# 함께병원

장애 유형·정도와 필요한 진료를 고르면, 정부 지정 기관(재활병원·건강주치의 등)·진료과·편의시설·거리를
따져 병원을 추천하는 Flutter 앱입니다. 병원 데이터는 앱에 들어 있어 인터넷 없이도 동작하고,
새 데이터가 올라오면 바뀐 파일만 내려받습니다.

- **홈·하단 탭**: 홈 / 병원 찾기 / 진료 카드 / 즐겨찾기. 처음 켜면 안내 3장(건너뛰기 가능), 설정은 홈 오른쪽 위
- **조건으로 찾기** (6단계, 진행 표시·이전 버튼): 장애 유형 → 정도 → 필요한 진료 → 나이(어린이·성인) → 필요한 편의시설
  → 지역(또는 현재 위치). 지난번 조건과 진료 카드의 장애 정보로 미리 골라 둔다
- **결과**: 추천순·가까운 순, 지정 기관만·편의시설 정보 있는 곳만·5/10/20km 거르기, 목록/지도(네이버 지도 키가 있을 때),
  없는 편의시설 경고, 결과가 없으면 이웃 시·도까지 넓히기·진료 목적 바꾸기
- **이름으로 찾기**: 전국 병원을 이름·지역·종별로 바로 검색
- **병원 정보**: 종별, 주소, 전화, 의사·전문의 수, 개원 연도, 홈페이지, 지정 현황(제도 설명 ‘?’), 진료과목,
  편의시설 있음·없음·정보 없음, 데이터 기준일
- **바로 하기**: 전화, 길찾기, 지도, 가족에게 공유, 즐겨찾기, 진료 카드 보여 주기, 정보가 틀렸어요(메일 신고)
- **나의 진료 카드**: 장애·소통 방법·필요한 도움·주의할 점·병·약·알레르기·보호자. 병원에 보여 주기(큰 글씨, 화면 켜 둠),
  자주 쓰는 문장 크게 보기, 보호자 바로 전화. 휴대폰 보안 저장소에 암호화해서 둔다
- **즐겨찾기·최근 본 병원 20곳**, 목록에서 바로 전화·길찾기
- **설정**: 글자 크기 100~200%, 고대비, 앱 잠금(지문·얼굴·휴대폰 비밀번호), 내 정보 전부 지우기, 데이터 기준일·출처,
  개인정보 처리방침, 오픈소스 라이선스, 문의
- 장애·건강 정보는 기기에만 두고 앱 밖으로 보내지 않으며 휴대폰 백업에서도 뺀다

## 개발

Flutter 3.47 이상(Dart 3.13.5 이상)이 필요합니다.

```bash
flutter pub get
flutter test
flutter run
```

빌드할 때 `--dart-define` 으로 바꾸는 값 (`lib/config.dart`):

| 이름 | 기본값 | 내용 |
|---|---|---|
| `NAVER_MAP_CLIENT_ID` | 없음 | 네이버 클라우드 플랫폼 Maps → Application(Dynamic Map, 패키지 `kr.hamkkehospital.app`)의 Client ID. 없으면 결과의 지도 보기를 숨긴다 |
| `CONTACT_EMAIL` | minyj07@gmail.com | 정보 오류 신고·문의 메일. 빈 값이면 버튼을 숨긴다 |
| `DATA_BASE_URL` | data 브랜치 주소 | 새 병원 데이터를 받는 곳. 빈 값이면 앱에 든 데이터만 쓴다 |

```bash
flutter build apk --release --split-per-abi --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID   # 휴대폰용: app-arm64-v8a-release.apk (약 48MB)
flutter build appbundle --release --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID             # 스토어용
```

ABI 를 모두 넣은 하나의 APK(`flutter build apk --release`)는 네이버 지도 SDK 때문에 120MB 가 넘으니, 휴대폰에는
ABI 별 APK 를, 스토어에는 AAB 를 씁니다.

### 스토어에 올리기 전: 서명 키

