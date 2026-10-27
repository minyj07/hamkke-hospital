"""심평원·건보공단 공공데이터로 앱에 넣을 병원 데이터를 만든다.

실행: python tools/build_data.py [--refresh]
결과:
  assets/data/regions.json           시·도 목록과 중심 좌표
  assets/data/hospitals/<코드>.json  시·도별 병원 목록 (필드 설명은 lib/models/hospital.dart)
  assets/data/meta.json              데이터 판 번호·기준일·출처와 파일별 sha256
API 응답은 tools/cache/ 에 저장해 두고 다시 실행할 때 재사용한다. --refresh 로 새로 받는다.
data/ 의 건강주치의·지정 기관 목록과 편의시설 기구표(tools/fetch_facilities.py 가 만든다)도 합친다.
같은 결과를 GitHub Pages 에도 올리면 설치된 앱이 바뀐 파일만 내려받는다
(.github/workflows/update-data.yml, lib/data/data_store.dart).
"""

import argparse
import csv
import hashlib
import json
import re
import statistics
import sys
import time
from collections import Counter, defaultdict
from datetime import datetime, timedelta, timezone
from difflib import SequenceMatcher
from pathlib import Path

from hira import ApiError, call

TOOLS = Path(__file__).resolve().parent
ROOT = TOOLS.parent
OUT = ROOT / "assets" / "data"
CACHE = TOOLS / "cache"

# 앱이 읽을 수 있는 데이터 형식. lib/data/data_store.dart 의 dataSchema 와 같아야 한다.
# 예전 앱이 못 읽게 형식을 바꾸면 둘 다 올리고, 배포 주소도 v2/ 처럼 새로 만든다.
SCHEMA = 1
KST = timezone(timedelta(hours=9))

# 앱의 추천 규칙(lib/services/recommender.dart)에서 쓰는 진료과목. 키는 심평원 진료과목코드.
DEPARTMENTS = {
    "01": "내과", "02": "신경과", "03": "정신건강의학과", "04": "외과", "05": "정형외과",
    "06": "신경외과", "08": "성형외과", "09": "마취통증의학과", "10": "산부인과",
    "11": "소아청소년과", "12": "안과", "13": "이비인후과", "14": "피부과", "15": "비뇨의학과",
    "21": "재활의학과", "23": "가정의학과", "49": "치과",
}
# 치과의원은 진료과목코드(49)로는 일부만 나오므로 종별코드로 받는다.
DENTAL_KINDS = {"41": "치과병원", "51": "치과의원"}

# 광주광역시·전라남도가 전남광주통합특별시(360000)로 합쳐진 뒤 240000(광주)에 남은 기관을 옮긴다.
REGION_MERGES = {"240000": "360000"}
# 통합·명칭 변경 전 주소를 쓰는 자료(건강주치의 CSV 등)를 시·도 코드로 바꾸기 위한 옛 이름.
LEGACY_REGION_NAMES = {
    "광주광역시": "360000", "전라남도": "360000", "강원도": "320000", "전라북도": "350000",
}

PAGE_SIZE = 5000

# 도로명 주소에서 "도로명 건물번호"를 뽑는다. 예: "경춘로 466", "창원천로94번길 82-18"
ROAD_ADDRESS = re.compile(r"(\S+(?:로|길))\s*(\d+(?:-\d+)?)")


def call_with_retry(*args, **kwargs) -> dict:
    for attempt in range(4):
        try:
            return call(*args, **kwargs)
        except ApiError as e:
            fatal = any(s in str(e) for s in ("SERVICE_KEY", "LIMITED_NUMBER", "NO_OPENAPI"))
            if fatal or attempt == 3:
                raise
            print(f"    재시도 {attempt + 1}: {e}")
            time.sleep(3 * 2**attempt)
    raise AssertionError("unreachable")


