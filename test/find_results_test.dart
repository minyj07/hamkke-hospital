// 병원 찾기 6단계와 추천 결과 화면 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/models/care_card.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/search_conditions.dart';
import 'package:hamkke_hospital/services/location.dart';
import 'package:hamkke_hospital/ui/widgets.dart';

import 'fakes.dart';

/// 병원 찾기에서 [label] 줄이 골라져 있는지 (체크 상자·라디오 모두).
bool selected(WidgetTester tester, String label) =>
    tester.widget<OptionTile>(find.widgetWithText(OptionTile, label)).selected;

/// 앱 바의 뒤로 화살표로 이전 단계로 간다.
Future<void> previousStep(WidgetTester tester) async {
  await tester.tap(find.byTooltip('이전 단계'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('병원 찾기는 몇 번째 단계인지 보여 주고, 뒤로 화살표로 이전 단계로 돌아갈 수 있다', (tester) async {
    await pumpApp(tester, await makeServices());
    await openFind(tester);

    expect(find.text('1 / 6 단계'), findsOneWidget);
    expect(nextEnabled(tester), isFalse);
    // 첫 단계의 뒤로 화살표는 이전 단계가 아니라 홈으로 간다.
    expect(find.byTooltip('이전 단계'), findsNothing);
    expect(find.byTooltip('홈으로'), findsOneWidget);

    await tapAndSettle(tester, '지체장애');
    await tapNext(tester);
    expect(find.text('2 / 6 단계'), findsOneWidget);
    expect(find.text('장애의 정도를 알려주세요'), findsOneWidget);

    await previousStep(tester);
    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);
    // 고른 것은 그대로 남아 있다.
    expect(selected(tester, '지체장애'), isTrue);

    // 휴대폰의 뒤로 가기도 앱을 닫지 않고 이전 단계로 간다.
    await tapNext(tester);
    final dynamic app = tester.state(find.byType(WidgetsApp));
    await app.didPopRoute();
    await tester.pumpAndSettle();
    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);

    await tester.tap(find.byTooltip('홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 장애가 있으신가요?'), findsNothing);
    expect(find.text('병원 찾기'), findsOneWidget); // 홈의 바로가기
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

    expect(find.text('찾기 결과'), findsOneWidget);
    expect(find.text('조건에 맞는 병원 1곳'), findsOneWidget);
    expect(find.text('1. 강남재활의학과의원'), findsOneWidget);
    expect(find.textContaining('강남안과의원'), findsNothing);
    // 찾은 조건을 칩으로 보여 준다.
    expect(find.text('지체장애'), findsOneWidget);
    expect(find.text('재활 치료'), findsOneWidget);
    expect(find.text('서울특별시 강남구'), findsOneWidget);
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
    // 병원 정보 화면이 길면 버튼이 첫 화면 아래에 있을 수 있다.
    await scrollTo(tester, find.text('전화하기'));
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
    await openFind(tester);

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

    expect(find.text('찾기 결과'), findsOneWidget);
    // 입력한 내용이 찾은 조건 칩에 그대로 나온다.
    expect(find.text('기타(척수손상)'), findsOneWidget);
    expect(find.text('기타(피부 질환)'), findsOneWidget);
    expect(find.text('현재 위치'), findsOneWidget);
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
    await openFind(tester);

    expect(selected(tester, '청각장애'), isTrue);
    expect(selected(tester, '지체장애'), isFalse);
    expect(find.textContaining('나의 진료 카드에 적은 장애로 미리 골라 두었어요'), findsOneWidget);

    await tapNext(tester);
    expect(selected(tester, '장애의 정도가 심하지 않은 장애인'), isTrue);
    expect(selected(tester, '장애의 정도가 심한 장애인'), isFalse);
    await tapNext(tester);
    // 진료와 나이는 지난번 조건으로 채운다.
    expect(selected(tester, '재활 치료'), isTrue);
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
    // 홈은 지난번 조건으로 다시 찾게 하지만, 위치는 누르기 전에 묻지 않는다.
    expect(find.text('지난번 조건으로 다시 찾기'), findsOneWidget);
    expect(store.saved?.summary, '시각장애 · 일반 진료 · 현재 위치');
    expect(location.calls, 0);

    await searchAgain(tester);

    expect(location.calls, 1);
    expect(find.text('1. 강남안과의원'), findsOneWidget);
    expect(find.textContaining('거리는 현재 위치에서 잰 직선거리예요'), findsOneWidget);
    expect(store.saved!.toJson().containsKey('region'), isFalse);
  });

  testWidgets('병원 정보를 못 불러오면 다시 시도할 수 있다', (tester) async {
    final repository = FlakyRepository();
    await pumpApp(
      tester,
      await makeServices(repository: repository, searchStore: FakeSearchStore(gangnamRehab)),
    );
    // 홈의 '내 주변 병원'이 앱을 켤 때 지난번 지역의 병원을 읽으므로,
    // 그와 상관없이 결과 화면이 처음 읽을 때 실패하도록 앱이 켜진 뒤에 넣는다.
    repository.hospitalFailures = 1;
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
      await previousStep(tester);
      await previousStep(tester);
      expect(selected(tester, '청각장애'), isTrue);
    });
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
    expect(find.text('조건에 맞는 병원 2곳'), findsOneWidget);

    await tapAndSettle(tester, '가까운 순');
    expect(top('1. 가까운재활의원'), lessThan(top('2. 먼재활병원')));
    expect(find.textContaining('조건에 맞는 병원 중 가까운 2곳이에요'), findsOneWidget);

    await tapAndSettle(tester, '지정 기관만');
    expect(find.textContaining('가까운재활의원'), findsNothing);
    expect(find.text('1. 먼재활병원'), findsOneWidget);
    expect(find.text('조건에 맞는 병원 1곳'), findsOneWidget);
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

  testWidgets('결과 카드의 하트로 즐겨찾기에 넣고 뺀다', (tester) async {
    final favorites = FakeSavedHospitalsStore();
    await pumpApp(
      tester,
      await makeServices(searchStore: FakeSearchStore(gangnamRehab), favoritesStore: favorites),
    );
    await searchAgain(tester);

    // 결과 카드는 찾은 조건·순서 아래에 있어 첫 화면 밖일 수 있다.
    await tester.ensureVisible(find.byTooltip('강남재활의학과의원 즐겨찾기에 넣기'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('강남재활의학과의원 즐겨찾기에 넣기'));
    await tester.pumpAndSettle();
    expect(favorites.saved.single.name, '강남재활의학과의원');
    // 하트를 눌러도 병원 정보로 넘어가지 않는다.
    expect(find.text('찾기 결과'), findsOneWidget);

    await tester.tap(find.byTooltip('강남재활의학과의원 즐겨찾기에서 빼기'));
    await tester.pumpAndSettle();
    expect(favorites.saved, isEmpty);
    expect(find.byTooltip('강남재활의학과의원 즐겨찾기에 넣기'), findsOneWidget);
  });
}