`android/key.properties` 가 있으면 릴리스 빌드를 그 키로 서명하고, 없으면(CI, 시험용) 디버그 키로 서명합니다.
키 파일과 `key.properties` 는 저장소에 올리지 않습니다 (`android/.gitignore`). 키를 잃어버리면 같은 앱으로
업데이트를 올릴 수 없으니 안전한 곳에 따로 보관합니다.

```bash
keytool -genkey -v -keystore "$USERPROFILE/hamkke-upload.jks" -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

```properties
# android/key.properties
storePassword=<키 저장소 비밀번호>
keyPassword=<키 비밀번호>
keyAlias=upload
storeFile=C:/Users/<사용자>/hamkke-upload.jks
```

### 앱 아이콘과 홈 화면 바로가기

- 아이콘 원본은 `assets/icon/` 에 있고(앱에는 넣지 않음), 바꾸면 `dart run flutter_launcher_icons` 로
  안드로이드(적응형·테마 아이콘 포함)와 iOS 아이콘을 다시 만듭니다. 스플래시 배경색은
  `android/app/src/main/res/values/colors.xml` 의 `splash_background` 입니다.
- 홈 화면에서 앱 아이콘을 길게 누르면 '병원 찾기', '진료 카드 보여 주기', '즐겨찾기' 바로가기가 나옵니다
  (`quick_actions`, `lib/main.dart` 의 `_setUpShortcuts`, 아이콘은 `res/drawable/ic_shortcut_*.xml`).
  바로가기 아이콘은 이름으로 찾는 리소스라 릴리스 빌드의 리소스 축소에서 지워지지 않게 `res/raw/keep.xml` 에 적어 둡니다.

PR 과 푸시마다 GitHub Actions(`.github/workflows/ci.yml`)가 `flutter analyze`, `flutter test`, Python 스크립트
테스트, 앱에 든 데이터 검사를 돌립니다. Flutter 를 올리면 이 파일의 `flutter-version` 도 함께 바꿉니다.

장애·건강 정보가 든 파일은 휴대폰 백업에서 뺍니다: 검색 조건(`last_search.json`), 즐겨찾기(`favorites.json`),
최근 본 병원(`recent_hospitals.json`), 진료 카드(안드로이드 `FlutterSecureStorage.xml`·`FlutterSecureKeyStorage.xml`,
iOS 는 이 기기에서만 읽는 키체인), 내려받은 병원 데이터(`hospital_data/`). 화면 설정(`settings.json`)은 백업합니다.
안드로이드는 `android/app/src/main/res/xml` 의 두 규칙, iOS 는 `ios/Runner/AppDelegate.swift` 가 맡고,
`test/backup_rules_test.dart` 가 파일 이름과 규칙이 맞는지 검사합니다. 기기에 새로 저장하는 데이터가
생기면 백업해도 되는지 정해서 규칙에 반영합니다.

| 경로 | 내용 |
|---|---|
| `lib/screens/` | 하단 탭(`app_shell.dart`), 홈, 병원 찾기(`find_screen.dart`), 결과·지도, 병원 상세, 진료 카드, 즐겨찾기, 설정, 앱 잠금 |
| `lib/screens/app_scope.dart` | 화면들이 함께 쓰는 저장소·기기 기능(`AppServices`) |
| `lib/services/recommender.dart` | 사용자 조건을 요구사항으로 바꾸고 병원마다 점수를 매긴다 |
| `data/scoring.json` | 추천 점수표. 데이터와 함께 배포해서 앱을 업데이트하지 않고 고친다 (`lib/services/score_weights.dart` 의 기본값과 이름이 같아야 한다) |
| `HANDOFF.md` | 진행 중인 작업과 남은 일 (인수인계 노트) |
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
- 기구표로 없다고 확인된 시설은 병원 파일의 `fx` 에 적어서 앱이 ‘없음’으로 경고하고, 기구표가 없는 병원은 ‘정보 없음’으로
  보여 줍니다 (정보가 없다고 추천 순서를 낮추지 않습니다).
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
