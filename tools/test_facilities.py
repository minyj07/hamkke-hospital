"""장애인편의시설 기구표를 받고 병원에 합치는 과정의 테스트. API 는 부르지 않는다.

실행: python -m unittest discover -s tools
"""

import contextlib
import csv
import io
import json
import tempfile
import unittest
import xml.etree.ElementTree as ET
from pathlib import Path
from unittest import mock

import build_data
import fetch_facilities
from build_data import Builder, building_key, eval_facilities, merge_facilities, parse_eval
from hira import ApiError

FULL = "주출입구 접근로, 장애인전용주차구역, 주출입구 높이차이 제거, 주출입구(문), 승강기, 장애인사용가능화장실"
NO_ELEVATOR = "주출입구 접근로, 주출입구 높이차이 제거, 주출입구(문), 장애인사용가능화장실"
# 기구표를 쓰지 않은 건물에 오는 가짜 응답 (2026-09 실측)
DUMMY = ("주출입구 접근로, 장애인전용주차구역, 주출입구높이차이제거(경사로), 주출입문, 승강기,"
         " 장애인사용가능화장실, 안내설비, 장애인사용가능객실")


def hospital(builder: Builder, ykiho: str, name: str, address: str) -> dict:
    sido = "210000" if address.startswith("부산") else "110000"
    return builder.add({
        "ykiho": ykiho, "YPos": 37.5, "XPos": 127.0, "sidoCd": sido, "sidoCdNm": address[:2],
        "yadmNm": name, "clCdNm": "의원", "addr": address, "sgguCdNm": address.split()[1],
    }, "21")


def merge(builder: Builder, rows: list[tuple[str, str]]) -> str:
    """(주소, 기구표) 행으로 기구표 파일을 만들어 합치고, 출력을 돌려준다."""
    with tempfile.TemporaryDirectory() as tmp:
        path = Path(tmp) / "facility_eval.csv"
        with path.open("w", encoding="utf-8-sig", newline="") as f:
            writer = csv.DictWriter(f, fetch_facilities.CSV_FIELDS)
            writer.writeheader()
            for i, (address, eval_info) in enumerate(rows):
                writer.writerow({"wfcltId": f"w{i}", "faclNm": "어느빌딩", "faclTyCd": "의원·치과의원",
                                 "lcMnad": address, "faclLat": "0", "faclLng": "0", "evalInfo": eval_info})
        out = io.StringIO()
        with mock.patch.object(build_data, "FACILITY_CSV", path), contextlib.redirect_stdout(out):
            merge_facilities(builder)
    return out.getvalue()


class BuildingKeyTest(unittest.TestCase):
    def test_심평원_주소와_편의시설_주소가_같은_건물로_묶인다(self):
        self.assertEqual(building_key("110000", "서울특별시 서대문구 신촌로 157, 3층 (창천동)"),
                         building_key("110000", "서울특별시 서대문구 신촌로 157"))

    def test_다른_시군구의_같은_도로명은_다른_건물이다(self):
        self.assertNotEqual(building_key("110000", "서울특별시 관악구 보라매로3길 29"),
                            building_key("110000", "서울특별시 동작구 보라매로3길 29"))

    def test_면이_읍이_되어도_같은_건물이다(self):
        self.assertEqual(building_key("210000", "부산광역시 기장군 정관읍 정관로 560, 마치빌딩 203호"),
                         building_key("210000", "부산광역시 기장군 정관면 정관로 560"))

    def test_도로명이_없거나_시도를_모르면_열쇠가_없다(self):
        self.assertIsNone(building_key("110000", "서울특별시 서대문구 창천동 90-85"))
        self.assertIsNone(building_key(None, "서울특별시 서대문구 신촌로 157"))


