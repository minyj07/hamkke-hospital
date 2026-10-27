"""인증키가 동작하는지, 어떤 API가 승인됐는지 확인한다.

실행: python tools/check_api.py
"""

import sys

from hira import ApiError, call

sys.stdout.reconfigure(encoding="utf-8")


def main() -> int:
    print("[1] 병원정보서비스 - 서울 재활의학과 병원 목록")
    try:
        body = call(
            "hospInfoServicev2",
            "getHospBasisList",
            pageNo=1,
            numOfRows=3,
            sidoCd="110000",
            dgsbjtCd="21",
        )
    except ApiError as e:
        print(f"  실패: {e}")
        return 1
    print(f"  성공: 전체 {body.get('totalCount')}곳")
    for item in body["items"]:
        fields = {k: v for k, v in item.items() if k != "ykiho"}
        print(f"  - {fields}")
    ykiho = body["items"][0]["ykiho"] if body["items"] else None

    print("\n[2] 의료기관별상세정보서비스 - 첫 병원의 진료과목")
    try:
        detail = call("MadmDtlInfoService2.8", "getDgsbjtInfo2.8", ykiho=ykiho)
        names = [i.get("dgsbjtCdNm") for i in detail["items"]]
        print(f"  성공: {names}")
    except ApiError as e:
        print(f"  실패: {e}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
