# 함께병원

장애 유형·정도와 필요한 진료를 고르면, 정부 지정 기관(재활병원·건강주치의 등)·진료과·편의시설·거리를
따져 병원을 추천하는 Flutter 앱입니다. 병원 데이터는 앱에 들어 있어 인터넷 없이도 동작하고,
새 데이터가 올라오면 바뀐 파일만 내려받습니다.

## 개발

Flutter 3.47 이상(Dart 3.13.5 이상)이 필요합니다.

```bash
flutter pub get
flutter test
flutter run
```

PR 과 푸시마다 GitHub Actions(`.github/workflows/ci.yml`)가 `flutter analyze`, `flutter test`, Python 스크립트
테스트, 앱에 든 데이터 검사를 돌립니다. Flutter 를 올리면 이 파일의 `flutter-version` 도 함께 바꿉니다.

앱이 기기에 저장하는 검색 조건(`last_search.json`, 장애 정보 포함)과 내려받은 병원 데이터(`hospital_data/`)는
휴대폰 백업에서 뺍니다. 안드로이드는 `android/app/src/main/res/xml` 의 두 규칙, iOS 는 `ios/Runner/AppDelegate.swift`
가 맡고, `test/backup_rules_test.dart` 가 파일 이름과 규칙이 맞는지 검사합니다. 기기에 새로 저장하는 데이터가
생기면 백업해도 되는지 정해서 규칙에 반영합니다.

| 경로 | 내용 |
|---|---|
| `lib/screens/` | 조건 입력 → 추천 목록 → 병원 상세 화면 |
| `lib/services/recommender.dart` | 사용자 조건을 요구사항으로 바꾸고 병원마다 점수를 매긴다 |
| `lib/data/hospital_repository.dart` | 지역·병원 데이터를 읽어 모델로 바꾼다 |
| `lib/data/data_store.dart` | 앱에 든 데이터와 새로 받은 데이터 중 새것을 고르고, 새 데이터를 받는다 |
| `tools/build_data.py` | 공공데이터 API·CSV 로 `assets/data/` 를 만든다 |
| `tools/fetch_facilities.py` | 장애인편의시설 목록과 건물별 기구표를 받아 `data/facility_eval.csv` 를 만든다 |
| `tools/verify_data.py` | 배포하기 전에 데이터를 검사한다 |
| `.github/workflows/update-data.yml` | 매주 데이터를 새로 만들어 GitHub Pages 에 올린다 |
| `.github/workflows/ci.yml` | PR·푸시마다 analyze 와 테스트를 돌린다 |

## 병원 데이터 만들기