def fetch_all(cache_name: str, refresh: bool, **params) -> list[dict]:
    path = CACHE / f"{cache_name}.json"
    if path.exists() and not refresh:
        return json.loads(path.read_text(encoding="utf-8"))
    items, page = [], 1
    while True:
        body = call_with_retry(
            "hospInfoServicev2", "getHospBasisList",
            pageNo=page, numOfRows=PAGE_SIZE, **params,
        )
        items += body["items"]
        if page * PAGE_SIZE >= int(body["totalCount"]):
            break
        page += 1
    CACHE.mkdir(exist_ok=True)
    path.write_text(json.dumps(items, ensure_ascii=False), encoding="utf-8")
    return items


def to_float(value) -> float | None:
    try:
        return float(value)
    except (TypeError, ValueError):
        return None


def to_int(value) -> int:
    try:
        return int(value)
    except (TypeError, ValueError):
        return 0


def opening_year(estb) -> int | None:
    """개설일자(예: 19790324)의 연도."""
    year = to_int(str(estb or "")[:4])
    return year if 1900 <= year <= datetime.now(KST).year else None


def homepage(url) -> str:
    """심평원에 등록된 홈페이지. 앞에 http(s):// 가 없으면 붙인다."""
    url = str(url or "").strip()
    if not url or " " in url or "." not in url:
        return ""
    return url if re.match(r"https?://", url, re.IGNORECASE) else "http://" + url


def normalize_name(name: str) -> str:
    return re.sub(r"[\s()（）\[\]·.,\-]", "", name).lower()


class Builder:
    def __init__(self) -> None:
        self.records: dict[str, dict] = {}  # ykiho -> 레코드
        self.without_coords: set[str] = set()
        self.short_names: dict[str, str] = {}  # 시·도 코드 -> 심평원 약칭 (예: 부산)

    def add(self, item: dict, department: str | None) -> dict | None:
        ykiho = item.get("ykiho")
        if not ykiho or ykiho in self.without_coords:
            return None
        rec = self.records.get(ykiho)
        if rec is None:
            lat, lng = to_float(item.get("YPos")), to_float(item.get("XPos"))
            if not lat or not lng:
                self.without_coords.add(ykiho)
                return None
            original = str(item.get("sidoCd", ""))
            region = REGION_MERGES.get(original, original)
            if original == region:
                self.short_names.setdefault(region, item.get("sidoCdNm", ""))
            rec = self.records[ykiho] = {
                "id": hashlib.sha1(ykiho.encode()).hexdigest()[:10],
                "n": str(item.get("yadmNm", "")).strip(),
                "k": item.get("clCdNm", ""),
                "a": str(item.get("addr", "")).strip(),
                "p": str(item.get("telno") or "").strip(),
                "r": region,
                "d": item.get("sgguCdNm", ""),
                "y": round(lat, 5),
                "x": round(lng, 5),
                # 의사 수와 그중 전문의 수 (의과·치과·한의 합), 개원 연도, 홈페이지
                "dr": to_int(item.get("drTotCnt")),
                "sd": sum(to_int(item.get(k)) for k in ("mdeptSdrCnt", "detySdrCnt", "cmdcSdrCnt")),
                "e": opening_year(item.get("estbDd")),
                "u": homepage(item.get("hospUrl")),
                "dp": set(),
                "c": set(),
                "f": set(),
                "fx": set(),
                "nt": [],
            }
        if department:
            rec["dp"].add(department)
        return rec

    def tidy_districts(self) -> None:
        """심평원은 겹치는 구 이름에 시 약칭을 붙인다(부산강서구). 화면에는 강서구로 보인다."""
        for rec in self.records.values():
            short = self.short_names.get(rec["r"], "")
            if short and rec["d"].startswith(short) and len(rec["d"]) > len(short) + 1:
                rec["d"] = rec["d"][len(short):]

    def region_names(self) -> dict[str, str]:
        """시·도 코드 → 주소에 가장 많이 쓰인 정식 이름."""
        counts: dict[str, Counter] = defaultdict(Counter)
        for rec in self.records.values():
            counts[rec["r"]][rec["a"].split(" ", 1)[0]] += 1
        return {code: c.most_common(1)[0][0] for code, c in counts.items()}