class EvalTest(unittest.TestCase):
    def test_표기가_흔들려도_같은_항목으로_읽는다(self):
        self.assertEqual(parse_eval("승강기,주출입구 높이차이 제거 , 장애인사용가능화장실"),
                         {"승강기", "주출입구높이차이제거", "장애인사용가능화장실"})

    def test_가짜_응답은_읽지_않는다(self):
        self.assertIsNone(parse_eval(DUMMY))

    def test_휠체어는_입구가_모두_갖춰지고_승강기가_있거나_1층일_때만(self):
        self.assertIn("wheelchair", eval_facilities(parse_eval(FULL), "서울 신촌로 157, 3층"))
        self.assertNotIn("wheelchair", eval_facilities(parse_eval(NO_ELEVATOR), "서울 신촌로 157, 3층"))
        self.assertIn("wheelchair", eval_facilities(parse_eval(NO_ELEVATOR), "서울 신촌로 157, 1층 101호"))
        self.assertNotIn("wheelchair", eval_facilities(parse_eval(NO_ELEVATOR), "서울 신촌로 157, 1층, 2층"))
        self.assertNotIn("wheelchair", eval_facilities(parse_eval(NO_ELEVATOR), "서울 신촌로 157, 지하1층"))
        self.assertNotIn("wheelchair", eval_facilities(parse_eval(NO_ELEVATOR), "서울 신촌로 157"))
        no_door = parse_eval(FULL) - {"주출입구(문)"}
        self.assertNotIn("wheelchair", eval_facilities(no_door, "서울 신촌로 157, 1층"))

    def test_기구표_항목을_앱의_편의시설로_바꾼다(self):
        self.assertEqual(eval_facilities(parse_eval(FULL), "서울 신촌로 157"),
                         {"wheelchair", "parking", "toilet"})
        self.assertEqual(eval_facilities({"유도및안내설비"}, ""), {"braille"})


class MergeTest(unittest.TestCase):
    def test_같은_건물의_병원_모두에_넣고_다른_곳에는_넣지_않는다(self):
        b = Builder()
        clinic3 = hospital(b, "k1", "화영내과의원", "서울특별시 서대문구 신촌로 157, 3층 (창천동)")
        clinic5 = hospital(b, "k2", "밝은치과의원", "서울특별시 서대문구 신촌로 157, 5층")
        other_gu = hospital(b, "k3", "동작내과의원", "서울특별시 동작구 신촌로 157")
        ground = hospital(b, "k4", "연세의원", "서울특별시 서대문구 연세로 10, 1층")
        gijang = hospital(b, "k5", "정관내과의원", "부산광역시 기장군 정관읍 정관로 560, 2층")

        out = merge(b, [
            ("서울특별시 서대문구 신촌로 157", FULL),
            ("서울특별시 서대문구 연세로 10", NO_ELEVATOR),
            ("부산광역시 기장군 정관면 정관로 560", DUMMY),
            ("부산광역시 기장군 정관면 정관로 560", "장애인전용주차구역"),
            ("서울특별시 서대문구 창천동 90-85", FULL),
            ("서울특별시 종로구 종로 1", "승강기, 무장애 엘리베이터"),
        ])

        self.assertEqual(clinic3["f"], {"wheelchair", "parking", "toilet"})
        self.assertEqual(clinic5["f"], {"wheelchair", "parking", "toilet"})
        self.assertEqual(other_gu["f"], set())
        self.assertEqual(ground["f"], {"wheelchair", "toilet"})
        self.assertEqual(gijang["f"], {"parking"})  # 가짜 응답은 버리고 진짜 기구표만 썼다
        self.assertIn("병원 4곳에 연결", out)
        self.assertIn("가짜 응답 1건", out)
        self.assertIn("도로명 주소 아님 1건", out)
        self.assertIn("건물에 앱 병원 없음 1건", out)
        self.assertIn("처음 보는 기구표 항목 '무장애엘리베이터'", out)

    def test_한_건물에_기구표가_여럿이면_모두_있다고_한_항목만_믿는다(self):
        b = Builder()
        clinic = hospital(b, "k1", "화영내과의원", "서울특별시 서대문구 신촌로 157, 3층")
        merge(b, [("서울특별시 서대문구 신촌로 157", FULL),
                  ("서울특별시 서대문구 신촌로 157", NO_ELEVATOR)])
        self.assertEqual(clinic["f"], {"toilet"})

    def test_기구표가_없으면_건너뛴다(self):
        b = Builder()
        clinic = hospital(b, "k1", "화영내과의원", "서울특별시 서대문구 신촌로 157")
        out = io.StringIO()
        with mock.patch.object(build_data, "FACILITY_CSV", Path("없는파일.csv")), \
                contextlib.redirect_stdout(out):
            merge_facilities(b)
        self.assertEqual(clinic["f"], set())
        self.assertIn("건너뜁니다", out.getvalue())

    def test_편의시설은_파일과_출처에_들어간다(self):
        b = Builder()
        hospital(b, "k1", "화영내과의원", "서울특별시 서대문구 신촌로 157")
        hospital(b, "k2", "연세의원", "서울특별시 서대문구 연세로 10")
        merge(b, [("서울특별시 서대문구 신촌로 157", FULL)])
        with tempfile.TemporaryDirectory() as tmp, mock.patch.object(build_data, "OUT", Path(tmp)), \
                contextlib.redirect_stdout(io.StringIO()):
            build_data.write_outputs(b, None)
            hospitals = json.loads((Path(tmp) / "hospitals" / "110000.json").read_text(encoding="utf-8"))
            meta = json.loads((Path(tmp) / "meta.json").read_text(encoding="utf-8"))
        facilities = {h["n"]: h.get("f") for h in hospitals}
        self.assertEqual(facilities, {"화영내과의원": ["parking", "toilet", "wheelchair"], "연세의원": None})
        self.assertIn("한국사회보장정보원 장애인편의시설 현황", meta["sources"])


