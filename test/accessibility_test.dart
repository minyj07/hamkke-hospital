import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/saved_hospitals.dart';
import 'package:hamkke_hospital/models/care_card.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/search_conditions.dart';
import 'package:hamkke_hospital/screens/help.dart';

import 'fakes.dart';

// 접근성 자동 점검 (기획서 9장). 작은 휴대폰(360×640)에서 글자를 2배로 키워 주요 화면을 모두 열고,
// 화면마다 1) 넘침(RenderFlex overflow)과 잘린 글이 없는지, 2) 누르는 곳이 48dp 이상인지,
// 3) 누르는 곳마다 화면낭독기 라벨이 있는지, 4) 글자와 배경의 대비가 4.5:1 이상인지 본다.
// 같은 검사를 글자 1배에서도 한 번 돈다. 화면낭독기가 읽는 순서는 자동으로 보지 못하므로 기기에서 확인한다.

const _phone = Size(360, 640);

/// 작은 휴대폰 화면으로 둔다. 화면낭독기(semantics)는 testWidgets 가 기본으로 켠다.
void preparePhone(WidgetTester tester) {
  tester.view.physicalSize = _phone;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// 첫 실행 안내는 본 것으로 하고, 앱 안 글자 크기를 [scale] 배로 둔 설정.
FakeSettingsStore settingsAt(double scale, [Map<String, dynamic> more = const {}]) =>
    FakeSettingsStore({'onboardingDone': true, 'textScale': scale, ...more});

/// 보이는 글 가운데 칸보다 길어 잘렸거나 줄임표로 끝난 것.
///
/// 앱바 제목, 칩 라벨, 입력 칸의 라벨·힌트는 Material 이 한 줄로 두고 자르는 곳이라 보지 않는다
/// (테스트 글꼴은 띄어쓰기도 글자 한 칸 너비로 재서 실제보다 넓게 나온다). 그 밖의 글은 줄을 바꿔 다 보여야 한다.
List<String> clippedTexts(WidgetTester tester) {
  final skipped = <Element>{
    for (final type in [AppBar, RawChip, TextField])
      ...find.descendant(of: find.byType(type), matching: find.byType(RichText)).evaluate(),
  };
  final screen = Offset.zero & (tester.view.physicalSize / tester.view.devicePixelRatio);
  final clipped = <String>[];
  for (final element in find.byType(RichText).evaluate()) {
    if (skipped.contains(element)) continue;
    final paragraph = element.renderObject;
    if (paragraph is! RenderParagraph || !paragraph.hasSize) continue;
    final text = paragraph.text.toPlainText().trim();
    if (text.isEmpty) continue;
    // 화면 밖의 글은 굴려서 보일 때 다시 본다.
    final bounds = MatrixUtils.transformRect(paragraph.getTransformTo(null), paragraph.paintBounds);
    if (!bounds.overlaps(screen)) continue;
    final Size(width: width, height: height) = paragraph.textSize;
    final box = paragraph.size;
    if (paragraph.didExceedMaxLines || width > box.width + 1 || height > box.height + 1) {
      clipped.add('"$text" (글 ${width.round()}×${height.round()}, '
          '칸 ${box.width.round()}×${box.height.round()})');
    }
  }
  return clipped;
}

/// 글자 대비 지침([textContrastGuideline])인데, 앱바 아래 끝이나 하단 탭 위 끝에 걸쳐 일부가 가려진 글은 건너뛴다.
///
/// 지침은 글 상자를 4px 넓힌 자리의 색을 세는데, 테스트 글꼴은 글자를 속 빈 네모로 그려 글자색 픽셀이 적다.
/// 그래서 굴리다 앱바 밑으로 일부 들어간 글은 앱바(scrolled-under 색)가 글자색으로 잡혀 1.3:1 로 나온다.
/// 그런 글은 굴려서 다 보일 때 다시 본다.
class BodyTextContrastGuideline extends MinimumTextContrastGuideline {
  BodyTextContrastGuideline(this.edges);

  /// 글이 걸치면 안 되는 가로선의 y 좌표.
  final List<double> edges;

  @override
  bool isNodeOffScreen(Rect paintBounds, ui.FlutterView window) =>
      super.isNodeOffScreen(paintBounds, window) ||
      edges.any((y) => paintBounds.top < y && paintBounds.bottom > y);
}

/// 지금 화면에서 글이 가려지는 가로선: 앱바 아래 끝과 하단 탭 위 끝.
List<double> clipEdges(WidgetTester tester) => [
      if (find.byType(AppBar).evaluate().isNotEmpty) tester.getRect(find.byType(AppBar).first).bottom,
      if (find.byType(NavigationBar).evaluate().isNotEmpty)
        tester.getRect(find.byType(NavigationBar).first).top,
    ];

/// 지금 보이는 [screen] 이 접근성 지침에 맞는지 본다. 긴 화면은 [checkWholeScreen] 으로 끝까지 본다.
Future<void> checkScreen(WidgetTester tester, String screen) async {
  expect(tester.takeException(), isNull, reason: '$screen: 레이아웃 오류(넘침 등)가 났어요.');
  expect(clippedTexts(tester), isEmpty, reason: '$screen: 잘린 글이 있어요.');
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline),
      reason: '$screen: 48dp 보다 작은 누르는 곳이 있어요.');
  await expectLater(tester, meetsGuideline(labeledTapTargetGuideline),
      reason: '$screen: 화면낭독기 라벨이 없는 누르는 곳이 있어요.');
  await expectLater(tester, meetsGuideline(BodyTextContrastGuideline(clipEdges(tester))),
      reason: '$screen: 글자와 배경의 대비가 낮아요.');
}