def fetch_hospitals(builder: Builder, refresh: bool) -> None:
    for code, name in DEPARTMENTS.items():
        items = fetch_all(f"dept_{code}", refresh, dgsbjtCd=code)
        print(f"  {name}: {len(items):,}곳")
        for item in items:
            builder.add(item, code)
    for kind, name in DENTAL_KINDS.items():
        items = fetch_all(f"kind_{kind}", refresh, clCd=kind)
        print(f"  {name}: {len(items):,}곳")
        for item in items:
            builder.add(item, "49")


def pick_match(candidates: list[dict], address: str, region: str | None) -> dict | None:
    if region:
        candidates = [c for c in candidates if c["r"] == region]
    if len(candidates) <= 1:
        return candidates[0] if candidates else None
    tokens = set(address.split())
    return max(candidates, key=lambda c: len(tokens & set(c["a"].split())))


def road_key(region: str | None, address: str) -> tuple | None:
    m = ROAD_ADDRESS.search(address)
    return (region, m.group(1), m.group(2)) if m else None


GENERIC_NAME_PARTS = re.compile(r"^의료법인|의료재단|(치과의원|치과병원|요양병원|재활병원|의원|병원)$")


def name_core(name: str) -> str:
    """"의원"·"치과의원"처럼 어느 기관에나 붙는 부분을 뗀 고유한 이름."""
    return GENERIC_NAME_PARTS.sub("", normalize_name(name))


def match_by_address(candidates: list[dict], name: str, dental: bool) -> dict | None:
    """같은 건물의 기관 중 고유한 이름이 겹치는 곳. 이름이 바뀌었거나 줄여 쓴 경우를 잡는다.

    같은 건물에 다른 병원이 여럿 있으므로, 짧은 쪽 이름의 60% 이상(2글자 이상)이
    이어서 겹칠 때만 같은 기관으로 본다. 예: 굿플란트 ↔ 365굿플란트 (O), 박안과 ↔ 박피부과 (X)
    """
    def kind_fits(rec: dict) -> bool:
        return ("49" in rec["dp"]) if dental else bool(rec["dp"] - {"49"} or not rec["dp"])

    core = name_core(name)
    best, best_score = None, 0.0
    for rec in candidates:
        other = name_core(rec["n"])
        if not core or not other or not kind_fits(rec):
            continue
        overlap = SequenceMatcher(None, core, other).find_longest_match().size
        score = overlap / min(len(core), len(other))
        if overlap >= 2 and score >= 0.6 and score > best_score:
            best, best_score = rec, score
    return best


def merge_primary_care(builder: Builder, refresh: bool) -> list[str]:
    """건강주치의 CSV의 기관을 심평원 데이터와 이름·주소로 연결한다. 못 찾은 기관 이름을 돌려준다."""
    csv_path = next((ROOT / "data").glob("*장애인 건강주치의*.csv"), None)
    if csv_path is None:
        print("  건강주치의 CSV가 data/ 에 없어 건너뜁니다.")
        return []

    region_by_name = {v: k for k, v in builder.region_names().items()} | LEGACY_REGION_NAMES
    by_name: dict[str, list[dict]] = defaultdict(list)
    by_road: dict[tuple, list[dict]] = defaultdict(list)
    for rec in builder.records.values():
        by_name[normalize_name(rec["n"])].append(rec)
        if key := road_key(rec["r"], rec["a"]):
            by_road[key].append(rec)

    with csv_path.open(encoding="cp949", newline="") as f:
        rows = list(csv.DictReader(f))

    unmatched = []
    for row in rows:
        name, address = row["요양기관명"].strip(), row["주소"].strip()
        region = region_by_name.get(address.split(" ", 1)[0])
        dental = row["구분"].strip() == "치과"
        rec = pick_match(by_name.get(normalize_name(name), []), address, region)
        if rec is None and (key := road_key(region, address)):
            rec = match_by_address(by_road.get(key, []), name, dental)
        if rec is None:
            # 추천 대상 진료과가 없는 기관일 수 있으니 이름으로 한 번 더 찾는다.
            found = fetch_all(f"name_{hashlib.sha1(name.encode()).hexdigest()[:12]}",
                              refresh, yadmNm=name)
            recs = [r for item in found if (r := builder.add(item, None))]
            exact = [r for r in recs if normalize_name(r["n"]) == normalize_name(name)]
            rec = pick_match(exact, address, region)
        if rec is None:
            unmatched.append(f"{name} ({address})")
            continue
        rec["c"].add("dentalPrimaryCare" if dental else "primaryCare")
        note = f"장애인 건강주치의 ({row['서비스유형'].strip()})"
        if note not in rec["nt"]:
            rec["nt"].append(note)
    print(f"  건강주치의 {len(rows):,}곳 중 {len(rows) - len(unmatched):,}곳 연결")
    return unmatched