class FetchTest(unittest.TestCase):
    """목록 → 의료시설 건물 → 기구표 → data/facility_eval.csv. API 대신 가짜 응답을 쓴다."""

    LIST_ITEMS = [
        ("w1", "화영빌딩", "의원·치과의원·한의원·조산소·산후조리원", "서울특별시 서대문구 신촌로 157", "영업"),
        ("w2", "우리병원", "병원·치과병원·한방병원·정신병원·요양병원", "서울특별시 서대문구 신촌로 1", "영업"),
        ("w3", "앱병원", "병원·치과병원·한방병원·정신병원·요양병원", "서울특별시 서대문구 연세로 10", "영업"),
        ("w4", "닫은의원", "의원·치과의원·한의원·조산소·산후조리원", "서울특별시 서대문구 연세로 20", "폐업"),
        ("w5", "마트", "수퍼마켓·일용품 등의 소매점", "서울특별시 서대문구 연세로 30", "영업"),
        ("w1", "화영빌딩 약국", "의원·치과의원·한의원·조산소·산후조리원", "서울특별시 서대문구 신촌로 157", "영업"),
    ]

    def setUp(self) -> None:
        self.tmp = tempfile.TemporaryDirectory()
        root = Path(self.tmp.name)
        cache, app = root / "cache", root / "assets"
        (app / "hospitals").mkdir(parents=True)
        cache.mkdir()
        (app / "regions.json").write_text(json.dumps([{"code": "110000", "name": "서울특별시"}]),
                                          encoding="utf-8")
        # 앱에 있는 병원: w1(의원 건물)·w3(병원) 건물에 있다. w2 건물에는 없다.
        (app / "hospitals" / "110000.json").write_text(json.dumps([
            {"n": "화영내과의원", "a": "서울특별시 서대문구 신촌로 157, 3층"},
            {"n": "앱병원", "a": "서울특별시 서대문구 연세로 10"},
        ], ensure_ascii=False), encoding="utf-8")
        self.requested: list[str] = []
        patches = {
            "OUT": cache, "USAGE": cache / "usage.json", "META": cache / "meta.json",
            "EVALS": cache / "eval.json", "APP_DATA": app, "CSV_PATH": root / "facility_eval.csv",
            "call_xml": self.fake_api,
        }
        for name, value in patches.items():
            patcher = mock.patch.object(fetch_facilities, name, value)
            patcher.start()
            self.addCleanup(patcher.stop)
        self.addCleanup(self.tmp.cleanup)

    def fake_api(self, path: str, **params) -> ET.Element:
        if path == fetch_facilities.LIST:
            self.requested.append("list")
            items = "".join(
                f"<servList><wfcltId>{w}</wfcltId><faclNm>{n}</faclNm><faclTyCd>{t}</faclTyCd>"
                f"<lcMnad>{a}</lcMnad><faclLat>0</faclLat><faclLng>0</faclLng><salStaNm>{s}</salStaNm></servList>"
                for w, n, t, a, s in self.LIST_ITEMS)
            return ET.fromstring(f"<r><totalCount>{len(self.LIST_ITEMS)}</totalCount>{items}</r>")
        self.requested.append(params["wfcltId"])
        if params["wfcltId"] == "w2":
            raise ApiError("NODATA_ERROR (code 03)")
        return ET.fromstring(f"<r><resultCode>0</resultCode><servList><evalInfo>{FULL}</evalInfo></servList></r>")

    def run_main(self, budget: int) -> str:
        # main() 이 sys.stdout.reconfigure() 를 부르므로 StringIO 대신 TextIOWrapper 로 받는다.
        out = io.TextIOWrapper(io.BytesIO(), encoding="utf-8")
        with mock.patch("sys.argv", ["fetch_facilities.py", "--budget", str(budget)]), \
                contextlib.redirect_stdout(out):
            fetch_facilities.main()
        out.flush()
        return out.buffer.getvalue().decode("utf-8")

    def test_앱_병원이_있는_병원급_건물부터_한도_안에서_받고_다음날_이어받는다(self):
        out = self.run_main(budget=2)
        # 목록 1번, 그다음 앱 병원과 같은 건물 중 병원급(w3)부터
        self.assertEqual(self.requested, ["list", "w3"])
        self.assertIn("오늘 한도(2번)를 다 썼습니다", out)

        with mock.patch.object(fetch_facilities, "date") as fake_date:
            fake_date.today.return_value.isoformat.return_value = "2099-01-01"
            self.run_main(budget=10)
        # 폐업(w4)·의료시설이 아닌 곳(w5)은 받지 않고, 같은 건물(w1)은 한 번만 받는다
        self.assertEqual(self.requested, ["list", "w3", "w1", "w2"])

        with fetch_facilities.CSV_PATH.open(encoding="utf-8-sig", newline="") as f:
            rows = list(csv.DictReader(f))
        # w2 는 기구표가 없어(오류) 빠진다
        self.assertEqual([r["wfcltId"] for r in rows], ["w1", "w3"])
        self.assertEqual(rows[0]["evalInfo"], FULL)
        self.assertNotIn(b"\r\n", fetch_facilities.CSV_PATH.read_bytes())

    def test_호출_한도_오류면_그_건물을_비워_두지_않고_멈춘다(self):
        def limited(path: str, **params) -> ET.Element:
            if path == fetch_facilities.LIST:
                return self.fake_api(path, **params)
            raise ApiError("LIMITED_NUMBER_OF_SERVICE_REQUESTS_EXCEEDS_ERROR (code 22)")

        with mock.patch.object(fetch_facilities, "call_xml", limited):
            out = self.run_main(budget=50)
        self.assertIn("기구표 받기를 멈춤", out)
        self.assertEqual(json.loads(fetch_facilities.EVALS.read_text(encoding="utf-8")), {})


if __name__ == "__main__":
    unittest.main()
