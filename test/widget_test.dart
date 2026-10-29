import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/data_store.dart';
import 'package:hamkke_hospital/data/saved_hospitals.dart';
import 'package:hamkke_hospital/models/care_card.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/search_conditions.dart';
import 'package:hamkke_hospital/screens/app_scope.dart';
import 'package:hamkke_hospital/services/location.dart';

import 'fakes.dart';

void main() {
  Future<void> scrollTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
      finder, 200, scrollable: find.byType(Scrollable).first);

  Future<void> searchGangnam(WidgetTester tester) async {
    await chooseUntilRegion(tester);
    await tapAndSettle(tester, '서울특별시');
    await tapNext(tester);
    await tapAndSettle(tester, '강남구');
    await tester.tap(find.text('추천 병원 보기'));
    await tester.pumpAndSettle();
  }

  Future<void> searchAgain(WidgetTester tester) => tapAndSettle(tester, '지난번 조건으로 다시 찾기');

  testWidgets('처음 켜면 안내 3장을 보여 주고, 건너뛰면 홈이 나온다', (tester) async {
    final store = FakeSettingsStore({});
    await pumpApp(tester, await makeServices(settingsStore: store));

    expect(find.text('나에게 맞는 병원을 찾아요'), findsOneWidget);
    expect(find.text('1 / 3'), findsOneWidget);
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
    expect(find.text('2 / 3'), findsOneWidget);

    await tester.tap(find.text('건너뛰기'));
    await tester.pumpAndSettle();
    expect(find.text('무엇을 도와드릴까요?'), findsOneWidget);
    expect(store.saved['onboardingDone'], isTrue);
  });

  testWidgets('홈의 큰 버튼으로 병원 찾기·진료 카드·즐겨찾기 탭을 연다', (tester) async {
    await pumpApp(tester, await makeServices());

    await tester.tap(find.widgetWithText(FilledButton, '병원 찾기'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);

    await tapTab(tester, '홈');
    await tester.tap(find.widgetWithText(FilledButton, '나의 진료 카드'));
    await tester.pumpAndSettle();
    expect(find.text('진료 카드 만들기'), findsOneWidget);

    await tapTab(tester, '홈');
    await tester.tap(find.widgetWithText(FilledButton, '즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('즐겨찾기한 병원이 없어요'), findsOneWidget);
  });

  testWidgets('병원 찾기는 몇 번째 단계인지 보여 주고, 이전 단계로 돌아갈 수 있다', (tester) async {
    await pumpApp(tester, await makeServices());
    await tapTab(tester, '병원 찾기');

    expect(find.text('1 / 6 단계'), findsOneWidget);
    expect(nextEnabled(tester), isFalse);
    expect(find.text('이전'), findsNothing);

    await tapAndSettle(tester, '지체장애');
    await tapNext(tester);
    expect(find.text('2 / 6 단계'), findsOneWidget);
    expect(find.text('장애의 정도를 알려주세요'), findsOneWidget);

    await tester.tap(find.text('이전'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);

    // 휴대폰의 뒤로 가기도 앱을 닫지 않고 이전 단계로 간다.
    await tapNext(tester);
    final dynamic app = tester.state(find.byType(WidgetsApp));
    await app.didPopRoute();
    await tester.pumpAndSettle();
    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);
  });

  testWidgets('조건을 끝까지 고르면 추천 병원과 상세 정보가 나온다', (tester) async {
    final services = await makeServices();
    await pumpApp(tester, services);

    await chooseUntilRegion(tester);
    expect(find.text('6 / 6 단계'), findsOneWidget);
    await tapAndSettle(tester, '서울특별시');
    await tapNext(tester);
    expect(find.text('서울특별시 전체'), findsOneWidget);
    await tapAndSettle(tester, '강남구');
    await tester.tap(find.text('추천 병원 보기'));
    await tester.pumpAndSettle();

    expect(find.text('추천 병원'), findsOneWidget);
    expect(find.text('1. 강남재활의학과의원'), findsOneWidget);
    expect(find.textContaining('강남안과의원'), findsNothing);
    // 거리순이 아니라 추천 점수순이다.
    expect(find.textContaining('조건에 잘 맞는 순서로 1곳을 골랐어요'), findsOneWidget);
    expect(find.textContaining('서울특별시 강남구 중심에서'), findsOneWidget);
    // 편의시설 정보가 없으면 없다고 하지 않고, 정보가 없다고 요약에서 한 번 알린다.
    expect(find.textContaining('휠체어 접근, 장애인 주차, 장애인 화장실, 이동식 리프트·전동 검사대 정보가 없는'),
        findsOneWidget);
    expect(find.textContaining('확인 필요'), findsNothing);
    await scrollTo(tester, find.textContaining('2026-10-07 기준 공공데이터 · 자료: 테스트 자료'));
    expect(services.lastSearch.value?.summary, '지체장애 · 재활 치료 · 서울특별시 강남구');

    await tester.scrollUntilVisible(find.text('1. 강남재활의학과의원'), -200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('1. 강남재활의학과의원'));
    await tester.pumpAndSettle();
    expect(find.text('서울특별시 강남구 테헤란로 1'), findsOneWidget);
    expect(find.text('전화하기'), findsOneWidget);
    expect(find.text('길찾기'), findsOneWidget);
    await scrollTo(tester, find.textContaining('필요하신 휠체어 접근'));
    await scrollTo(tester, find.text('진료 시간과 쉬는 날은 병원에 전화로 확인하세요.'));
    await scrollTo(tester, find.textContaining('방문 전 전화로 확인하세요'));
    // 본 병원은 최근 본 병원에 남는다.
    expect(services.recent.items.single.name, '강남재활의학과의원');
  });

  testWidgets('기타를 고르면 직접 입력해야 다음으로 넘어가고, 입력한 내용으로 찾는다', (tester) async {
    await pumpApp(tester, await makeServices());
    await tapTab(tester, '병원 찾기');

    await tapAndSettle(tester, '기타');
    expect(nextEnabled(tester), isFalse);
    await tester.enterText(find.byType(TextField), '척수손상');
    await tester.pump();
    expect(nextEnabled(tester), isTrue);
    await tapNext(tester);

    await tapAndSettle(tester, '장애의 정도가 심하지 않은 장애인');
    await tapNext(tester);

    await tapAndSettle(tester, '기타');
    expect(nextEnabled(tester), isFalse);
    await tester.enterText(find.byType(TextField), '피부 질환');
    await tester.pump();
    await tapNext(tester);
    await tapAndSettle(tester, '성인');
    await tapNext(tester);
    await tapNext(tester);

    await tapAndSettle(tester, '현재 위치로 찾기');

    expect(find.text('추천 병원'), findsOneWidget);
    expect(find.textContaining('기타(척수손상) · 기타(피부 질환) · 현재 위치'), findsOneWidget);
    expect(find.text('1. 강남피부과의원'), findsOneWidget);
    expect(find.textContaining('강남재활의학과의원'), findsNothing);
  });

  testWidgets('현재 위치로 찾으면 시·도를 고르지 않아도 가까운 병원이 나온다', (tester) async {
    await pumpApp(tester, await makeServices());
    await chooseUntilRegion(tester, type: '시각장애', need: '일반 진료');
    await tapAndSettle(tester, '현재 위치로 찾기');

    expect(find.text('1. 강남안과의원'), findsOneWidget);
    expect(find.textContaining('거리는 현재 위치에서 잰 직선거리예요'), findsOneWidget);
  });

  testWidgets('위치를 못 얻으면 이유를 알려주고 지역 선택 화면에 남는다', (tester) async {
    await pumpApp(
      tester,
      await makeServices(here: const LocationResult.error('위치 권한을 허용해야 현재 위치로 찾을 수 있어요.')),
    );
    await chooseUntilRegion(tester, type: '시각장애', need: '일반 진료');
    await tapAndSettle(tester, '현재 위치로 찾기');

    expect(find.text('위치 권한을 허용해야 현재 위치로 찾을 수 있어요.'), findsOneWidget);
    expect(find.text('어디에서 찾을까요?'), findsOneWidget);
  });

  testWidgets('찾은 조건을 저장해 두고, 앱을 다시 켜면 홈에서 바로 다시 찾는다', (tester) async {
    final store = FakeSearchStore();
    await pumpApp(tester, await makeServices(searchStore: store));
    expect(find.text('지난번 조건'), findsNothing);

    await searchGangnam(tester);
    expect(store.saved?.summary, '지체장애 · 재활 치료 · 서울특별시 강남구');
    expect(store.saved?.age, AgeGroup.adult);

    // 앱을 껐다 켠다.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, await makeServices(searchStore: store));
    expect(find.text('지난번 조건'), findsOneWidget);
    expect(find.text('지체장애 · 재활 치료 · 서울특별시 강남구'), findsOneWidget);
    expect(find.text('이 휴대폰에 저장하고, 앱 밖으로 보내지 않아요.'), findsOneWidget);

    await searchAgain(tester);
    expect(find.text('추천 병원'), findsOneWidget);
    expect(find.text('1. 강남재활의학과의원'), findsOneWidget);
    expect(find.textContaining('서울특별시 강남구 중심에서'), findsOneWidget);
  });

  testWidgets('병원 찾기는 지난번 조건으로 미리 골라 두고, 진료 카드가 있으면 장애는 카드로 채운다',
      (tester) async {
    await pumpApp(
      tester,
      await makeServices(
        searchStore: FakeSearchStore(gangnamRehab),
        careCardStore: FakeCareCardStore(const CareCard(
          types: {DisabilityType.hearing},
          severity: Severity.mild,
        )),
      ),
    );
    await tapTab(tester, '병원 찾기');

    bool checked(String label) =>
        tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, label)).value!;
    expect(checked('청각장애'), isTrue);
    expect(checked('지체장애'), isFalse);
    expect(find.textContaining('나의 진료 카드에 적은 장애로 미리 골라 두었어요'), findsOneWidget);

    await tapNext(tester);
    expect(
      tester
          .widget<RadioGroup<Severity>>(find.byType(RadioGroup<Severity>))
          .groupValue,
      Severity.mild,
    );
    await tapNext(tester);
    // 진료와 나이는 지난번 조건으로 채운다.
    expect(tester.widget<RadioGroup<CareNeed>>(find.byType(RadioGroup<CareNeed>)).groupValue,
        CareNeed.rehab);
    expect(nextEnabled(tester), isTrue);
  });

  testWidgets('현재 위치로 찾은 조건은 위치를 저장하지 않고, 다시 찾을 때 새로 얻는다', (tester) async {
    final location = FakeLocationService(const LocationResult(37.5172, 127.0473));
    final store = FakeSearchStore(const SearchConditions(
      types: {DisabilityType.visual},
      severity: Severity.severe,
      need: CareNeed.general,
    ));
    await pumpApp(tester, await makeServices(locationService: location, searchStore: store));
    expect(find.text('시각장애 · 일반 진료 · 현재 위치'), findsOneWidget);

    await searchAgain(tester);

    expect(location.calls, 1);
    expect(find.text('1. 강남안과의원'), findsOneWidget);
    expect(find.textContaining('거리는 현재 위치에서 잰 직선거리예요'), findsOneWidget);
    expect(store.saved!.toJson().containsKey('region'), isFalse);
  });

  testWidgets('지난번 조건을 지우고, 잘못 눌렀으면 되돌린다', (tester) async {
    final store = FakeSearchStore(gangnamRehab);
    await pumpApp(tester, await makeServices(searchStore: store));

    await tapAndSettle(tester, '조건 지우기');
    expect(find.text('지난번 조건'), findsNothing);
    expect(store.saved, isNull);
    expect(find.text('지난번 조건을 지웠어요.'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('지난번 조건'), findsOneWidget);
    expect(store.saved?.summary, gangnamRehab.summary);
  });

  testWidgets('저장한 지역이 새 데이터에서 없어졌으면 지역을 다시 고르게 한다', (tester) async {
    await pumpApp(
      tester,
      await makeServices(
        searchStore: FakeSearchStore(const SearchConditions(
          types: {DisabilityType.physical},
          severity: Severity.severe,
          need: CareNeed.rehab,
          regionCode: '999999',
          regionName: '없어진도',
        )),
      ),
    );

    await searchAgain(tester);

    expect(find.text('지역 정보가 바뀌었어요. 지역을 다시 골라 주세요.'), findsOneWidget);
    expect(find.text('추천 병원'), findsNothing);
    expect(find.text('지난번 조건'), findsOneWidget);
  });

  testWidgets('병원 정보를 못 불러오면 다시 시도할 수 있다', (tester) async {
    await pumpApp(
      tester,
      await makeServices(
        repository: FlakyRepository(hospitalFailures: 1),
        searchStore: FakeSearchStore(gangnamRehab),
      ),
    );
    await searchAgain(tester);
    expect(find.text('병원 정보를 불러오지 못했어요.'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('병원 정보를 불러오지 못했어요.'), findsNothing);
    expect(find.text('1. 강남재활의학과의원'), findsOneWidget);
  });

  testWidgets('지역 목록을 못 불러오면 지역 고르기에서 다시 시도할 수 있다', (tester) async {
    await pumpApp(tester, await makeServices(repository: FlakyRepository(regionFailures: 1)));
    await chooseUntilRegion(tester, type: '시각장애', need: '일반 진료');
    expect(find.text('지역 정보를 불러오지 못했어요.'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('서울특별시'), findsOneWidget);
  });

  testWidgets('지난번 조건으로 찾다가 지역을 못 불러오면, 다시 누를 때 다시 읽는다', (tester) async {
    // 병원 찾기 탭이 처음 한 번 지역을 읽으므로 두 번 실패하게 한다.
    await pumpApp(
      tester,
      await makeServices(
        repository: FlakyRepository(regionFailures: 2),
        searchStore: FakeSearchStore(gangnamRehab),
      ),
    );
    await searchAgain(tester);
    expect(find.text('지역 정보를 불러오지 못했어요. 다시 눌러 주세요.'), findsOneWidget);

    await searchAgain(tester);
    expect(find.text('1. 강남재활의학과의원'), findsOneWidget);
  });

  group('맞는 병원이 없으면', () {
    const hearing = SearchConditions(
      types: {DisabilityType.hearing},
      severity: Severity.mild,
      need: CareNeed.general,
      age: AgeGroup.adult,
      regionCode: '110000',
      regionName: '서울특별시',
      districtName: '강남구',
    );

    testWidgets('0곳이라고 하지 않고 조건을 넓히게 한다: 이웃 시·도까지 찾기', (tester) async {
      await pumpApp(tester, await makeServices(searchStore: FakeSearchStore(hearing)));
      await searchAgain(tester);

      expect(find.textContaining('조건에 맞는 병원을 찾지 못했어요'), findsOneWidget);
      expect(find.text('조건을 넓혀 볼까요?'), findsOneWidget);
      expect(find.text('경기도까지 찾아요.'), findsOneWidget);
      expect(find.textContaining('0곳'), findsNothing);
      expect(find.textContaining('직선거리'), findsNothing);

      await tapAndSettle(tester, '이웃 시·도까지 찾기');
      expect(find.text('1. 성남이비인후과의원'), findsOneWidget);
      expect(find.textContaining('이웃 경기도까지 찾았어요.'), findsOneWidget);
    });

    testWidgets('진료 목적 바꾸기: 고른 조건을 둔 채 병원 찾기의 진료 단계로 간다', (tester) async {
      await pumpApp(tester, await makeServices(searchStore: FakeSearchStore(hearing)));
      await searchAgain(tester);

      await tapAndSettle(tester, '진료 목적 바꾸기');
      expect(find.text('어떤 진료가 필요하신가요?'), findsOneWidget);
      expect(find.text('3 / 6 단계'), findsOneWidget);
      await tester.tap(find.text('이전'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('이전'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CheckboxListTile>(find.widgetWithText(CheckboxListTile, '청각장애')).value,
        isTrue,
      );
    });
  });

  testWidgets('병원 상세에 의사 수·개원 연도·홈페이지와 길찾기·공유·즐겨찾기가 나온다', (tester) async {
    await pumpApp(tester, await makeServices(searchStore: FakeSearchStore(gangnamRehab)));
    await searchAgain(tester);
    await tester.tap(find.text('1. 강남재활의학과의원'));
    await tester.pumpAndSettle();

    expect(find.text('의사 5명'), findsOneWidget);
    expect(find.text('그중 전문의 3명'), findsOneWidget);
    expect(find.text('2015년 개원'), findsOneWidget);
    expect(find.text('http://gangnam.example'), findsOneWidget);
    expect(find.text('길찾기'), findsOneWidget);
    expect(find.text('공유하기'), findsOneWidget);
    expect(find.text('즐겨찾기에 넣기'), findsOneWidget);
    // 진료 카드를 만들지 않았으면 보여 주기 버튼이 없다.
    expect(find.text('진료 카드 보여 주기'), findsNothing);
    await scrollTo(tester, find.text('추천 이유'));
  });

  testWidgets('정보가 틀렸어요: 고른 항목과 병원 ID 로 메일을 만들고, 개인 정보는 넣지 않는다', (tester) async {
    // 신고 화면 전체가 한 화면에 보이게 화면을 길게 한다.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final opened = mockUrlLauncher(tester);
    await pumpApp(tester, await makeServices(searchStore: FakeSearchStore(gangnamRehab)));
    await searchAgain(tester);
    await tester.tap(find.text('1. 강남재활의학과의원'));
    await tester.pumpAndSettle();

    await tapAndSettle(tester, '정보가 틀렸어요');
    // 아이콘이 붙은 버튼은 FilledButton 의 하위 클래스라 byType 으로는 찾지 못한다.
    bool sendEnabled() => tester
        .widget<ButtonStyleButton>(find.ancestor(
            of: find.text('메일로 보내기'), matching: find.bySubtype<ButtonStyleButton>()))
        .enabled;
    expect(sendEnabled(), isFalse);
    await tapAndSettle(tester, '전화번호');
    await tester.enterText(find.byType(TextField), '번호가 바뀌었어요');
    await tester.pump();
    expect(sendEnabled(), isTrue);
    await tapAndSettle(tester, '메일로 보내기');

    final mail = Uri.decodeFull(opened.single);
    expect(mail, startsWith('mailto:help@example.com?subject=[함께병원 정보 오류] 강남재활의학과의원'));
    expect(mail, contains('병원 ID: h1'));
    expect(mail, contains('틀린 정보: 전화번호'));
    expect(mail, contains('자세한 내용: 번호가 바뀌었어요'));
    expect(mail, contains('앱 버전: 1.0.0 (1)'));
    expect(mail, contains('데이터 기준일: 2026-10-07'));
    expect(mail, isNot(contains('지체장애')));
    expect(find.textContaining('메일 앱에서 보내 주시면'), findsOneWidget);
  });

  testWidgets('병원 이름으로 찾아 바로 상세를 연다', (tester) async {
    await pumpApp(tester, await makeServices());
    await tapAndSettle(tester, '병원 이름으로 찾기');
    expect(find.textContaining('병원 이름이나 지역을 입력하세요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '없는병원');
    await tester.pumpAndSettle();
    expect(find.textContaining('찾는 병원이 없어요'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '강남 피부');
    await tester.pumpAndSettle();
    expect(find.text('1곳을 찾았어요.'), findsOneWidget);
    expect(find.text('의원 · 서울특별시 강남구'), findsOneWidget);

    await tester.tap(find.text('강남피부과의원'));
    await tester.pumpAndSettle();
    expect(find.text('서울특별시 강남구 테헤란로 3'), findsOneWidget);
    // 추천에서 연 게 아니므로 거리와 추천 이유는 없다.
    expect(find.text('추천 이유'), findsNothing);
    expect(find.textContaining('km'), findsNothing);
  });

  testWidgets('즐겨찾기에 넣고, 탭에서 열고 전화하고, 뺀다. 본 병원은 최근 본 병원에 남는다', (tester) async {
    final opened = mockUrlLauncher(tester);
    final favorites = FakeSavedHospitalsStore();
    final recent = FakeSavedHospitalsStore();
    await pumpApp(tester, await makeServices(favoritesStore: favorites, recentStore: recent));
    await tapTab(tester, '즐겨찾기');
    expect(find.textContaining('즐겨찾기한 병원이 없어요'), findsOneWidget);
    expect(find.textContaining('최근 본 병원이 없어요'), findsOneWidget);

    await tapTab(tester, '홈');
    await tapAndSettle(tester, '병원 이름으로 찾기');
    await tester.enterText(find.byType(TextField), '재활');
    await tester.pumpAndSettle();
    await tester.tap(find.text('강남재활의학과의원'));
    await tester.pumpAndSettle();
    await tapAndSettle(tester, '즐겨찾기에 넣기');
    expect(find.text('즐겨찾기에서 빼기'), findsOneWidget);
    expect(favorites.saved.single.name, '강남재활의학과의원');

    await goBack(tester);
    await tester.pumpAndSettle();
    await goBack(tester);
    await tester.pumpAndSettle();
    await tapTab(tester, '즐겨찾기');
    // 즐겨찾기 카드와 최근 본 병원에 하나씩 있다.
    expect(find.text('강남재활의학과의원'), findsNWidgets(2));
    expect(recent.saved.single.name, '강남재활의학과의원');

    await tester.tap(find.text('전화'));
    await tester.pumpAndSettle();
    expect(opened, ['tel:02-000-0000']);

    await tester.tap(find.text('강남재활의학과의원').first);
    await tester.pumpAndSettle();
    expect(find.text('서울특별시 강남구 테헤란로 1'), findsOneWidget);
    await goBack(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('강남재활의학과의원 즐겨찾기에서 빼기'));
    await tester.pumpAndSettle();
    expect(find.textContaining('즐겨찾기한 병원이 없어요'), findsOneWidget);
    expect(favorites.saved, isEmpty);
  });

  testWidgets('결과를 가까운 순으로 바꾸고, 지정 기관·편의시설 정보·거리로 거른다', (tester) async {
    // 결과 두 곳이 한 화면에 모두 보이게 화면을 길게 한다.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    await pumpApp(
      tester,
      await makeServices(
        searchStore: FakeSearchStore(gangnamRehab),
        repository: FakeRepository(hospitals: const [
          Hospital(
            id: 'near',
            name: '가까운재활의원',
            region: '110000',
            address: '서울특별시 강남구 1',
            lat: 37.5175,
            lng: 127.0470,
            departments: {'재활의학과'},
          ),
          Hospital(
            id: 'far',
            name: '먼재활병원',
            region: '110000',
            address: '서울특별시 노원구 1',
            lat: 37.6,
            lng: 127.0470,
            departments: {'재활의학과'},
            categories: {InstitutionCategory.rehabDesignated},
            facilities: {Facility.wheelchair},
            absentFacilities: {Facility.parking},
          ),
        ]),
      ),
    );
    await searchAgain(tester);

    // 추천순: 지정 재활의료기관이 멀어도 먼저. 없다고 확인된 시설은 카드에서 알린다.
    expect(top('1. 먼재활병원'), lessThan(top('2. 가까운재활의원')));
    expect(find.text('확인 필요 · 없다고 확인됨: 장애인 주차'), findsOneWidget);

    await tapAndSettle(tester, '가까운 순');
    expect(top('1. 가까운재활의원'), lessThan(top('2. 먼재활병원')));
    expect(find.textContaining('조건에 맞는 병원 중 가까운 2곳이에요'), findsOneWidget);

    await tapAndSettle(tester, '지정 기관만');
    expect(find.textContaining('가까운재활의원'), findsNothing);
    expect(find.text('1. 먼재활병원'), findsOneWidget);
    expect(find.textContaining('정부 지정 기관만 보여줘요'), findsOneWidget);
    await tapAndSettle(tester, '지정 기관만');

    await tapAndSettle(tester, '편의시설 정보 있는 곳만');
    expect(find.textContaining('가까운재활의원'), findsNothing);
    await tapAndSettle(tester, '편의시설 정보 있는 곳만');

    await tapAndSettle(tester, '5 km 안');
    expect(find.text('1. 가까운재활의원'), findsOneWidget);
    expect(find.textContaining('먼재활병원'), findsNothing);
    expect(find.textContaining('5 km 안의 병원만 보여줘요'), findsOneWidget);
  });

  testWidgets('병원 정보 기준일을 보여주고, 설정에서 새 정보를 바로 받을 수 있다', (tester) async {
    await pumpApp(tester, await makeServices(repository: FakeRepository(updateResult: UpdateResult.updated)));
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
    await scrollTo(tester, find.text('2026-10-07 기준 공공데이터'));

    await tapAndSettle(tester, '지금 새 정보 확인하기');
    expect(find.text('새 병원 정보를 받았어요.'), findsOneWidget);
    expect(find.text('2026-10-26 기준 공공데이터'), findsOneWidget);
  });

  testWidgets('새 정보를 확인하지 못하면 이유를 알려준다', (tester) async {
    await pumpApp(tester, await makeServices(repository: FakeRepository(updateResult: UpdateResult.failed)));
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();

    await tapAndSettle(tester, '지금 새 정보 확인하기');
    expect(find.textContaining('인터넷 연결을 확인'), findsOneWidget);
    expect(find.text('2026-10-07 기준 공공데이터'), findsOneWidget);
  });

  testWidgets('앱을 다시 켜면 저장해 둔 즐겨찾기·최근 본 병원을 바꾸기 전에도 바로 보여 준다', (tester) async {
    final favorites = FakeSavedHospitalsStore()..saved = [SavedHospital.of(defaultHospitals.first)];
    final recent = FakeSavedHospitalsStore()..saved = [SavedHospital.of(defaultHospitals.last)];
    await pumpApp(tester, await makeServices(favoritesStore: favorites, recentStore: recent));

    await tapTab(tester, '즐겨찾기');
    expect(find.text('강남재활의학과의원'), findsOneWidget);
    expect(find.text('강남피부과의원'), findsOneWidget);
    expect(find.textContaining('즐겨찾기한 병원이 없어요'), findsNothing);

    // 병원 정보에서도 이미 즐겨찾기한 병원으로 보인다.
    await tester.tap(find.text('강남재활의학과의원'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에서 빼기'), findsOneWidget);
  });

  testWidgets('앱 바의 뒤로 가기 버튼은 휴대폰 언어와 상관없이 한국어로 읽힌다', (tester) async {
    await pumpApp(tester, await makeServices(searchStore: FakeSearchStore(gangnamRehab)));
    await searchAgain(tester);

    expect(find.byTooltip('뒤로'), findsOneWidget);
    expect(find.byTooltip('Back'), findsNothing);
  });

  group('홈 화면 바로가기', () {
    const card = CareCard(name: '김함께', types: {DisabilityType.hearing}, severity: Severity.severe);

    testWidgets('앱이 켜진 뒤 누르면 그 탭으로 가고, 진료 카드가 있으면 바로 병원에 보여 준다', (tester) async {
      final services = await makeServices(careCardStore: FakeCareCardStore(card));
      await pumpApp(tester, services);

      services.shortcut.value = AppShortcut.favorites;
      await tester.pumpAndSettle();
      expect(find.textContaining('즐겨찾기한 병원이 없어요'), findsOneWidget);
      // 한 번 연 바로가기는 비워서, 탭을 다시 만들어도 또 열지 않는다.
      expect(services.shortcut.value, isNull);

      services.shortcut.value = AppShortcut.card;
      await tester.pumpAndSettle();
      expect(find.text('안녕하세요. 저는 김함께예요.'), findsOneWidget);
      expect(find.text('나의 진료 카드'), findsNothing);
    });

    testWidgets('카드를 아직 만들지 않았으면 진료 카드 바로가기는 카드 탭만 연다', (tester) async {
      final services = await makeServices();
      await pumpApp(tester, services);

      services.shortcut.value = AppShortcut.card;
      await tester.pumpAndSettle();
      expect(find.text('진료 카드 만들기'), findsOneWidget);
      expect(find.text('병원에 보여 주기'), findsNothing);
    });

    testWidgets('꺼져 있던 앱을 바로가기로 켜면 첫 화면이 생긴 뒤 그 화면을 연다', (tester) async {
      final services = await makeServices();
      // 바로가기는 탭 화면이 생기기 전에 들어온다.
      services.shortcut.value = AppShortcut.find;
      await pumpApp(tester, services);

      expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);
      expect(services.shortcut.value, isNull);
    });
  });
}