def merge_designated(builder: Builder, refresh: bool) -> list[str]:
    """보건복지부·국립재활원 지정 기관 목록(data/designated_institutions.csv)을 연결한다.

    목록의 hira_name 은 심평원 등록 이름이고, address_hint 로 같은 이름의 다른 기관을 걸러낸다.
    출처는 data/designated_sources.md 에 있다. 못 찾은 항목을 돌려준다.
    """
    path = ROOT / "data" / "designated_institutions.csv"
    if not path.exists():
        print("  지정 기관 목록이 없어 건너뜁니다.")
        return []
    with path.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))

    by_name: dict[str, list[dict]] = defaultdict(list)
    for rec in builder.records.values():
        by_name[rec["n"]].append(rec)

    unmatched = []
    for row in rows:
        name, region, hint = row["hira_name"], row["region"], row["address_hint"]

        def candidates() -> list[dict]:
            return [r for r in by_name.get(name, []) if r["r"] == region and hint in r["a"]]

        found = candidates()
        if not found:
            # 추천 대상 진료과가 없어 아직 받지 않은 기관이면 이름으로 찾는다.
            items = fetch_all(f"name_{hashlib.sha1(name.encode()).hexdigest()[:12]}",
                              refresh, yadmNm=name)
            for item in items:
                if (rec := builder.add(item, None)) and rec not in by_name[rec["n"]]:
                    by_name[rec["n"]].append(rec)
            found = candidates()
        if len(found) != 1:
            unmatched.append(f"{row['category']} {name} ({hint}): 후보 {len(found)}곳")
            continue
        rec = found[0]
        rec["c"].add(row["category"])
        if row["label"] not in rec["nt"]:
            rec["nt"].append(row["label"])
    print(f"  지정 기관 {len(rows)}건 중 {len(rows) - len(unmatched)}건 연결")
    return unmatched


# 장애인편의시설 기구표 (한국사회보장정보원). tools/fetch_facilities.py 가 만든다.
FACILITY_CSV = ROOT / "data" / "facility_eval.csv"
# 기구표(evalInfo)는 설치된 편의시설 항목을 쉼표로 이은 글이다. 표기가 흔들리므로 공백을 지우고 비교한다.
EVAL_ITEMS = {
    "주출입구접근로", "주출입구높이차이제거", "주출입구(문)", "승강기",
    "장애인전용주차구역", "장애인사용가능화장실", "유도및안내설비", "장애인사용가능객실",
}
EVAL_ALIASES = {"주출입구높이차이제거(경사로)": "주출입구높이차이제거", "안내설비": "유도및안내설비"}
# 기구표를 쓰지 않은 건물은 모든 항목을 채운 가짜 응답이 온다. 이 표기는 그 응답에만 나온다.
EVAL_DUMMY = "주출입문"
# 휠체어로 들어가려면 주출입구까지의 길, 턱 없는 입구, 넓은 문이 모두 있어야 한다.
EVAL_ENTRANCE = {"주출입구접근로", "주출입구높이차이제거", "주출입구(문)"}
# 기구표 항목 → 앱의 편의시설 (lib/models/hospital.dart 의 Facility).
EVAL_FACILITIES = {"장애인전용주차구역": "parking", "장애인사용가능화장실": "toilet", "유도및안내설비": "braille"}
# 앱의 편의시설 이름. 기구표로 알 수 있는 것은 휠체어와 EVAL_FACILITIES 뿐이고, 나머지는 '정보 없음'이다.
FACILITIES = {"wheelchair", "parking", "toilet", "lift", "signLanguage", "braille", "sedation",
              "quietRoom", "dialysis"}