/// 긴 화면은 처음부터 끝까지 넘기면서 [checkScreen] 을 되풀이하고, 다음에 누를 것이 위쪽에 있을 수 있으니
/// 처음으로 되돌린다. [scrollable] 이 없으면 화면의 첫 스크롤 영역을 쓴다.
Future<void> checkWholeScreen(WidgetTester tester, String screen, {Finder? scrollable}) async {
  final position = tester.state<ScrollableState>(scrollable ?? find.byType(Scrollable).first).position;
  Future<void> jumpTo(double pixels) async {
    if (position.pixels == pixels) return;
    position.jumpTo(pixels);
    await tester.pumpAndSettle();
  }

  await jumpTo(0);
  await checkScreen(tester, screen);
  var part = 1;
  while (position.pixels < position.maxScrollExtent - 1 && part < 40) {
    await jumpTo(math.min(position.pixels + 400, position.maxScrollExtent));
    await checkScreen(tester, '$screen (${++part}번째 부분)');
  }
  await jumpTo(0);
}

/// [text] 가 있는 곳까지 굴려서 보이게 한다.
Future<void> scrollTo(WidgetTester tester, String text, {double delta = 200}) async {
  await tester.scrollUntilVisible(find.text(text), delta, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
}

/// [label] 입력 칸까지 굴려서 [text] 를 넣는다.
Future<void> enterField(WidgetTester tester, String label, String text) async {
  final field = find.widgetWithText(TextField, label);
  await tester.scrollUntilVisible(field, 200, scrollable: find.byType(Scrollable).first);
  await tester.pumpAndSettle();
  await tester.enterText(field, text);
  await tester.pump();
}

/// 지정 재활의료기관. 강남구 중심에서 약 15km 라 '5 km 안'으로 거르면 빠진다.
/// 편의시설은 있음·없음·정보 없음이 섞여 있어 카드의 경고와 병원 정보의 세 가지 표시가 모두 나온다.
const designatedRehab = Hospital(
  id: 'r1',
  name: '서울재활병원',
  region: '110000',
  kind: '병원',
  district: '노원구',
  address: '서울특별시 노원구 1',
  phone: '02-111-1111',
  lat: 37.65,
  lng: 127.06,
  doctors: 12,
  specialists: 5,
  openedYear: 2010,
  homepage: 'http://rehab.example',
  departments: {'재활의학과', '내과'},
  categories: {InstitutionCategory.rehabDesignated},
  facilities: {Facility.wheelchair, Facility.toilet},
  absentFacilities: {Facility.parking},
  notes: ['재활의료기관 (3기)'],
);

/// 서울에는 이비인후과가 없어서 결과가 0건인 조건.
const hearingGangnam = SearchConditions(
  types: {DisabilityType.hearing},
  severity: Severity.mild,
  need: CareNeed.general,
  age: AgeGroup.adult,
  regionCode: '110000',
  regionName: '서울특별시',
  districtName: '강남구',
);

const card = CareCard(
  name: '김함께',
  types: {DisabilityType.hearing},
  severity: Severity.severe,
  communication: {Communication.writing},
  help: {HelpNeed.callMe},
  cautions: '큰 소리에 놀라요.',
  guardianName: '엄마',
  guardianPhone: '010-1234-5678',
);

void main() {
  for (final scale in [2.0, 1.0]) {
    group('글자 ${scale == 1.0 ? '1배' : '2배'}, 360×640 화면', () {
      testWidgets('첫 실행 안내 3장', (tester) async {
        preparePhone(tester);
        await pumpApp(tester, await makeServices(settingsStore: FakeSettingsStore({'textScale': scale})));
        expect(find.text('1 / 3'), findsOneWidget);
        await checkScreen(tester, '첫 실행 안내 1');
        for (final page in [2, 3]) {
          await tester.tap(find.text('다음'));
          await tester.pumpAndSettle();
          expect(find.text('$page / 3'), findsOneWidget);
          await checkScreen(tester, '첫 실행 안내 $page');
        }
        await tester.tap(find.text('시작하기'));
        await tester.pumpAndSettle();
        expect(find.text('나에게 맞는\n병원을 찾아보세요'), findsOneWidget);
      });

      testWidgets('홈과 홈 검색, 마이페이지, 설정과 내 정보 지우기 확인, 개인정보 처리방침', (tester) async {
        preparePhone(tester);
        await pumpApp(tester, await makeServices(settingsStore: settingsAt(scale)));
        await checkWholeScreen(tester, '홈');

        // 홈 검색창으로 찾은 결과와, 거기서 연 병원 정보.
        await tester.enterText(find.byType(TextField), '강남');
        await tester.pumpAndSettle();
        expect(find.text('검색 결과 3곳'), findsOneWidget);
        await checkWholeScreen(tester, '홈 검색 결과');
        await tapAndSettle(tester, '강남재활의학과의원');
        // 이름으로 찾아 열면 거리·추천 이유가 없고 편의시설 정보도 없다.
        await checkWholeScreen(tester, '병원 정보 (이름으로 찾은 병원)');
        await goBack(tester);
        await tester.tap(find.byTooltip('검색어 지우기'));
        await tester.pumpAndSettle();

        // 내 주변 병원: 현재 위치로 보기를 눌러 가로 카드가 나온 뒤, 진료과로 거른 뒤.
        await tapAndSettle(tester, '현재 위치로 보기');
        await checkWholeScreen(tester, '홈 (내 주변 병원)');
        await tapAndSettle(tester, '내과');
        await checkWholeScreen(tester, '홈 (내과로 거름, 근처에 없음)');

        await tapTab(tester, '마이페이지');
        await checkWholeScreen(tester, '마이페이지 (카드 없음)');
        await tapAndSettle(tester, '설정');
        await checkWholeScreen(tester, '설정');
        await tapAndSettle(tester, '내 정보 전부 지우기');
        await checkScreen(tester, '내 정보 지우기 확인');
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();

        await tapAndSettle(tester, '개인정보 처리방침');
        await checkWholeScreen(tester, '개인정보 처리방침');
      });

      testWidgets('병원 찾기 6단계 → 추천 결과와 거르기 → 병원 정보, 지정 기관 설명, 정보 오류 신고',
          (tester) async {
        preparePhone(tester);
        await pumpApp(
          tester,
          await makeServices(
            settingsStore: settingsAt(scale),
            repository: FakeRepository(hospitals: const [designatedRehab, ...defaultHospitals]),
          ),
        );
        await openFind(tester);
        await checkWholeScreen(tester, '병원 찾기 1단계 장애 유형');
        await tapAndSettle(tester, '지체장애');
        await tapAndSettle(tester, '기타');
        await tester.scrollUntilVisible(find.byType(TextField), 100,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        await checkScreen(tester, '병원 찾기 1단계 기타 입력 칸');
        await tester.enterText(find.byType(TextField), '척수장애');
        await tester.pump();
        await tapNext(tester);

        await checkWholeScreen(tester, '병원 찾기 2단계 장애 정도');
        await tapAndSettle(tester, '장애의 정도가 심한 장애인');
        await tapNext(tester);

        await checkWholeScreen(tester, '병원 찾기 3단계 진료');
        await tapAndSettle(tester, '재활 치료');
        await tapNext(tester);

        await checkWholeScreen(tester, '병원 찾기 4단계 나이');
        await tapAndSettle(tester, '성인');
        await tapNext(tester);

        await checkWholeScreen(tester, '병원 찾기 5단계 편의시설');
        await tapAndSettle(tester, '수어 통역');
        await scrollTo(tester, '처음 골라 둔 대로 되돌리기');
        await checkScreen(tester, '병원 찾기 5단계 편의시설 (직접 고른 뒤)');
        await tester.tap(find.text('처음 골라 둔 대로 되돌리기'));
        await tester.pumpAndSettle();
        await tapNext(tester);

        await checkWholeScreen(tester, '병원 찾기 6단계 시·도');
        await tapAndSettle(tester, '서울특별시');
        await tapNext(tester);
        await checkWholeScreen(tester, '병원 찾기 6단계 시·군·구');
        await tapAndSettle(tester, '강남구');
        await tester.tap(find.text('추천 병원 보기'));
        await tester.pumpAndSettle();

        // 순서·거르기·거리 제목은 칩과 따로, 제목으로 읽혀야 한다 (셋이 한 덩어리로 합쳐지면 안 된다).
        for (final title in ['순서', '거르기', '거리']) {
          await scrollTo(tester, title);
          final node = tester.getSemantics(find.text(title));
          expect((node.label, node.flagsCollection.isHeader), (title, true),
              reason: '결과 화면의 ‘$title’ 제목은 자기 칩들 바로 앞에 따로 읽혀야 해요.');
        }
        await scrollTo(tester, '1. 서울재활병원');
        expect(find.text('확인 필요 · 없다고 확인됨: 장애인 주차'), findsOneWidget);
        await checkWholeScreen(tester, '추천 결과');

        await tapAndSettle(tester, '가까운 순');
        await checkScreen(tester, '추천 결과 (가까운 순)');
        await tapAndSettle(tester, '지정 기관만');
        await tapAndSettle(tester, '5 km 안');
        await scrollTo(tester, '조건을 넓혀 볼까요?');
        await checkWholeScreen(tester, '추천 결과 (거르기로 0건)');
        await tapAndSettle(tester, '거르기 모두 끄기');

        await tapAndSettle(tester, '2. 서울재활병원');
        expect(find.text('서울특별시 노원구 1'), findsOneWidget);
        await checkWholeScreen(tester, '병원 정보 (지정 기관, 편의시설 있음·없음·정보 없음)');
        await tapAndSettle(tester, categoryQuestion(InstitutionCategory.rehabDesignated));
        await checkScreen(tester, '지정 기관 설명');
        await tester.tap(find.text('닫기'));
        await tester.pumpAndSettle();

        await tapAndSettle(tester, '정보가 틀렸어요');
        await checkWholeScreen(tester, '정보 오류 신고');
        await tapAndSettle(tester, '전화번호');
        await enterField(tester, '자세한 내용 (안 써도 돼요)', '번호가 바뀌었어요');
        await checkWholeScreen(tester, '정보 오류 신고 (보낼 수 있음)');
      });

      testWidgets('맞는 병원이 없을 때: 조건 넓히기 → 이웃 시·도까지 찾은 결과', (tester) async {
        preparePhone(tester);
        await pumpApp(
          tester,
          await makeServices(settingsStore: settingsAt(scale), searchStore: FakeSearchStore(hearingGangnam)),
        );
        await checkWholeScreen(tester, '홈 (지난번 조건 있음)');
        await tapAndSettle(tester, '지난번 조건으로 다시 찾기');
        await checkWholeScreen(tester, '추천 결과 0건');
        await tapAndSettle(tester, '이웃 시·도까지 찾기');
        await scrollTo(tester, '1. 성남이비인후과의원');
        await checkWholeScreen(tester, '추천 결과 (이웃 시·도까지)');
      });

      testWidgets('진료 카드: 만들기 → 보여 주기 → 자주 쓰는 문장과 크게 보기 → 고치기와 지우기 확인', (tester) async {
        preparePhone(tester);
        await pumpApp(tester, await makeServices(settingsStore: settingsAt(scale)));
        await openCard(tester);
        await checkWholeScreen(tester, '나의 진료 카드 (카드 없음)');

        await tapAndSettle(tester, '진료 카드 만들기');
        await checkWholeScreen(tester, '진료 카드 만들기');
        await enterField(tester, '이름 또는 불러 주었으면 하는 이름', '이지현');
        await tapAndSettle(tester, '청각장애');
        await tapAndSettle(tester, '장애의 정도가 심한 장애인');
        await tapAndSettle(tester, '필담(글로 쓰기)');
        await tapAndSettle(tester, '차례 알려 주기');
        await enterField(tester, '주의할 점', '큰 소리에 놀라요.');
        await enterField(tester, '보호자 이름이나 관계', '엄마');
        await enterField(tester, '보호자 전화번호', '010-1234-5678');
        await tapAndSettle(tester, '저장하기');
        expect(find.text('진료 카드를 저장했어요.'), findsOneWidget);
        await checkWholeScreen(tester, '나의 진료 카드 (카드 있음, 저장 알림)');
        // 알림이 사라진 뒤에 눌러야 알림을 누르지 않는다.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();

        await tapAndSettle(tester, '병원에 보여 주기');
        await checkWholeScreen(tester, '병원에 보여 주기');
        await goBack(tester);
        await tester.pumpAndSettle();

        await tapAndSettle(tester, '자주 쓰는 문장');
        await checkWholeScreen(tester, '자주 쓰는 문장');
        await tapAndSettle(tester, '화장실에 가고 싶어요.');
        await checkWholeScreen(tester, '크게 보기');
        await goBack(tester);
        await tester.pumpAndSettle();
        await goBack(tester);
        await tester.pumpAndSettle();

        await tapAndSettle(tester, '카드 고치기');
        await checkWholeScreen(tester, '진료 카드 고치기');
        await tapAndSettle(tester, '진료 카드 지우기');
        await checkScreen(tester, '진료 카드 지우기 확인');
        await tester.tap(find.text('취소'));
        await tester.pumpAndSettle();
        await goBack(tester);
        await goBack(tester);

        // 카드를 만든 뒤의 마이페이지.
        await tapTab(tester, '마이페이지');
        expect(find.text('이지현 님'), findsOneWidget);
        await checkWholeScreen(tester, '마이페이지 (카드 있음)');
      });

      testWidgets('즐겨찾기 탭: 빈 상태와 즐겨찾기·최근 본 병원이 있을 때', (tester) async {
        preparePhone(tester);
        await pumpApp(tester, await makeServices(settingsStore: settingsAt(scale)));
        await tapTab(tester, '즐겨찾기');
        await checkWholeScreen(tester, '즐겨찾기 (빈 상태)');

        await tester.pumpWidget(const SizedBox());
        final services = await makeServices(
          settingsStore: settingsAt(scale),
          favoritesStore: FakeSavedHospitalsStore()..saved = [SavedHospital.of(defaultHospitals.first)],
          recentStore: FakeSavedHospitalsStore()
            ..saved = [SavedHospital.of(defaultHospitals.last), SavedHospital.of(gyeonggiEnt)],
        );
        // 저장해 둔 목록은 읽어야 보인다.
        await (services.favorites.load(), services.recent.load()).wait;
        await pumpApp(tester, services);
        await tapTab(tester, '즐겨찾기');
        expect(find.text('강남재활의학과의원'), findsOneWidget);
        await checkWholeScreen(tester, '즐겨찾기 (병원 있음)');
      });

      testWidgets('잠금 화면과, 잠긴 채 병원에 보여 주기', (tester) async {
        preparePhone(tester);
        await pumpApp(
          tester,
          await makeServices(
            settingsStore: settingsAt(scale, {'appLock': true, 'showCardWhenLocked': true}),
            appLock: FakeAppLock(succeeds: false),
            careCardStore: FakeCareCardStore(card),
          ),
        );
        expect(find.text('메디움이 잠겨 있어요'), findsOneWidget);
        await checkWholeScreen(tester, '잠금 화면');
        await tapAndSettle(tester, '병원에 보여 주기');
        expect(find.text('안녕하세요. 저는 김함께예요.'), findsOneWidget);
        await checkWholeScreen(tester, '잠긴 채 병원에 보여 주기');
      });
    });
  }
}
