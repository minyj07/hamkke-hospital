"""build_data.py 가 쓰는 병원 파일·검색 색인과 verify_data.py 검사의 테스트. API 는 부르지 않는다.

실행: python -m unittest discover -s tools
"""

import contextlib
import io
import json
import tempfile
import unittest
from pathlib import Path
from unittest import mock

import build_data
import verify_data
from build_data import Builder, homepage, opening_year, primary_care_source


def add(builder: Builder, ykiho: str, name: str, sido: str, address: str, **extra) -> dict:
    return builder.add({
        "ykiho": ykiho, "YPos": 37.5, "XPos": 127.0, "sidoCd": sido, "sidoCdNm": address[:2],
        "yadmNm": name, "clCdNm": "의원", "addr": address, "sgguCdNm": address.split()[1], **extra,
    }, "21")


class FieldTest(unittest.TestCase):
    def test_개원_연도는_개설일자에서_읽고_이상한_값은_버린다(self):
        self.assertEqual(opening_year(19790324), 1979)
        self.assertEqual(opening_year("20240101"), 2024)
        self.assertIsNone(opening_year(None))
        self.assertIsNone(opening_year("0"))
        self.assertIsNone(opening_year(99991231))

    def test_홈페이지는_http_를_붙이고_주소가_아니면_버린다(self):
        self.assertEqual(homepage("www.kbsmc.co.kr"), "http://www.kbsmc.co.kr")
        self.assertEqual(homepage("https://a.kr"), "https://a.kr")
        self.assertEqual(homepage(" HTTP://B.KR "), "HTTP://B.KR")
        self.assertEqual(homepage("없음"), "")
        self.assertEqual(homepage(None), "")

    def test_건강주치의_출처는_파일_이름에_기관_이름이_있으면_다시_붙이지_않는다(self):
        self.assertEqual(primary_care_source("국민건강보험공단_장애인 건강주치의 의료기관 목록_20250721"),
                         "국민건강보험공단_장애인 건강주치의 의료기관 목록_20250721")
        self.assertEqual(primary_care_source("장애인 건강주치의 의료기관 목록_20250721"),
                         "국민건강보험공단 장애인 건강주치의 의료기관 목록_20250721")


class OutputTest(unittest.TestCase):
    def build(self) -> Builder:
        b = Builder()
        add(b, "k1", "강남의원", "110000", "서울특별시 강남구 테헤란로 1",
            drTotCnt=5, mdeptSdrCnt=3, detySdrCnt=1, estbDd=20150301, hospUrl="www.gangnam.kr")
        add(b, "k2", "부산의원", "210000", "부산광역시 해운대구 해운대로 1", drTotCnt=0, estbDd="")
        return b

    def write(self, builder: Builder, out: Path) -> None:
        with mock.patch.object(build_data, "OUT", out), contextlib.redirect_stdout(io.StringIO()):
            build_data.write_outputs(builder, None)

    def test_의사_수_개원_연도_홈페이지를_쓰고_없는_값은_뺀다(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.write(self.build(), Path(tmp))
            seoul = json.loads((Path(tmp) / "hospitals" / "110000.json").read_text(encoding="utf-8"))[0]
            busan = json.loads((Path(tmp) / "hospitals" / "210000.json").read_text(encoding="utf-8"))[0]
        self.assertEqual((seoul["dr"], seoul["sd"], seoul["e"], seoul["u"]),
                         (5, 4, 2015, "http://www.gangnam.kr"))
        self.assertFalse({"dr", "sd", "e", "u"} & busan.keys())

    def test_검색_색인은_시도별로_병원을_담고_병원_파일과_어긋나면_검사에서_잡는다(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            self.write(self.build(), out)
            search = json.loads((out / "search.json").read_text(encoding="utf-8"))
            meta = json.loads((out / "meta.json").read_text(encoding="utf-8"))
            with mock.patch.object(verify_data, "OUT", out):
                self.assertEqual(verify_data.check(meta, None, 0.9), [])
                search["110000"][0][0] = "다른id"
                (out / "search.json").write_text(json.dumps(search, ensure_ascii=False), encoding="utf-8")
                errors = verify_data.check(meta, None, 0.9)
        self.assertEqual(search["210000"], [[search["210000"][0][0], "부산의원", "해운대구", "의원"]])
        self.assertIn("search.json", meta["files"])
        self.assertTrue(any("검색 색인" in e for e in errors), errors)

    def test_추천_점수표를_데이터와_함께_내보내고_모르는_이름은_검사에서_잡는다(self):
        with tempfile.TemporaryDirectory() as tmp:
            out = Path(tmp)
            self.write(self.build(), out)
            meta = json.loads((out / "meta.json").read_text(encoding="utf-8"))
            scoring = json.loads((out / "scoring.json").read_text(encoding="utf-8"))
        self.assertIn("scoring.json", meta["files"])
        self.assertEqual(scoring, json.loads(build_data.SCORING.read_text(encoding="utf-8")))
        self.assertEqual(verify_data.check_scoring(scoring), [])
        self.assertEqual(len(verify_data.check_scoring({**scoring, "designatd": 40})), 1)
        self.assertEqual(len(verify_data.check_scoring({**scoring, "child": -1})), 1)
        self.assertEqual(len(verify_data.check_scoring({k: v for k, v in scoring.items() if k != "child"})), 1)


if __name__ == "__main__":
    unittest.main()