FLOOR = re.compile(r"(지하|B)?\s*(\d+)\s*층")


def building_key(region: str | None, address: str) -> tuple | None:
    """같은 건물을 가리키는 열쇠 (시·도, 시·군·구, 도로명, 건물번호).

    도로명은 시·군·구마다 따로 붙이므로 시·군·구까지 봐야 다른 도시의 같은 도로명과 섞이지 않는다.
    읍·면은 뺀다. 면이 읍이 되면 한 건물에 예전 주소와 새 주소가 함께 쓰인다 (정관면 → 정관읍).
    """
    m = ROAD_ADDRESS.search(address)
    if not region or not m:
        return None
    district = "".join(t for t in address[:m.start()].split()[1:] if not t.endswith(("읍", "면")))
    return region, district, m.group(1), m.group(2)


def parse_eval(text: str) -> set[str] | None:
    """기구표 원문 → 항목 집합. 가짜 응답이면 None."""
    items = {re.sub(r"\s+", "", t) for t in text.split(",")} - {""}
    if EVAL_DUMMY in items:
        return None
    return {EVAL_ALIASES.get(t, t) for t in items}


def on_ground_floor(address: str) -> bool:
    """주소에 적힌 층이 지상 1층뿐인지. 그러면 승강기가 없어도 휠체어로 갈 수 있다."""
    floors = FLOOR.findall(address)
    return bool(floors) and all(f == ("", "1") for f in floors)


def eval_facilities(items: set[str], address: str) -> tuple[set[str], set[str]]:
    """기구표 항목 → (있는 편의시설, 없다고 확인된 편의시설).

    휠체어는 입구를 모두 갖추고 승강기가 있거나 지상 1층에만 있으면 있고, 입구가 모자라거나 승강기 없이
    다른 층에 있으면 없다. 입구는 갖췄는데 승강기가 없고 층을 모르면 알 수 없으므로 어느 쪽에도 넣지 않는다.
    """
    present = {EVAL_FACILITIES[i] for i in items if i in EVAL_FACILITIES}
    absent = set(EVAL_FACILITIES.values()) - present
    entrance = EVAL_ENTRANCE <= items
    if entrance and ("승강기" in items or on_ground_floor(address)):
        present.add("wheelchair")
    elif not entrance or FLOOR.search(address):
        absent.add("wheelchair")
    return present, absent


