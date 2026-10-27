# 함께병원 인수인계 노트

2026-10-27 작성. 다른 계정(새 Claude 세션)에서 이어서 작업할 때 이 파일부터 읽으세요.

## 1. 지금 상태 한눈에

- **하던 일**: 기획서(`C:\Users\minyj\OneDrive\문서\카카오톡 받은 파일\기획서.md`, v1.0, 2026-10-24)대로 앱을 MVP 수준으로 고치는 중.
- **코드**: 기획서 P0 과 P1 대부분을 구현했다. `flutter analyze` 문제 없음, Flutter 테스트 104개와 Python 테스트 19개가 통과한다.
- **아직 안 한 것**: 에뮬레이터·실기기 확인, 추천 시나리오 테스트 30개, 접근성 자동 점검 테스트, 푸시. 자세한 순서는 [3장](#3-바로-이어서-할-일-순서대로)에 있다. README 는 새 기능에 맞게 고쳐 두었다.
- **Git**:
  - 저장소는 `github.com/minyj07/hamkke-hospital` 의 `main` 이다. `1d58a50` 이 1단계(이름 검색·즐겨찾기 등)다.
  - **이번 작업은 로컬 `main` 에 커밋했고, 푸시는 하지 않았다** (사용자 요청). `git log` 맨 위 커밋이다.
  - 그래서 `origin/main` 은 아직 `1d58a50` 이고 CI 도 돌지 않았다. 푸시는 사용자에게 먼저 물어본다.
  - 커밋 메시지 끝에는 `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>` 을 붙인다.

## 2. 사용자가 정한 것

| 항목 | 결정 | 코드 위치 |
|---|---|---|
| 지도 SDK (기획서 미결 1) | **네이버 지도** (`flutter_naver_map` 1.4.4) | `lib/screens/results_map.dart`, `lib/main.dart` 의 `_initMap` |
| 네이버 지도 키 | 저장소에 넣지 않는다. 빌드할 때 `--dart-define=NAVER_MAP_CLIENT_ID=...` 로 넣고, 없으면 결과 화면의 목록/지도 버튼을 숨긴다. 키는 사용자가 직접 발급한다 (NCP 콘솔 → Maps → Application 등록 → Dynamic Map, 패키지 `kr.hamkkehospital.app`). | `lib/config.dart` |
| 신고·문의 메일 | **minyj07@gmail.com**. 앱과 공개 저장소에 드러나는 것을 사용자가 승인했다. `--dart-define=CONTACT_EMAIL=` 로 바꿀 수 있다. | `lib/config.dart` |
| 잠겨 있을 때 진료 카드 공개 (미결 4) | 기본은 **안 보이게**. 설정에서 '잠겨 있어도 병원에 보여 주기 열기'를 켤 수 있다. | `lib/data/app_settings.dart` |
| 상태 관리 | Riverpod 를 쓰지 않고 기존 방식(ChangeNotifier + `AppScope` InheritedWidget)을 유지한다. | `lib/screens/app_scope.dart` |
| 익명 사용 통계 (미결 5) | 넣지 않았다. 아직 정하지 않음. | — |

## 3. 바로 이어서 할 일 (순서대로)

1. **APK 크기 정리**: 릴리스 빌드는 되지만 하나로 묶은 APK 가 124MB 다 ([7장](#7-빌드-확인-기록)). 휴대폰 시험용은 `--split-per-abi` 의 arm64 APK 를 쓰고, 지도 SDK 크기를 사용자와 상의한다.
2. **에뮬레이터로 전체 화면 점검** (AVD `Medium_Phone_API_37.0`). 이번에 새로 들어가 아직 기기에서 돌려 보지 않은 것:
   - 앱 잠금 (`local_auth`): MainActivity 를 `FlutterFragmentActivity` 로 바꿨고 테마는 AppCompat 이다. PIN 은 `adb shell locksettings set-pin 1234`, 지문은 `adb -e emu finger touch 1` 로 시험한다.
   - 진료 카드 보안 저장 (`flutter_secure_storage` 11.2.0).
   - 화면 켜 두기 (`wakelock_plus`).
   - 메일 앱 열기 (신고·문의).
   - 첫 실행 안내 → 홈 → 하단 탭 4개 → 병원 찾기 6단계 → 결과 → 상세 → 진료 카드 → 설정.
   - TalkBack 으로 결과 카드가 '이름, 거리, 추천 이유, 경고' 순으로 읽히는지 본다.
   - 휴대폰 글꼴을 200%로 놓고 잘림이 없는지 본다.
3. **추천 시나리오 테스트 30개** (기획서 7.2, 12.3 완료 기준). `test/recommender_scenarios_test.dart` 를 새로 만든다.
   - 장애 유형 × 진료 목적 × 나이 대표 조합마다 기대 1순위·포함·제외를 표로 적는다.
   - `test/recommender_test.dart` 의 `hospital()`·`profile()` 도우미를 쓰면 된다.
4. **접근성 자동 점검 테스트**:
   - 설정의 `textScale: 2.0` 과 화면 크기 360×640 으로 주요 화면을 모두 열어, 넘침(RenderFlex overflow)이 없는지 본다.
   - `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` 을 통과하는지 본다.
5. (README 는 갱신함: 새 기능, `--dart-define` 3개, 새 파일 구조, 백업 제외 목록.)
6. **푸시** (사용자 승인 후). 커밋은 해 두었다. 푸시한 뒤 GitHub CI(`ci.yml`)를 확인한다.
7. **데이터 배포**:
   - Actions → 병원 데이터 갱신 → Run workflow 를 돌려 `data` 브랜치에 `scoring.json` 을 올린다. `build=false` 여도 된다.
   - 지금 `data` 브랜치에는 `scoring.json` 이 없다. 그래도 앱은 앱에 든 점수표를 쓰므로 문제없다.
8. **네이버 지도 키**를 받으면 지도 화면을 실기기에서 처음 확인한다. `results_map.dart` 는 아직 한 번도 실행해 보지 않았다.

## 4. 기획서 대비 구현 현황

| 기획서 | 상태 | 비고 |
|---|---|---|
| 6.1 홈 (큰 버튼 3개, 지난번 조건, 첫 실행 안내 3장) | 완료 | `home_screen.dart`, `onboarding_screen.dart` |
| 8장 하단 탭 4개 (홈/병원 찾기/진료 카드/즐겨찾기), 설정은 홈 오른쪽 위 | 완료 | `app_shell.dart`. 뒤로 가기를 누르면 찾기는 이전 단계로, 다른 탭은 홈으로 간다. |
| 6.2 진행 표시 'N / 6 단계', 이전 버튼 | 완료 | `find_screen.dart` |
| 6.2 지난번 조건·진료 카드로 미리 채우기 | 완료 | 1·2단계는 카드 장애 정보가 우선이다. |
| 6.2 [P1] 나이대 (어린이/성인) | 완료 | 어린이면 공공어린이재활 기관과 소아청소년과를 가산한다. |
| 6.2 [P1] 편의시설 직접 선택 | 완료 | 자동 추정값을 체크해 두고 고칠 수 있다. 직접 고르면 +12/−10. |
| 6.3 카드 (지정 기관 배지, 추천 이유 3줄, 없는 시설 경고) | 완료 | 화면낭독기용 라벨은 '번호. 이름, 거리, 지정 기관, 이유…, 확인 필요' 순서다. |
| 6.3 목록/지도 전환 | 코드 완료, **실행 미확인** | 네이버 지도 키가 있어야 보인다. |
| 6.3 필터 (지정 기관만, 편의시설 정보 있는 곳만, 5/10/20km), 정렬 | 완료 | |
| 6.3 0건이면 '조건을 넓혀 볼까요?' | 완료 | 거르기 끄기, 이웃 시·도까지 찾기(`neighborRegions`), 진료 목적 바꾸기(찾기 3단계로) |
| 6.4 상세: 편의시설 있음/없음/정보 없음 | 완료 | 정보 없음을 없음으로 보이지 않는다. |
| 6.4 상세: 즐겨찾기·공유·지도·진료 카드 보여 주기·데이터 기준일 | 완료 | 버튼은 글자가 크면 한 줄에 하나씩 놓인다. |
| 6.4 [P1] 진료 시간 | 문구만 | '진료 시간과 쉬는 날은 병원에 전화로 확인하세요.' 아래 '남은 데이터 작업' 참고. |
| 6.5 나의 진료 카드 (입력, 병원에 보여 주기, 큰 글씨·고대비, 화면 켜 두기, 가로 화면) | 완료 | 문장형 표시를 하고, 조사(이/가, 예요/이에요)를 받침에 맞춘다. |
| 6.5 [P1] 자주 쓰는 문장, 보호자 바로 전화 | 완료 | |
| 6.5 [P1] 앱 잠금 (생체·PIN) | 코드 완료, **실기기 미확인** | 1분 넘게 다른 앱에 있다 오면 다시 잠근다. |
| 6.5 [P2] 카드 이미지 저장·공유 | 안 함 | 로드맵 |
| 6.6 즐겨찾기 + 최근 본 병원 20곳, 목록에서 바로 전화·길찾기 | 완료 | `saved_hospitals.dart` |
| 6.7 설정 (글자 1.0~2.0배, 고대비, 내 정보 전부 지우기, 기준일·출처·업데이트, 처리방침, 라이선스, 문의, 버전) | 완료 | `settings_screen.dart`, `privacy_screen.dart` |
| 6.8 [P1] 정보 오류 신고 (메일) | 완료 | 병원 ID·앱 버전·데이터 기준일만 붙이고 개인 정보는 넣지 않는다. |
| 7.2 [P0] 편의시설 정보 없으면 감점 안 함 | 완료 | `Recommendation.unknown` |
| 7.2 [P1] 점수표 설정 파일 분리 | 완료 | `data/scoring.json` → 데이터와 함께 배포하므로 앱 업데이트 없이 바뀐다. |
| 7.2 시나리오 테스트 30개 | **남음** | 3장 3번 |
| 9장 접근성 | 대부분 반영, **자동 점검 테스트 남음** | 아래 '접근성에서 한 것' 참고 |
| 10장 진료 카드 보안 저장소 | 완료 | 안드로이드는 Keystore 로 암호화하고 백업에서 뺀다. iOS 는 키체인 `first_unlock_this_device` 다. |
| 4.2-6 편의시설 데이터 채우기 | 사용자 몫 | `tools/fetch_facilities.py` 를 하루 한 번 돌린다. 개발계정은 하루 100건이라 운영계정 신청이 필요하다. |

**접근성에서 한 것**:
- 모든 아이콘 버튼에 툴팁(라벨)이 있다.
- 제목에 `Semantics(header)` 를 달았다.
- 결과 카드는 한 번에 읽힌다.
- 경고는 아이콘과 글로 함께 보여 준다.
- 버튼 높이는 48~56dp 다.
- 지도는 `ExcludeSemantics` 로 감싸서 화면낭독기가 읽지 않게 하고, 같은 내용을 아래 카드에서 이전·다음으로 읽게 했다.
- 업데이트 결과처럼 바뀌는 문구는 `liveRegion` 으로 읽어 준다.
- 저절로 넘어가는 화면이 없다.
- 지정 기관마다 '?' 도움말이 있다 (`help.dart`).

## 5. 코드 구조 (이번에 생기거나 크게 바뀐 파일)

```text
lib/config.dart                   DATA_BASE_URL, NAVER_MAP_CLIENT_ID, CONTACT_EMAIL (--dart-define)
lib/main.dart                     서비스 만들기, 테마(고대비), 글자 크기, LockGate, 첫 실행 분기(_Start)
lib/models/care_card.dart         진료 카드, 소통 방법·필요한 도움 enum, 자주 쓰는 문장
lib/models/korean.dart            받침에 맞는 조사
lib/models/hospital.dart          + absentFacilities(fx), FacilityStatus, hasFacilityInfo
lib/models/search_conditions.dart + age, facilities(직접 고른 편의시설)
lib/data/saved_hospitals.dart     즐겨찾기·최근 본 병원 (예전 favorites.dart 를 대신한다)
lib/data/app_settings.dart        settings.json (글자 크기, 고대비, 첫 실행, 잠금)
lib/data/care_card_store.dart     보안 저장소 + 재설치 감지 표시 파일(care_card_saved)
lib/data/last_search_store.dart   + LastSearch (ChangeNotifier)
lib/data/regions.dart             + neighborRegions (시·도 인접표, 광주는 360000 에 합쳐짐)
lib/data/hospital_repository.dart + loadWeights() (scoring.json, 없으면 기본값)
lib/services/score_weights.dart   추천 점수표
lib/services/recommender.dart     나이, 직접 고른 시설 가중치, 있음/없음/정보 없음, suggestedFacilities()
lib/services/app_lock.dart        local_auth 래퍼
lib/screens/app_scope.dart        AppServices(모든 서비스) + AppScope, clearPersonalData()
lib/screens/app_shell.dart        하단 탭, 뒤로 가기 처리, editSearch()
lib/screens/home_screen.dart      홈
lib/screens/onboarding_screen.dart 첫 실행 안내
lib/screens/find_screen.dart      병원 찾기 6단계 (예전 profile_screen.dart 를 대신한다)
lib/screens/results_launcher.dart 조건으로 찾아 결과 열기 (홈·찾기가 함께 쓰는 mixin)
lib/screens/results_screen.dart   결과 목록·필터·넓히기, ResultsExit
lib/screens/results_map.dart      네이버 지도 보기
lib/screens/hospital_detail_screen.dart 상세
lib/screens/hospital_actions.dart 전화·길찾기·지도·공유 (상세·즐겨찾기가 함께 씀)
lib/screens/report_screen.dart    정보가 틀렸어요 (mailto)
lib/screens/care_card_screen.dart 진료 카드 탭, 병원에 보여 주기, 자주 쓰는 문장
lib/screens/care_card_edit_screen.dart 카드 만들기·고치기
lib/screens/settings_screen.dart  설정 (예전 '병원 정보 업데이트' 대화상자도 여기로 옮김)
lib/screens/privacy_screen.dart   개인정보 처리방침
lib/screens/lock_gate.dart        앱 잠금 화면
lib/screens/help.dart             지정 기관 설명
lib/screens/data_notice.dart      '공공데이터 기준이라 실제와 다를 수 있어요…' 안내
test/fakes.dart                   화면 테스트용 가짜 저장소·앱 만들기·도우미
test/card_and_settings_test.dart  진료 카드·설정·잠금 화면 테스트
```

## 6. 데이터 형식 변경 (예전 앱과 호환됨)

- **`hospitals/*.json` 의 `fx`**: 장애인편의시설 기구표로 '없다'고 확인된 시설이다. `f` 는 있는 시설이고, `f`·`fx` 어디에도 없으면 정보 없음이다. 예전 앱은 `fx` 를 무시한다.
  - 휠체어 판정: 입구를 모두 갖추고 승강기가 있거나 지상 1층이면 있음. 입구가 모자라거나 승강기 없이 다른 층이면 없음. 층을 모르면 정보 없음.
  - 한 건물에 기구표가 여럿이면, 모두 있다고 한 것만 있음이고 모두 없다고 한 것만 없음이다.
- **`scoring.json`**: 원본은 `data/scoring.json` 이다. `tools/build_data.py` 가 `assets/data/` 로 복사하고 `meta.json` 에 해시를 넣는다.
  - `tools/verify_data.py` 가 이름과 숫자를 검사한다.
  - 앱은 이 파일이 없거나 망가졌으면 `ScoreWeights.standard` 를 쓴다.
  - 점수를 고치면 `data/scoring.json` 과 `lib/services/score_weights.dart` 의 기본값을 함께 맞춘다. `test/recommender_test.dart` 가 이름 목록이 같은지 검사한다.
- **`assets/data/meta.json`**: `files` 에 `scoring.json` 만 더했다. `version` 은 `2026-10-27T08:45:43Z` 그대로다.
- **`.gitattributes`**: `assets/data/** -text` 라서 `scoring.json` 도 줄바꿈이 바뀌지 않는다.

**남은 데이터 작업** (기획서 P1, 사용자와 상의 필요):
- **진료 시간**: 심평원 의료기관별상세정보서비스 `getDtlInfo` 로 받을 수 있다.
  - 개발계정은 하루 1만 건이라 6만여 곳을 받는 데 7일쯤 걸린다.
  - 받으면 `build_data.py` 에 합치고, 상세 화면의 '진료 시간' 문구를 바꾼다.
- **편의시설 수집**: `fetch_facilities.py` 를 매일 돌린다. 지금 `data/facility_eval.csv` 는 머리글만 있다.

## 7. 빌드 확인 기록

- 2026-10-27 `flutter build apk --release` (지도 키 없음): **성공**. `build\app\outputs\flutter-apk\app-release.apk` 가 **124.2MB** 다 (1단계 APK 는 54MB 였다).
  - 늘어난 원인은 네이버 지도 SDK 의 `libnavermap.so` 다. ABI 하나에 24.5MB(압축)이고, 지도 키가 없어도 들어간다.
  - ABI 별 크기: arm64 42.9MB, x86_64 45.8MB, armeabi-v7a 34.5MB. 데이터를 포함한 assets 는 4.6MB 다.
  - 휴대폰에 설치할 APK 는 `flutter build apk --release --split-per-abi` 로 만들어 `app-arm64-v8a-release.apk` (약 50MB 예상)를 쓴다.
  - 기획서 12.2 의 '데이터 포함 50MB 이하'는 스토어에는 AAB(`flutter build appbundle`)로 올려서 기기별로 받게 하면 맞출 수 있다. 지도 SDK 를 계속 쓸지는 사용자와 다시 정한다.
  - 빌드 경고: `flutter_naver_map` 이 Kotlin Gradle Plugin 을 직접 적용해서, 이후 Flutter 버전에서는 빌드가 실패할 수 있다고 나온다. Flutter 를 올리기 전에 플러그인 새 버전을 확인한다.

## 8. 명령 모음

```bash
export PATH="/c/dev/flutter/bin:$PATH"   # Git Bash 에서 Flutter 쓰기
flutter analyze
flutter test                                    # 104개
python -m unittest discover -s tools            # 19개
python tools/verify_data.py                     # 앱에 든 데이터 검사
flutter build apk --release                     # 지도 없이
flutter build apk --release --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID
```

## 9. 개발 환경과 알아낸 것

- **Flutter**: 3.47.8 (`C:\dev\flutter`). **Android SDK**: `%LOCALAPPDATA%\Android\Sdk`. **Python**: 3.12.
- **에뮬레이터**:
  - 멈추면 AVD 폴더의 `*.lock` 파일을 지우고 `emulator -avd Medium_Phone_API_37.0 -no-snapshot` 으로 켠다.
  - Git Bash 에서 adb 로 기기 경로를 쓸 때는 `MSYS_NO_PATHCONV=1` 을 붙인다.
  - `adb install` 에는 `C:/...` 형식 경로를 쓴다.
  - 한글은 `adb shell input text` 로 입력되지 않는다.
- **테스트 작성 요령**:
  - 목록을 굴린 직후에는 `pumpAndSettle` 한 뒤에 눌러야 한다. 안 그러면 하단 탭 막대를 누른다. `fakes.dart` 의 `tapAndSettle` 이 이미 그렇게 한다.
  - `FilledButton.icon` 같은 아이콘 버튼은 하위 클래스라 `find.byType(FilledButton)` 으로 못 찾는다. `find.bySubtype<ButtonStyleButton>()` 을 쓴다.
  - 화면이 길면 `tester.view.physicalSize` 로 테스트 화면을 키운다. ListView 는 화면 밖 항목을 만들지 않는다.
  - 병원 찾기 탭은 앱이 켜질 때 지역 목록을 한 번 읽는다. `FlakyRepository` 의 실패 횟수를 셀 때 이 한 번을 넣어 센다.
- **화면 구조에서 주의할 것**:
  - `LockGate` 는 `MaterialApp.builder` 안에서 전체 Navigator 를 감싼다. 그래서 잠금 화면용 Navigator 는 `HeroControllerScope.none` 으로 감싸야 한다.
  - `AppScope.of` 는 의존 관계를 만들지 않으므로 `initState` 에서도 쓸 수 있다.
  - iOS 키체인은 앱을 지워도 남는다. 그래서 `care_card_saved` 파일이 없으면 남은 카드를 지운다.
- **휴대폰 백업에서 빼는 것**: `last_search.json`, `favorites.json`, `recent_hospitals.json`, `hospital_data/`, `FlutterSecureStorage.xml`, `FlutterSecureKeyStorage.xml`.
  - 이 목록은 `test/backup_rules_test.dart` 가 검사한다.
  - `settings.json` 은 민감 정보가 없어서 백업한다.
- **셸 주의**: Bash 도구의 heredoc 안에 쓴 `"\n"` 이 실제 줄바꿈으로 바뀐 적이 있다. 파이썬 파일에 `\n` 을 넣을 때는 편집 도구로 고친다.

## 10. 지켜야 할 규칙 (사용자와 정한 것)

- `tools/.env` 는 읽거나 만들지 않는다. API 키가 들어 있다.
- API 키와 GitHub 시크릿은 사용자가 직접 넣는다. 예: `gh secret set DATA_GO_KR_SERVICE_KEY -R minyj07/hamkke-hospital`.
- 바깥으로 나가는 일(푸시, 배포, 저장소 설정, yearend2025.me 같은 다른 사이트)은 먼저 물어본다.
- 사용자에게는 한국어로 답한다.
- 미뤄 둔 일 (사용자가 요청할 때만 한다):
  - Windows 작업 스케줄러에 `fetch_facilities.py` 등록
  - 편의시설 실데이터 검증
  - 시크릿을 넣은 뒤 GitHub 서버에서 공공데이터 API 호출이 되는지 확인
