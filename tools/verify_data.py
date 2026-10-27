"""build_data.py 가 만든 데이터를 배포하기 전에 검사한다.

실행: python tools/verify_data.py [--previous <지금 배포된 meta.json 의 주소나 경로>]

meta.json 의 파일 목록·sha256 이 실제 파일과 맞는지, 앱이 읽는 형식인지 본다.
--previous 를 주면 지금 배포된 데이터보다 병원 수가 크게 줄었거나 파일이 빠졌을 때 실패한다.
API 가 일부만 응답해서 반쪽짜리 데이터가 앱 사용자에게 내려가는 것을 막기 위해서다.
"""

import argparse
import hashlib
import json
import sys
import urllib.error
import urllib.request
from pathlib import Path

from build_data import OUT, SCHEMA

# 병원마다 꼭 있어야 하는 키 (lib/models/hospital.dart 의 Hospital.fromJson).
REQUIRED_KEYS = ("id", "n", "a", "y", "x")


def load_previous(source: str) -> dict | None:
    """지금 배포된 meta.json. 처음 배포라 아직 없으면 None."""
    if not source.startswith(("http://", "https://")):
        path = Path(source)
        return json.loads(path.read_text(encoding="utf-8")) if path.exists() else None
    try:
        with urllib.request.urlopen(source, timeout=60) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def check(meta: dict, previous: dict | None, min_ratio: float) -> list[str]:
    errors = []
    if meta.get("schema") != SCHEMA:
        errors.append(f"schema 가 {SCHEMA} 이 아닙니다: {meta.get('schema')}")
    for key in ("version", "generatedAt", "sources"):
        if not meta.get(key):
            errors.append(f"meta.json 에 {key} 가 없습니다.")

    files: dict[str, str] = meta.get("files") or {}
    on_disk = {"regions.json", *(p.relative_to(OUT).as_posix() for p in (OUT / "hospitals").glob("*.json"))}
    for name in sorted(on_disk ^ files.keys()):
        errors.append(f"meta.json 의 파일 목록과 실제 파일이 다릅니다: {name}")
    for name, digest in files.items():
        path = OUT / name
        if path.exists() and hashlib.sha256(path.read_bytes()).hexdigest() != digest:
            errors.append(f"sha256 이 맞지 않습니다: {name}")

    total = 0
    for region in json.loads((OUT / "regions.json").read_text(encoding="utf-8")):
        path = OUT / "hospitals" / f"{region['code']}.json"
        if not path.exists():
            errors.append(f"{region['name']}: 병원 파일이 없습니다.")
            continue
        hospitals = json.loads(path.read_text(encoding="utf-8"))
        broken = sum(1 for h in hospitals if any(h.get(k) in (None, "") for k in REQUIRED_KEYS))
        if broken:
            errors.append(f"{region['name']}: 필수 항목이 빠진 병원 {broken}곳")
        if len(hospitals) != region["count"]:
            errors.append(f"{region['name']}: regions.json 은 {region['count']}곳, 파일은 {len(hospitals)}곳")
        total += len(hospitals)
    if total != meta.get("hospitalCount"):
        errors.append(f"hospitalCount({meta.get('hospitalCount')})와 실제 병원 수({total})가 다릅니다.")

    if previous:
        before = previous.get("hospitalCount", 0)
        if total < before * min_ratio:
            errors.append(f"병원 수가 {before:,}곳에서 {total:,}곳으로 크게 줄었습니다.")
        for name in sorted(set(previous.get("files", {})) - files.keys()):
            errors.append(f"지금 배포된 데이터에 있는 {name} 이 없습니다.")
    return errors


def main() -> int:
    sys.stdout.reconfigure(encoding="utf-8")
    parser = argparse.ArgumentParser()
    parser.add_argument("--previous", help="지금 배포된 meta.json 의 주소나 경로")
    parser.add_argument("--min-ratio", type=float, default=0.9,
                        help="배포된 데이터와 비교해 이 비율보다 병원 수가 줄면 실패")
    args = parser.parse_args()

    previous = load_previous(args.previous) if args.previous else None
    if args.previous and previous is None:
        print("배포된 데이터가 아직 없어 비교하지 않습니다.")
    meta = json.loads((OUT / "meta.json").read_text(encoding="utf-8"))
    errors = check(meta, previous, args.min_ratio)
    for e in errors:
        print(f"  실패: {e}")
    if errors:
        return 1
    print(f"검사 통과: {meta['version']} · 병원 {meta['hospitalCount']:,}곳 · 파일 {len(meta['files'])}개")
    return 0


if __name__ == "__main__":
    sys.exit(main())