def merge_facilities(builder: Builder) -> None:
    """장애인편의시설 기구표(data/facility_eval.csv)의 편의시설을 같은 건물의 병원에 넣는다.

    기구표는 건물 단위이고 의원은 시설명이 '화영빌딩'처럼 건물 이름인 경우가 많으며 좌표가 0 인
    시설도 많아서, 이름·좌표가 아니라 도로명 주소로 건물을 찾아 그 건물의 병원 모두에 적용한다.
    접근성 정보는 없는데 있다고 하는 쪽이 더 위험하므로 애매하면 넣지 않는다.
    """
    if not FACILITY_CSV.exists():
        print("  편의시설 기구표가 data/ 에 없어 건너뜁니다. (tools/fetch_facilities.py 로 받기)")
        return
    with FACILITY_CSV.open(encoding="utf-8-sig", newline="") as f:
        rows = list(csv.DictReader(f))

    region_by_name = {v: k for k, v in builder.region_names().items()} | LEGACY_REGION_NAMES
    by_building: dict[tuple, list[dict]] = defaultdict(list)
    for rec in builder.records.values():
        if key := building_key(rec["r"], rec["a"]):
            by_building[key].append(rec)

    evals: dict[str, list[set[str]]] = defaultdict(list)  # 병원 id → 그 건물의 기구표들
    dummy = no_address = no_hospital = 0
    unknown: Counter = Counter()
    for row in rows:
        items = parse_eval(row["evalInfo"])
        if items is None:
            dummy += 1
            continue
        unknown.update(items - EVAL_ITEMS)
        address = row["lcMnad"].strip()
        key = building_key(region_by_name.get(address.split(" ", 1)[0]), address)
        if key is None:
            no_address += 1
        elif key not in by_building:
            no_hospital += 1
        for rec in by_building.get(key, []):
            evals[rec["id"]].append(items)

    linked = 0
    for rec in builder.records.values():
        if found := evals.get(rec["id"]):
            # 같은 건물에 기구표가 여럿이면 모두 있다고 한 것만 있고, 모두 없다고 한 것만 없다.
            # 서로 다르면 어느 쪽인지 알 수 없다.
            rec["f"], _ = eval_facilities(set.intersection(*found), rec["a"])
            _, rec["fx"] = eval_facilities(set.union(*found), rec["a"])
            linked += 1
    print(f"  기구표 {len(rows):,}건 → 병원 {linked:,}곳에 연결 (가짜 응답 {dummy:,}건,"
          f" 도로명 주소 아님 {no_address:,}건, 건물에 앱 병원 없음 {no_hospital:,}건)")
    for item, count in unknown.most_common():
        print(f"    처음 보는 기구표 항목 '{item}' {count:,}건 — 필요하면 EVAL_ITEMS 에 넣는다")


# 추천 점수표 (lib/services/score_weights.dart). 데이터와 함께 배포해서 앱을 업데이트하지 않고 고친다.
SCORING = ROOT / "data" / "scoring.json"


def file_hashes() -> dict[str, str]:
    """앱이 바뀐 파일만 내려받도록 파일마다 내용의 sha256 을 적는다. 키는 assets/data/ 아래 경로."""
    scoring = [OUT / "scoring.json"] if (OUT / "scoring.json").exists() else []
    paths = [OUT / "regions.json", OUT / "search.json", *scoring,
             *sorted((OUT / "hospitals").glob("*.json"))]
    return {p.relative_to(OUT).as_posix(): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}


def center(recs: list[dict]) -> dict:
    """병원 좌표의 중앙값. 지역 중심점으로 쓴다."""
    return {
        "lat": round(statistics.median(r["y"] for r in recs), 4),
        "lng": round(statistics.median(r["x"] for r in recs), 4),
    }