Python 3.10 이상과 [공공데이터포털](https://www.data.go.kr) 인증키(건강보험심사평가원 병원정보서비스)가 필요합니다.

1. `tools/.env.example` 을 `tools/.env` 로 복사하고 인증키를 넣습니다.
2. `python tools/build_data.py --refresh`
3. `python tools/verify_data.py`

앱을 새로 출시하기 전에 이렇게 데이터를 새로 만들어 두면 설치 직후부터 최신 데이터를 씁니다.
스크립트를 고쳤다면 `python -m unittest discover -s tools` 로 테스트합니다.

### 편의시설 (휠체어 접근·장애인 주차·장애인 화장실·점자·음성 안내)

한국사회보장정보원 장애인편의시설 API(같은 인증키로 활용신청)의 건물별 기구표를 쓴다.

1. `python tools/fetch_facilities.py` 를 하루 한 번 실행합니다. 목록을 다 받은 뒤, 영업 중인 의료시설
   건물의 기구표를 앱 병원이 있는 건물·병원급부터 받아 `data/facility_eval.csv` 에 모읍니다.
2. 받은 만큼 `data/facility_eval.csv` 를 커밋합니다. `build_data.py` 와 주간 자동 업데이트가 이 파일을 씁니다.

- 기구표는 건물 하나에 한 번 호출해야 하는데 개발계정은 **하루 100건**입니다. 목록이 182쪽(18만 곳), 의료시설 건물이
  약 5,400곳(2026-10 추정)이라 개발계정으로는 두 달쯤 걸립니다. data.go.kr 에서 활용사례를 등록하고
  **운영계정 트래픽 증가**를 신청한 뒤 `--budget` 을 올리면 하루이틀에 끝납니다.
- 기구표는 건물 단위라 도로명 주소(시·군·구, 도로명, 건물번호)가 같은 병원 모두에 적용합니다.
  휠체어 접근은 주출입구 접근로·턱 없는 입구·출입문이 모두 있고, 승강기가 있거나 주소에 지상 1층만 적힌 경우입니다.
- 기구표를 쓰지 않은 건물은 모든 항목이 채워진 가짜 응답이 와서 버립니다. 처음 보는 항목이 나오면
  `build_data.py` 가 알려 주니 `EVAL_ITEMS` 에 넣을지 정합니다.

## 병원 데이터 자동 업데이트

```text
공공데이터 API → build_data.py → verify_data.py → GitHub Pages (/v1/)    매주, GitHub Actions
                                                        ↑
설치된 앱 ── 켤 때 meta.json 확인 → sha256 이 바뀐 파일만 받아 검증 → 모두 받으면 meta.json 교체
```

- 인증키는 GitHub 시크릿에만 있고 앱에는 들어가지 않습니다. 앱은 공개된 JSON 만 받습니다.
- 받다가 끊기거나 내용이 sha256 과 다르면 예전 데이터를 그대로 씁니다.
- 앱을 업데이트해서 앱에 든 데이터가 더 새로우면, 받아 둔 데이터를 지우고 앱에 든 것을 씁니다.
- 앱 첫 화면 오른쪽 위의 업데이트 버튼에서 데이터 기준일을 보고 바로 확인할 수 있습니다.

### 처음 한 번 설정

앱은 `https://raw.githubusercontent.com/minyj07/hamkke-hospital/data/v1/` 에서 받습니다(`lib/main.dart` 의 기본값).
워크플로가 판마다 커밋 하나짜리 `data` 브랜치로 덮어써 올립니다. GitHub Pages 에도 함께 올리지만 이 계정의 Pages 는
사용자 지정 도메인 때문에 HTTP 로만 열려서 앱은 쓰지 않습니다.

1. 이 프로젝트를 GitHub 저장소에 올립니다. GitHub Pages 는 공개 저장소이거나 유료 플랜이어야 합니다.
2. 저장소 **Settings → Secrets and variables → Actions → New repository secret** 에
   `DATA_GO_KR_SERVICE_KEY` 를 만들고 공공데이터포털 일반 인증키(Decoding)를 넣습니다.
3. **Settings → Pages → Build and deployment → Source** 를 **GitHub Actions** 로 바꿉니다.
4. **Actions → 병원 데이터 갱신 → Run workflow** 로 처음 배포합니다. 이후 매주 월요일 새벽 3시(한국 시간)에 실행됩니다.
   `build` 를 끄면 API 를 부르지 않고 저장소의 `assets/data` 를 그대로 배포합니다.
5. 저장소 이름이나 계정이 바뀌면 빌드할 때 주소를 넣습니다. 빈 값을 넣으면 앱에 든 데이터만 씁니다.

   ```bash
   flutter build apk --dart-define=DATA_BASE_URL=https://<계정>.github.io/<저장소>/v1/
   ```

### 알아 둘 것

- 병원 수가 지난 배포보다 10% 넘게 줄거나 시·도 파일이 빠지면 배포하지 않습니다. API 가 일부만 응답한 경우를
  막기 위해서입니다. 시·도 통합처럼 의도한 변화라면 Run workflow 에서 `force` 를 켭니다.
- 공개 저장소에 60일 동안 활동이 없으면 GitHub 이 예약 실행을 멈춥니다. Actions 탭에서 다시 켜 주세요.
- GitHub 서버(해외)에서 공공데이터 API 호출이 막히면 국내 PC 를 self-hosted runner 로 쓰거나,
  국내에서 `build_data.py` 를 실행한 결과를 올리도록 바꿔야 합니다.
- 예전 앱이 읽지 못하게 데이터 형식을 바꿀 때는 `tools/build_data.py` 의 `SCHEMA` 와
  `lib/data/data_store.dart` 의 `dataSchema` 를 함께 올리고, 새 형식은 `v2/` 에 배포합니다.
  예전 앱은 계속 `v1/` 을 봅니다.
