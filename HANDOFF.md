# 함께병원 인수인계 노트

2026-10-27 작성. 다른 계정(새 Claude 세션)에서 이어서 작업할 때 이 파일부터 읽으세요.

## 1. 지금 상태 한눈에

- **하던 일**: 기획서(`C:\Users\minyj\OneDrive\문서\카카오톡 받은 파일\기획서.md`, v1.0, 2026-10-24)대로 앱을 MVP 수준으로 고치는 중. 2026-10-27 두 번째 세션에서 3장의 1~4번(APK 크기, 에뮬레이터 점검, 추천 시나리오 테스트, 접근성 자동 점검)을 끝내고 그 과정에서 찾은 결함 6개를 고쳤다 ([3-1장](#3-1-2026-10-27-두-번째-세션에서-고친-것)).
- **코드**: 기획서 P0 과 P1 대부분을 구현했다. `flutter analyze` 문제 없음, Flutter 테스트 **165개**와 Python 테스트 **20개**가 통과한다. 2026-10-29 에는 배포 준비(앱 아이콘·스플래시·홈 화면 바로가기·릴리스 서명 설정)를 더했다 ([3-2장](#3-2-2026-10-29-배포-준비-앱처럼-보이게)).
- **아직 안 한 것**: 푸시, 데이터 배포, 네이버 지도 키·지도 화면 확인, 실기기(지문·TalkBack 실제 청취) 확인, 그리고 사용자가 정할 것 3가지([2-1장](#2-1-사용자와-상의할-것)). 자세한 순서는 [3장](#3-바로-이어서-할-일-순서대로)에 있다. README 는 새 기능과 ABI 별 빌드에 맞게 고쳐 두었다.
- **Git**:
  - 저장소는 `github.com/minyj07/hamkke-hospital` 의 `main` 이다. `1d58a50` 이 1단계(이름 검색·즐겨찾기 등), `03dfb48` 이 2단계(기획서 MVP)다.
  - 두 세션의 커밋(`03dfb48`, `06b4896`)은 **2026-10-27 저녁에 사용자 승인을 받아 `origin/main` 에 푸시했다**. 푸시는 늘 사용자에게 먼저 물어본다.
  - 푸시로 돈 GitHub CI(`ci.yml`, run 40505129426)는 앱(Flutter)·데이터 스크립트(Python) 두 작업 모두 **성공**했다 (1분 40초).
  - 2026-10-29 배포 준비 커밋 `ca11063`([3-2장](#3-2-2026-10-29-배포-준비-앱처럼-보이게))도 사용자 승인으로 `origin/main` 에 푸시했고 CI(run 40865125903)가 두 작업 모두 **성공**했다.
  - 커밋 메시지 끝에는 작업한 모델의 `Co-Authored-By: <모델 이름> <noreply@anthropic.com>` 을 붙인다 (1·2단계는 Claude Opus 5.5, 이번 세션은 Claude Fable 5.1).

## 2. 사용자가 정한 것

| 항목 | 결정 | 코드 위치 |
|---|---|---|
| 지도 SDK (기획서 미결 1) | **네이버 지도** (`flutter_naver_map` 1.4.4) | `lib/screens/results_map.dart`, `lib/main.dart` 의 `_initMap` |
| 네이버 지도 키 | 저장소에 넣지 않는다. 빌드할 때 `--dart-define=NAVER_MAP_CLIENT_ID=...` 로 넣고, 없으면 결과 화면의 목록/지도 버튼을 숨긴다. 키는 사용자가 직접 발급한다 (NCP 콘솔 → Maps → Application 등록 → Dynamic Map, 패키지 `kr.hamkkehospital.app`). | `lib/config.dart` |
| 신고·문의 메일 | **minyj07@gmail.com**. 앱과 공개 저장소에 드러나는 것을 사용자가 승인했다. `--dart-define=CONTACT_EMAIL=` 로 바꿀 수 있다. | `lib/config.dart` |
| 잠겨 있을 때 진료 카드 공개 (미결 4) | 기본은 **안 보이게**. 설정에서 '잠겨 있어도 병원에 보여 주기 열기'를 켤 수 있다. | `lib/data/app_settings.dart` |
| 상태 관리 | Riverpod 를 쓰지 않고 기존 방식(ChangeNotifier + `AppScope` InheritedWidget)을 유지한다. | `lib/screens/app_scope.dart` |
| 익명 사용 통계 (미결 5) | 넣지 않았다. 아직 정하지 않음. | — |
| 앱 언어 | 한국어만. Material 기본 라벨(뒤로 가기 '뒤로', 라이선스 화면 등)도 휴대폰 언어와 상관없이 한국어다. | `lib/main.dart` 의 `locale`, `localizationsDelegates` |
| 앱 기본 색 | **보라 #5B3FA0** (2026-10-29, 후보 6개 그림 중 D). 처음 초록(#1B6E5A)에서 바꿨다. 테마·아이콘·스플래시·바로가기 아이콘·홈 로고가 모두 이 색이다. | `lib/main.dart` 의 `_seed`, 바꾸는 법은 [3-2장](#3-2-2026-10-29-배포-준비-앱처럼-보이게) 아이콘 행 |

## 2-1. 사용자와 상의할 것

아직 정하지 않았고, 정하면 코드를 바꿔야 하는 것. 테스트는 지금 동작대로 적어 두었다.

1. **지도 SDK 유지 여부**: 네이버 지도 SDK 가 ABI 하나당 약 25MB 다. arm64 APK 는 47.5MB 로 50MB 안에 들지만, 빼면 약 22MB 가 된다. 키를 받아 지도 화면을 쓸지, 지도 앱으로 넘기는 '지도에서 보기'만 둘지 정한다.
2. **국립 정신건강 전문기관의 거리 감점**: `InstitutionCategory.mentalHealthCenter` 가 `recommender.dart` 의 `_regionalCategories` 에 없어 동네 병원처럼 1km 에 2점씩 깎인다. 전국에 몇 곳 없는 기관이라 40km 떨어지면 동네 정신건강의학과 의원보다 뒤로 간다 (시나리오 '지적장애(심함) 마음 건강'). 권역 기관(0.2/km, 최대 30)으로 바꿀지 정한다.
3. **건강검진에서 찾는 진료과**: `CareNeed.checkup` 은 가정의학과만 찾아서, 내과만 있는 병원은 장애친화 검진기관이 아니면 결과에서 빠진다 (시나리오 '심장장애 건강검진'). 실제로 내과 의원이 국가검진을 많이 하므로 내과를 더할지 정한다.
4. **글자 200%·좁은 화면(360dp)에서 실제 글꼴로 잘릴 수 있는 문구 3곳** (접근성 테스트의 계산, 문구를 바꿔야 해서 그대로 둠): 카드 편집의 칩 '조용한 곳에서 기다리기', 결과 거르기 칩 '편의시설 정보 있는 곳만'(경계선), 카드 편집의 입력 칸 라벨 '이름 또는 불러 주었으면 하는 이름'(줄임표). 짧은 문구로 바꿀지 정한다.

## 3. 바로 이어서 할 일 (순서대로)

1~4번(APK 크기, 에뮬레이터 점검, 추천 시나리오 테스트, 접근성 자동 점검)은 2026-10-27 두 번째 세션에서 끝냈다 ([7장](#7-빌드-확인-기록), [7-1장](#7-1-에뮬레이터-점검-기록-2026-10-27), [3-1장](#3-1-2026-10-27-두-번째-세션에서-고친-것)). 남은 것:

1. **사용자 결정** ([2-1장](#2-1-사용자와-상의할-것)) 을 받으면 그에 맞게 `recommender.dart`·`data/scoring.json`·시나리오 테스트의 기대값을 함께 고친다.
2. ~~**푸시**~~ 끝: 2026-10-27 `06b4896` 까지 `origin/main` 에 푸시했고 CI 가 통과했다 (1장). 이 HANDOFF 갱신 커밋은 그 뒤에 로컬에만 있을 수 있으니 `git log origin/main..main` 으로 확인한다.
3. **데이터 배포**:
   - Actions → 병원 데이터 갱신 → Run workflow 를 돌려 `data` 브랜치에 `scoring.json` 과 고친 `meta.json`(출처 문구) 을 올린다. `build=false` 여도 된다.
   - 지금 `data` 브랜치에는 `scoring.json` 이 없다. 그래도 앱은 앱에 든 점수표를 쓰므로 문제없다.
4. **네이버 지도 키**를 받으면 지도 화면을 실기기에서 처음 확인한다. `results_map.dart` 는 아직 한 번도 실행해 보지 않았다.
5. **실기기 확인**: `app-arm64-v8a-release.apk` 를 설치해서 지문 잠금, TalkBack 실제 청취(특히 병원 정보의 '추천 이유·지정 현황' 묶음이 한 덩어리로 읽히는 것이 괜찮은지), 메일 앱을 본다.
6. (기획서 12.3) 장애 당사자 사용성 테스트는 사용자 몫이다.

## 3-1. 2026-10-27 두 번째 세션에서 고친 것

점검·테스트를 하다가 찾은 결함. 문구와 동작은 바꾸지 않았다.

| 결함 | 고친 곳 | 검사하는 테스트 |
|---|---|---|
| 즐겨찾기·최근 본 병원을 앱을 켤 때 읽지 않아, 다음에 켰을 때 목록을 바꾸기 전까지 즐겨찾기 탭이 비어 보이고 병원 정보의 버튼도 '넣기'로 보였다 (`SavedHospitals._ready` 가 지연 초기화) | `app_shell.dart` 의 `initState` 에서 `favorites.load()`·`recent.load()` | `widget_test.dart` '앱을 다시 켜면 저장해 둔 즐겨찾기…' |
| 앱 바의 뒤로 가기 버튼이 화면낭독기에 영어 `Back` 으로 읽혔다 (Material 한국어 번역 없음) | `pubspec.yaml` 에 `flutter_localizations`, `main.dart` 에 `locale: ko` + `GlobalMaterialLocalizations.delegates` | `widget_test.dart` '앱 바의 뒤로 가기 버튼은 … 한국어로 읽힌다' |
| 테마의 `visualDensity: comfortable` 이 실제로는 -4dp 라 버튼·칩의 터치 영역이 44dp 였다 | `main.dart` → `VisualDensity.standard` | `accessibility_test.dart` 의 `androidTapTargetGuideline` |
| 결과 화면의 '순서·거르기·거리' 제목이 칩과 떨어져 한 노드(`순서\n거르기\n거리`)로 읽혔다 | `results_screen.dart` `_Controls.group()` 제목을 `Semantics(container, header)` 로 | `accessibility_test.dart` (제목이 별도 헤더 노드인지) |
| 설정 '내 정보 전부 지우기' 대화상자가 글자 2배·640dp 에서 본문이 잘렸다 | `settings_screen.dart` 대화상자 `scrollable: true` | `accessibility_test.dart` |
| 데이터 출처 문구에 '국민건강보험공단'이 두 번 들어갔다 | `tools/build_data.py` `primary_care_source()`, `assets/data/meta.json` | `tools/test_build_outputs.py` |

테스트를 쓸 때 알아 둘 것: 앱이 한국어라 `tester.pageBack()`(영어 `Back` 툴팁을 찾음)은 쓸 수 없고 `test/fakes.dart` 의 `goBack(tester)` 를 쓴다.

## 3-2. 2026-10-29 배포 준비 ("앱처럼" 보이게)

사용자 요청: "홈 화면 등 앱처럼 기본 기능을 더해 바로 배포해도 편하게 쓸 수 있게". Flutter 기본 아이콘·흰 스플래시·디버그 서명 상태였던 것을 채웠다.

| 한 것 | 어디 | 비고 |
|---|---|---|
| **앱 아이콘**: 보라(#5B3FA0, 사용자가 고른 색) 바탕에 흰 십자, 가운데 하트. 안드로이드 적응형(원·둥근 네모 마스크 대응)·단색(테마 아이콘)·iOS 아이콘 | 원본 `assets/icon/` (앱에 넣지 않음)은 `python tools/make_icon.py assets/icon 5B3FA0` 으로 그리고(Pillow 필요), 런처 아이콘은 `dart run flutter_launcher_icons` 로 만든다 (pubspec 의 `flutter_launcher_icons` 설정) | 적응형 앞면은 생성기가 16% 안쪽으로 넣으므로 스크립트가 1/0.68 배로 크게 그린다. **색을 바꿀 때 함께 바꿀 곳**: `lib/main.dart` `_seed`, pubspec `adaptive_icon_background`, `res/values(-night)/colors.xml` 의 `splash_background`, `res/drawable/ic_shortcut_*.xml` 의 `fillColor`, 아이콘 생성 명령의 색 인자. 앱 안 로고(`lib/screens/logo.dart` `LogoMark`, 홈 앱 바)는 테마 색을 따라 저절로 바뀐다. |
| **스플래시**: 연한 초록 배경(다크 모드는 짙은 초록) + 안드로이드 12 이상은 시스템 스플래시에 앱 아이콘 | `res/values(-night)/colors.xml` 의 `splash_background`, `res/values(-night)-v31/styles.xml`, `drawable(-v21)/launch_background.xml` | iOS 는 아직 기본 흰 LaunchScreen 이다. |
| **홈 화면 바로가기** (아이콘 길게 누르기): 병원 찾기 / 진료 카드 보여 주기(카드가 있으면 바로 보여 주기 화면, 없으면 카드 탭) / 즐겨찾기 | `quick_actions` 1.1.1, `lib/main.dart` `_setUpShortcuts`, `AppShortcut` enum 과 `AppServices.shortcut`(`app_scope.dart`), 받아서 여는 곳은 `app_shell.dart` `_openShortcut`, 아이콘 `res/drawable/ic_shortcut_*.xml` | 앱이 꺼진 채로 누르면 탭 화면이 생기기 전에 들어오므로 값으로 들고 있다가 첫 프레임 뒤에 연다. 테스트 3개(`widget_test.dart` '홈 화면 바로가기'). 잠겨 있으면 잠금 화면 아래에서 열려 있다가 풀면 보인다. 바로가기 아이콘 drawable 은 코드가 이름으로만 찾아서 릴리스 빌드의 리소스 축소가 지워 버린다(그러면 메뉴에 빈 흰 원만 보이고 `dumpsys shortcut` 에 `iconRes=0`). `res/raw/keep.xml` 의 `tools:keep` 으로 지킨다. 새 바로가기 아이콘을 더하면 거기에도 적는다. 에뮬레이터에서 시험할 때는 `adb shell "am start -n kr.hamkkehospital.app/.MainActivity -a android.intent.action.RUN --es 'some unique action key' card"` 처럼 따옴표를 기기 셸까지 전달해야 한다. |
| **릴리스 서명**: `android/key.properties` 가 있으면 그 키, 없으면 디버그 키 | `android/app/build.gradle.kts` | **키는 사용자가 만든다** (README '스토어에 올리기 전: 서명 키'). 키를 만들기 전까지 릴리스 APK/AAB 는 디버그 서명이라 스토어에 못 올린다. |

**아직 안 한 것 / 사용자 몫**: 서명 키 생성(README), 스토어 등록 정보(스크린샷, 설명, 개인정보 처리방침 **URL** — 앱 안의 처리방침 글을 GitHub Pages 나 저장소 파일로 올려야 한다), iOS 스플래시·빌드 확인(맥 필요), 홈 화면 **위젯**(진료 카드 한 장짜리)은 네이티브 코드가 필요해 넣지 않았다.

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
| 6.5 [P1] 앱 잠금 (생체·PIN) | 완료 (에뮬레이터에서 PIN 확인, **지문·실기기 미확인**) | 1분 넘게 다른 앱에 있다 오면 다시 잠근다. |
| 6.5 [P2] 카드 이미지 저장·공유 | 안 함 | 로드맵 |
| 6.6 즐겨찾기 + 최근 본 병원 20곳, 목록에서 바로 전화·길찾기 | 완료 | `saved_hospitals.dart` |
| 6.7 설정 (글자 1.0~2.0배, 고대비, 내 정보 전부 지우기, 기준일·출처·업데이트, 처리방침, 라이선스, 문의, 버전) | 완료 | `settings_screen.dart`, `privacy_screen.dart` |
| 6.8 [P1] 정보 오류 신고 (메일) | 완료 | 병원 ID·앱 버전·데이터 기준일만 붙이고 개인 정보는 넣지 않는다. |
| 7.2 [P0] 편의시설 정보 없으면 감점 안 함 | 완료 | `Recommendation.unknown` |
| 7.2 [P1] 점수표 설정 파일 분리 | 완료 | `data/scoring.json` → 데이터와 함께 배포하므로 앱 업데이트 없이 바뀐다. |
| 7.2 시나리오 테스트 30개 | 완료 | `test/recommender_scenarios_test.dart` 시나리오 40개 + 메타 2개 (장애 유형 16종·진료 목적 8종·나이·정도를 모두 덮는지, 추천 이유에 숫자가 없는지). 기대값은 손으로 계산했고 모두 코드와 일치했다. |
| 9장 접근성 | 자동 점검 완료, **실기기 TalkBack 검수 남음** | `test/accessibility_test.dart` 14개: 360×640 화면에서 글자 1배·2배로 주요 화면을 모두 열어 넘침·잘린 글·터치 영역 48dp·라벨·글자 대비를 검사한다. 아래 '접근성에서 한 것' 참고 |
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
- (2026-10-27 두 번째 세션) 터치 영역을 48dp 로 되돌렸고, 결과 화면 거르기 제목을 헤더로, Material 기본 라벨을 한국어로 했다. 접근성 테스트에서 뺀 것과 이유: 앱바 제목(Material 이 1.34배까지만 키우고 줄임표)·칩 라벨(한 줄 fade)·입력 칸 라벨(한 줄 줄임표)은 잘린 글 검사에서 뺐고, 글자 대비는 앱바 아래 끝·하단 탭 위 끝에 걸쳐 일부 가려진 글만 건너뛴다(테스트 글꼴이 속 빈 네모라 가린 색이 글자색으로 잡히는 오탐). 병원 정보의 `_Section`(추천 이유·지정 현황 등)은 헤더와 본문이 한 노드로 읽히는데 손대지 않았다 (3장 5번).

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
test/fakes.dart                   화면 테스트용 가짜 저장소·앱 만들기·도우미 (goBack 포함)
test/card_and_settings_test.dart  진료 카드·설정·잠금 화면 테스트
test/recommender_helpers.dart     (2차) 추천 테스트 공용 도우미 (seoul, hospital(), profile(), ids())
test/recommender_scenarios_test.dart (2차) 기획서 7.2 시나리오 40개 (표 형식 Scenario)
test/accessibility_test.dart      (2차) 기획서 9장 접근성 자동 점검 14개
```

2차 세션에서 바뀐 앱 코드: `lib/main.dart`(한국어 로컬라이제이션, `VisualDensity.standard`), `lib/screens/app_shell.dart`(즐겨찾기·최근 본 병원 읽기), `lib/screens/results_screen.dart`(거르기 제목 Semantics), `lib/screens/settings_screen.dart`(지우기 대화상자 scrollable), `pubspec.yaml`(`flutter_localizations`), `tools/build_data.py`(`primary_care_source`).

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
- 2026-10-27 `flutter build apk --release --split-per-abi` (지도 키 없음): **성공**. arm64 **47.9MB**, armeabi-v7a 39.9MB, x86_64 50.6MB (한국어 로컬라이제이션을 넣기 전에는 47.5 / 39.5 / 50.2MB).
  - 휴대폰 시험용은 `build\app\outputs\flutter-apk\app-arm64-v8a-release.apk` 를 쓴다. 기획서 12.2 의 50MB 안에 든다.
  - split APK 의 버전 코드에는 ABI 번호가 붙는다 (x86_64 는 앱 정보에 `1.0.0 (4001)`, arm64 는 3001). AAB 는 원래 번호다.
  - 지도 SDK 를 계속 쓸지(빼면 ABI 당 약 25MB 줄어든다)는 아직 사용자와 정하지 않았다.

## 7-1. 에뮬레이터 점검 기록 (2026-10-27)

AVD `Medium_Phone_API_37.0` (Android 17, x86_64, 1080×2400, 420dpi) 에 `app-x86_64-release.apk` 를 설치해서 봤다.

- **흐름**: 첫 실행 안내 3장 → 시작하기 → 홈 → 하단 탭 4개 → 병원 찾기 6단계 (뇌병변·심한·재활·성인·편의시설 4개 미리 선택됨·서울 강남구) → 결과 (1. 청담병원, 지정 재활의료기관, 약 1.4km) → 상세 → '?' 도움말 → 정보가 틀렸어요 → 메일로 보내기 → 진료 카드 만들기·저장 → 병원에 보여 주기 → 즐겨찾기(최근 본 병원) → 설정 → 개인정보 처리방침 → 오픈소스 라이선스. **모두 정상**.
- **메일 앱 열기**: `mailto:` 로 Gmail 이 열렸다 (에뮬레이터는 계정이 없어 환영 화면). 뒤로 오면 앱이 그대로 있다.
- **진료 카드 보안 저장**: 저장 → 탭에 문장형으로 보임. 로마자 이름은 `Kim(이)에요` 처럼 조사를 둘 다 붙인다.
- **화면 켜 두기**: 보여 주기 화면에서 `adb shell dumpsys window windows | grep -c KEEP_SCREEN_ON` 이 1, 닫으면 0.
- **앱 잠금**: `adb shell locksettings set-pin 1234` 뒤 설정에서 켜면 BiometricPrompt(기기 비밀번호)가 뜨고, PIN 을 넣으면 켜진다. 홈으로 나가 65초 뒤 다시 열면 인증 창이 저절로 뜨고, 취소하면 '함께병원이 잠겨 있어요' + '잠금 풀기' 화면이다. 풀면 나가기 전 화면(설정)으로 돌아온다. **지문은 시험하지 않았다** (에뮬레이터에 지문을 등록해야 한다).
- **화면낭독기 순서**: `adb shell uiautomator dump` 로 보면 결과 카드가 `1. 청담병원, 약 1.4km, 정부 지정 기관, 보건복지부 지정 재활의료기관, 진료과: 재활의학과` 한 덩어리로 읽힌다. 여기서 찾은 문제 둘은 이번에 고쳤다: 결과 화면의 '순서·거르기·거리' 제목 글이 칩과 떨어져 한 노드로 묶이던 것, 앱 바 뒤로 가기 버튼이 영어 `Back` 으로 읽히던 것 ([3-1장](#3-1-2026-10-27-두-번째-세션에서-고친-것)).
- **휴대폰 글꼴 200%** (`adb shell settings put system font_scale 2.0`): 안내·홈·찾기·결과·상세·진료 카드·설정 모두 잘림·겹침 없음. 상세의 버튼은 한 줄에 하나씩 놓인다. 끝나면 `font_scale 1.0` 으로 되돌린다.
- **알아낸 것**:
  - 인증 창은 보안 창이라 `screencap` 이 검게 나온다. `adb shell dumpsys window | grep mCurrentFocus` 가 `BiometricPrompt` 이면 떠 있는 것이다. PIN 은 `input text 1234` + `input keyevent 66`.
  - `pm clear` 직후 첫 캡처에는 아래쪽에 검은 띠(시스템 전환 효과)가 몇 초 남는다. 앱 결함이 아니다.
  - 긴 대기는 `adb shell sleep 65` 처럼 기기 쪽에서 한다.
  - 설정 화면은 탭 막대가 없는 별도 화면이라, 거기서 하단 탭 자리를 누르면 '잠겨 있어도 보여 주기' 스위치를 건드린다.
- **남은 것**: 네이버 지도 화면(키 없음), 지문, 실기기.

## 8. 명령 모음

```bash
export PATH="/c/dev/flutter/bin:$PATH"   # Git Bash 에서 Flutter 쓰기
flutter analyze
flutter test                                    # 아래 1장 참고
python -m unittest discover -s tools            # 20개
python tools/verify_data.py                     # 앱에 든 데이터 검사
flutter build apk --release --split-per-abi     # 휴대폰용: app-arm64-v8a-release.apk
flutter build apk --release --dart-define=NAVER_MAP_CLIENT_ID=발급받은ID
flutter build appbundle --release               # 스토어용 AAB

# 에뮬레이터 (Git Bash)
"$LOCALAPPDATA/Android/Sdk/emulator/emulator" -avd Medium_Phone_API_37.0 -no-snapshot &
adb install -r C:/.../build/app/outputs/flutter-apk/app-x86_64-release.apk
adb shell am start -n kr.hamkkehospital.app/.MainActivity
adb exec-out screencap -p > shot.png            # 화면 캡처
MSYS_NO_PATHCONV=1 adb shell uiautomator dump /sdcard/ui.xml   # 화면낭독기 라벨·순서 확인
adb shell locksettings set-pin 1234             # 앱 잠금 시험용 (지우기: locksettings clear --old 1234)
adb shell settings put system font_scale 2.0    # 글꼴 200% (끝나면 1.0)
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