def write_outputs(builder: Builder, primary_care_file: str | None) -> None:
    names = builder.region_names()
    by_region: dict[str, list[dict]] = defaultdict(list)
    for rec in builder.records.values():
        if rec["dp"] or rec["c"]:
            by_region[rec["r"]].append(rec)

    hospitals_dir = OUT / "hospitals"
    hospitals_dir.mkdir(parents=True, exist_ok=True)
    for old in hospitals_dir.glob("*.json"):
        old.unlink()

    regions = []
    for code in sorted(by_region):
        recs = sorted(by_region[code], key=lambda r: r["n"])
        compact = []
        for rec in recs:
            out = {k: v for k, v in rec.items() if k not in ("r", "dp", "c", "f", "fx", "nt")}
            out["dp"] = sorted(rec["dp"])
            if rec["c"]:
                out["c"] = sorted(rec["c"])
            if rec["f"]:
                out["f"] = sorted(rec["f"])
            if rec["fx"]:
                out["fx"] = sorted(rec["fx"])
            if rec["nt"]:
                out["nt"] = rec["nt"]
            for key in ("p", "dr", "sd", "e", "u"):
                if not out[key]:
                    del out[key]
            compact.append(out)
        (hospitals_dir / f"{code}.json").write_text(
            json.dumps(compact, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
        districts: dict[str, list[dict]] = defaultdict(list)
        for rec in recs:
            if rec["d"]:
                districts[rec["d"]].append(rec)
        regions.append({
            "code": code,
            "name": names[code],
            **center(recs),
            "count": len(recs),
            "districts": [{"name": d, **center(rs)} for d, rs in sorted(districts.items())],
        })

    # sha256 이 운영체제마다 달라지지 않게 줄바꿈은 항상 \n 으로 쓴다.
    (OUT / "regions.json").write_text(
        json.dumps(regions, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")
    # 병원 이름 검색용 색인 (시·도 → [id, 이름, 시·군·구, 종별]). 전국을 검색해도 시·도 파일을 다 읽지
    # 않고, 고른 병원의 시·도 파일만 읽는다.
    search = {
        code: [[r["id"], r["n"], r["d"], r["k"]] for r in sorted(by_region[code], key=lambda r: r["n"])]
        for code in sorted(by_region)
    }
    (OUT / "search.json").write_text(
        json.dumps(search, ensure_ascii=False, separators=(",", ":")), encoding="utf-8")
    if SCORING.exists():
        scoring = json.loads(SCORING.read_text(encoding="utf-8"))
        (OUT / "scoring.json").write_text(
            json.dumps(scoring, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")
    sources =["건강보험심사평가원 병원정보서비스"]
    if primary_care_file:
        sources.append(f"국민건강보험공단 {primary_care_file}")
    sources.append("보건복지부·국립재활원 지정 기관 목록")
    if any(rec["f"] or rec["fx"] for recs in by_region.values() for rec in recs):
        sources.append("한국사회보장정보원 장애인편의시설 현황")
    now = datetime.now(timezone.utc)
    meta = {
        "schema": SCHEMA,
        # 앱은 이 값이 더 큰 데이터가 올라오면 받는다. UTC 시각이라 문자열 순서가 곧 시간 순서다.
        "version": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "generatedAt": now.astimezone(KST).date().isoformat(),
        "hospitalCount": sum(r["count"] for r in regions),
        "sources": sources,
        "files": file_hashes(),
    }
    (OUT / "meta.json").write_text(
        json.dumps(meta, ensure_ascii=False, indent=1), encoding="utf-8", newline="\n")

    total = sum(p.stat().st_size for p in hospitals_dir.glob("*.json"))
    print(f"  시·도 {len(regions)}곳, 병원 {meta['hospitalCount']:,}곳, 파일 합계 {total / 1e6:.1f}MB")
    for r in regions:
        print(f"    {r['code']} {r['name']}: {r['count']:,}곳")


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--refresh", action="store_true", help="캐시를 무시하고 API에서 새로 받기")
    args = parser.parse_args()

    builder = Builder()
    print("[1] 심평원 병원 목록 받기")
    fetch_hospitals(builder, args.refresh)
    print(f"  중복 제거 후 {len(builder.records):,}곳 (좌표 없는 기관 {len(builder.without_coords):,}곳 제외)")

    print("[2] 장애인 건강주치의 연결")
    unmatched = merge_primary_care(builder, args.refresh)
    for u in unmatched:
        print(f"    못 찾음: {u}")

    print("[3] 지정 기관 연결")
    for u in merge_designated(builder, args.refresh):
        print(f"    못 찾음: {u}")

    print("[4] 장애인편의시설 연결")
    merge_facilities(builder)

    print("[5] 파일 쓰기")
    builder.tidy_districts()
    csv_path = next((ROOT / "data").glob("*장애인 건강주치의*.csv"), None)
    write_outputs(builder, csv_path.stem if csv_path else None)
    return 0


if __name__ == "__main__":
    sys.exit(main())
