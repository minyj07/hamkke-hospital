"""한국사회보장정보원 장애인편의시설 목록과 기구표를 하루 호출 한도 안에서 조금씩 받아 둔다.

1. 목록: 1,000곳씩 받는다.
2. 기구표(설치된 편의시설 항목): 영업 중인 의료시설 건물마다 한 번 받는다. 기구표는 건물(wfcltId)
   단위라 한 건물에 시설이 여럿이어도 한 번이면 된다. 앱에 있는 병원과 같은 건물, 병원급을 먼저 받는다.
받은 기구표는 data/facility_eval.csv 로 모으고, build_data.py 가 같은 건물의 병원에 합친다.
data/ 에 두는 것은 GitHub Actions 의 주간 갱신에서도 쓰기 위해서다. 받을 때마다 커밋한다.

개발계정은 하루 100번까지라 매일 실행하면 받은 곳에서 이어서 받는다. 목록은 182쪽(18만 곳)이고
의료시설 건물은 약 5,400곳(2026-10 추정)이라, 기구표까지 받으려면 개발계정으로 두 달쯤 걸린다.
운영계정(활용사례 등록 후 트래픽 증가 신청)으로 한도가 늘면 --budget 을 올린다.

실행: python tools/fetch_facilities.py [--budget 90]
결과: tools/cache/facilities/ (받은 응답), data/facility_eval.csv
"""

import argparse
import csv
import json
import math
import sys
from datetime import date
from pathlib import Path

from build_data import LEGACY_REGION_NAMES, ROOT, building_key
from hira import ApiError, call_xml

LIST = "B554287/DisabledPersonConvenientFacility/getDisConvFaclList"
EVAL = "B554287/DisabledPersonConvenientFacility/getFacInfoOpenApiJpEvalInfoList"
PAGE_SIZE = 1000  # 이 API 가 한 번에 주는 최대 개수
FIELDS = ("wfcltId", "faclNm", "faclTyCd", "lcMnad", "faclLat", "faclLng", "salStaNm")
MEDICAL_TYPES = ("의원", "병원", "의료")
# 다음 건물로 넘어가도 소용없는 오류 (인증키·호출 한도·네트워크). 나머지는 그 건물만의 문제로 본다.
STOP_ERRORS = ("SERVICE_KEY", "LIMITED_NUMBER", "NO_OPENAPI", "네트워크 오류", "XML 이 아닌")

OUT = Path(__file__).with_name("cache") / "facilities"
USAGE = OUT / "usage.json"  # 오늘 쓴 호출 수 (여러 번 실행해도 한도를 넘지 않게)
META = OUT / "meta.json"
EVALS = OUT / "eval.json"  # 건물(wfcltId) → 기구표 원문. 기구표가 없는 건물은 빈 글
APP_DATA = ROOT / "assets" / "data"
CSV_PATH = ROOT / "data" / "facility_eval.csv"
CSV_FIELDS = ("wfcltId", "faclNm", "faclTyCd", "lcMnad", "faclLat", "faclLng", "evalInfo")


class Budget:
    """오늘 쓸 수 있는 호출 수."""

    def __init__(self, limit: int) -> None:
        self.limit = limit
        self.today = date.today().isoformat()
        self.usage = json.loads(USAGE.read_text()) if USAGE.exists() else {}

    @property
    def used(self) -> int:
        return self.usage.get(self.today, 0)

    def left(self) -> bool:
        return self.used < self.limit

    def spend(self) -> None:
        self.usage[self.today] = self.used + 1
        USAGE.write_text(json.dumps(self.usage))


def fetch_list(budget: Budget) -> None:
    """목록을 받은 곳에서 이어서 받는다."""
    total = json.loads(META.read_text())["totalCount"] if META.exists() else None
    page = 1
    while total is None or page <= math.ceil(total / PAGE_SIZE):
        path = OUT / f"page_{page:04d}.json"
        if path.exists():
            page += 1
            continue
        if not budget.left():
            break
        try:
            root = call_xml(LIST, pageNo=page, numOfRows=PAGE_SIZE)
        except ApiError as e:
            print(f"목록 {page}쪽 실패: {e}")
            break
        finally:
            budget.spend()
        total = int(root.findtext("totalCount"))
        META.write_text(json.dumps({"totalCount": total}))
        items = [{f: el.findtext(f) for f in FIELDS} for el in root.findall("servList")]
        path.write_text(json.dumps(items, ensure_ascii=False), encoding="utf-8")
        page += 1


