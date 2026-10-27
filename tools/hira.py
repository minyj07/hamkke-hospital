"""건강보험심사평가원(HIRA) 공공데이터 API 클라이언트.

표준 라이브러리만 사용한다. 인증키는 tools/.env 의 DATA_GO_KR_SERVICE_KEY 에서 읽고,
어떤 출력·오류 메시지에도 키가 드러나지 않게 한다.
"""

import json
import urllib.error
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from pathlib import Path

BASE_URL = "https://apis.data.go.kr/B551182"
ENV_PATH = Path(__file__).with_name(".env")


class ApiError(Exception):
    pass


def load_key() -> str:
    if not ENV_PATH.exists():
        raise ApiError(f"{ENV_PATH} 파일이 없습니다. .env.example 을 참고해 만들어 주세요.")
    for line in ENV_PATH.read_text(encoding="utf-8").splitlines():
        name, sep, value = line.partition("=")
        if sep and name.strip() == "DATA_GO_KR_SERVICE_KEY":
            key = value.strip().strip('"').strip("'")
            if not key:
                break
            # Encoding 키(%2B 등)를 붙여넣었어도 동작하도록 한 번 디코딩한다.
            return urllib.parse.unquote(key) if "%" in key else key
    raise ApiError("tools/.env 에 DATA_GO_KR_SERVICE_KEY 값이 비어 있습니다.")


def _redact(text: str, key: str) -> str:
    for k in {key, urllib.parse.quote(key, safe=""), urllib.parse.quote_plus(key)}:
        text = text.replace(k, "***")
    return text


def _gateway_error(root: ET.Element) -> str | None:
    """data.go.kr 게이트웨이 오류(키 미등록, 트래픽 초과 등)는 _type=json 이어도 XML로 온다."""
    auth = root.findtext(".//returnAuthMsg")
    if auth:
        return f"{auth} (code {root.findtext('.//returnReasonCode')})"
    code = root.findtext(".//resultCode")
    if code and code not in ("00", "0"):
        return f"{root.findtext('.//resultMsg')} (code {code})"
    return None


def call(service: str, operation: str, **params) -> dict:
    """API를 호출해 body 부분(dict)을 돌려준다. items 는 항상 list 로 정규화한다."""
    key = load_key()
    query = urllib.parse.urlencode({"serviceKey": key, "_type": "json", **params})
    url = f"{BASE_URL}/{service}/{operation}?{query}"
    try:
        with urllib.request.urlopen(url, timeout=60) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        body = e.read().decode("utf-8", "replace")[:300]
        raise ApiError(_redact(f"HTTP {e.code} {e.reason}: {body}", key)) from None
    except urllib.error.URLError as e:
        raise ApiError(_redact(f"네트워크 오류: {e.reason}", key)) from None

    if raw.lstrip().startswith("<"):
        root = ET.fromstring(raw)
        err = _gateway_error(root)
        if err:
            raise ApiError(err)
        raise ApiError("JSON 대신 XML 응답이 왔습니다: " + _redact(raw[:300], key))

    data = json.loads(raw)
    header = data.get("response", {}).get("header", {})
    if str(header.get("resultCode")) not in ("00", "0"):
        raise ApiError(f"{header.get('resultMsg')} (code {header.get('resultCode')})")

    body = data["response"]["body"]
    items = body.get("items") or {}
    item = items.get("item", []) if isinstance(items, dict) else []
    body["items"] = item if isinstance(item, list) else [item]
    return body


def call_xml(path: str, **params) -> ET.Element:
    """XML 로만 응답하는 API 를 호출한다. path 는 '기관코드/서비스/오퍼레이션'.

    예: call_xml("B554287/DisabledPersonConvenientFacility/getDisConvFaclList", pageNo=1)
    """
    key = load_key()
    url = f"https://apis.data.go.kr/{path}?" + urllib.parse.urlencode({"serviceKey": key, **params})
    try:
        with urllib.request.urlopen(url, timeout=120) as resp:
            raw = resp.read().decode("utf-8")
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8", "replace")
    except urllib.error.URLError as e:
        raise ApiError(_redact(f"네트워크 오류: {e.reason}", key)) from None
    try:
        root = ET.fromstring(raw)
    except ET.ParseError:
        raise ApiError("XML 이 아닌 응답: " + _redact(raw[:300], key)) from None
    err = _gateway_error(root)
    if err is None and root.findtext("resultCode") not in (None, "0", "00"):
        err = f"{root.findtext('resultMessage')} (code {root.findtext('resultCode')})"
    if err:
        raise ApiError(err)
    return root