def medical_buildings() -> dict[str, dict]:
    """받은 목록에서 영업 중인 의료시설의 건물 (wfcltId → 목록 항목)."""
    buildings: dict[str, dict] = {}
    for path in sorted(OUT.glob("page_*.json")):
        for item in json.loads(path.read_text(encoding="utf-8")):
            if (item["wfcltId"] and item["salStaNm"] in (None, "", "영업")
                    and any(t in (item["faclTyCd"] or "") for t in MEDICAL_TYPES)):
                buildings.setdefault(item["wfcltId"], item)
    return buildings


def fetch_order(buildings: dict[str, dict]) -> list[str]:
    """기구표를 받을 순서. 앱에 있는 병원과 같은 건물, 그중 병원급을 먼저 받는다."""
    regions = json.loads((APP_DATA / "regions.json").read_text(encoding="utf-8"))
    region_by_name = {r["name"]: r["code"] for r in regions} | LEGACY_REGION_NAMES
    in_app = {
        key
        for path in (APP_DATA / "hospitals").glob("*.json")
        for h in json.loads(path.read_text(encoding="utf-8"))
        if (key := building_key(path.stem, h["a"]))
    }

    def later(wid: str) -> tuple[bool, bool]:
        address = buildings[wid]["lcMnad"] or ""
        key = building_key(region_by_name.get(address.split(" ", 1)[0]), address)
        return key not in in_app, "병원" not in (buildings[wid]["faclTyCd"] or "")

    return sorted(buildings, key=later)


def fetch_evals(buildings: dict[str, dict], budget: Budget) -> dict[str, str]:
    """아직 받지 않은 건물의 기구표를 받는다."""
    evals = json.loads(EVALS.read_text(encoding="utf-8")) if EVALS.exists() else {}
    try:
        for wid in fetch_order(buildings):
            if wid in evals:
                continue
            if not budget.left():
                break
            try:
                root = call_xml(EVAL, wfcltId=wid)
            except ApiError as e:
                if any(s in str(e) for s in STOP_ERRORS):
                    print(f"기구표 받기를 멈춤: {e}")
                    break
                evals[wid] = ""  # 이 건물만의 오류(기구표 없음 등). 다시 받지 않는다.
                continue
            finally:
                budget.spend()
            evals[wid] = (root.findtext(".//evalInfo") or "").strip()
    finally:
        EVALS.write_text(json.dumps(evals, ensure_ascii=False), encoding="utf-8")
    return evals


def write_csv(buildings: dict[str, dict], evals: dict[str, str]) -> int:
    """기구표를 받은 건물을 data/facility_eval.csv 로 모은다. 가짜 응답 거르기는 build_data.py 가 한다."""
    rows = [
        {**{f: buildings[wid][f] or "" for f in CSV_FIELDS[:-1]}, "evalInfo": evals[wid]}
        for wid in sorted(buildings)
        if evals.get(wid)
    ]
    with CSV_PATH.open("w", encoding="utf-8-sig", newline="") as f:
        writer = csv.DictWriter(f, CSV_FIELDS, lineterminator="\n")
        writer.writeheader()
        writer.writerows(rows)
    return len(rows)


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--budget", type=int, default=90, help="오늘 쓸 최대 호출 수")
    args = parser.parse_args()

    OUT.mkdir(parents=True, exist_ok=True)
    budget = Budget(args.budget)
    fetch_list(budget)
    buildings = medical_buildings()
    evals = fetch_evals(buildings, budget)
    written = write_csv(buildings, evals)

    total = json.loads(META.read_text())["totalCount"] if META.exists() else None
    pages = len(list(OUT.glob("page_*.json")))
    done = sum(1 for wid in buildings if wid in evals)
    print(f"목록 {pages}/{math.ceil(total / PAGE_SIZE) if total else '?'}쪽 · 의료시설 건물 {len(buildings):,}곳 중"
          f" 기구표 {done:,}곳 · {CSV_PATH.name} {written:,}곳 · 오늘 쓴 호출 {budget.used}번")
    if not budget.left():
        print(f"오늘 한도({args.budget}번)를 다 썼습니다. 내일 다시 실행하세요.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
