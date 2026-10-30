// 홈·하단 탭·즐겨찾기·마이페이지·홈 검색·홈 화면 바로가기 화면 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/saved_hospitals.dart';
import 'package:hamkke_hospital/models/care_card.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/search_conditions.dart';
import 'package:hamkke_hospital/screens/app_scope.dart';
import 'package:hamkke_hospital/services/location.dart';

import 'fakes.dart';

const _homeTitle = '나에게 맞는\n병원을 찾아보세요';
const _noFavorites = '아직 저장한 병원이 없어요';

/// 홈 목록 안의 [label] (하단 탭에도 같은 글이 있을 때 쓴다).
Finder _onHome(String label) =>
    find.descendant(of: find.byType(ListView).first, matching: find.text(label));

void main() {
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
    expect(find.text(_homeTitle), findsOneWidget);
    expect(store.saved['onboardingDone'], isTrue);
  });

  testWidgets('홈은 로고와 메디움 이름, 검색창, 바로가기 4개, 내 주변 병원, 자주 찾는 진료과를 보여 준다', (tester) async {
    await pumpApp(tester, await makeServices());

    expect(find.text('메디움'), findsOneWidget);
    expect(find.text(_homeTitle), findsOneWidget);
    expect(find.text('병원 이름, 진료과, 지역으로 검색해보세요'), findsOneWidget);
    for (final label in ['병원 찾기', '나의 진료 카드', '지도에서 찾기']) {
      expect(find.text(label), findsOneWidget);
    }
    expect(_onHome('즐겨찾기'), findsOneWidget);
    await scrollTo(tester, find.text('자주 찾는 진료과'));
    for (final dept in ['내과', '정형외과', '신경과', '외과']) {
      expect(find.text(dept), findsOneWidget);
    }
    // 하단 탭은 홈·즐겨찾기·마이페이지 3개다.
    final tabs = find.descendant(of: find.byType(NavigationBar), matching: find.byType(NavigationDestination));
    expect(tabs, findsNWidgets(3));
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('마이페이지')), findsOneWidget);
    // 지난번 조건이 없으면 다시 찾기 링크도 없다.
    expect(find.text('지난번 조건으로 다시 찾기'), findsNothing);
  });

  testWidgets('홈 바로가기로 병원 찾기·진료 카드·즐겨찾기를 연다', (tester) async {
    await pumpApp(tester, await makeServices());

    await tapAndSettle(tester, '병원 찾기');
    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);
    // 병원 찾기는 탭이 아니어서 탭 막대에서는 홈이 켜져 있다.
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);

    await tapTab(tester, '홈');
    await tapAndSettle(tester, '나의 진료 카드');
    expect(find.text('진료 카드 만들기'), findsOneWidget);
    await goBack(tester);

    await tester.tap(_onHome('즐겨찾기'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_noFavorites), findsOneWidget);
  });

  testWidgets('지도에서 찾기는 네이버 지도에서 병원을 찾는다', (tester) async {
    final opened = mockUrlLauncher(tester);
    await pumpApp(tester, await makeServices());

    await tapAndSettle(tester, '지도에서 찾기');
    expect(Uri.decodeFull(opened.single), startsWith('nmap://search?query=병원'));
  });

  testWidgets('찾은 조건을 저장해 두고, 앱을 다시 켜면 홈에서 바로 다시 찾는다', (tester) async {
    final store = FakeSearchStore();
    await pumpApp(tester, await makeServices(searchStore: store));
    expect(find.text('지난번 조건으로 다시 찾기'), findsNothing);

    await searchGangnam(tester);
    expect(store.saved?.summary, '지체장애 · 재활 치료 · 서울특별시 강남구');
    expect(store.saved?.age, AgeGroup.adult);

    // 앱을 껐다 켠다.
    await tester.pumpWidget(const SizedBox());
    await pumpApp(tester, await makeServices(searchStore: store));
    // 화면낭독기는 지난번 조건도 함께 읽는다.
    expect(tester.widget<Text>(find.text('지난번 조건으로 다시 찾기')).semanticsLabel,
        '지난번 조건으로 다시 찾기: 지체장애 · 재활 치료 · 서울특별시 강남구');

    await searchAgain(tester);
    expect(find.text('1. 강남재활의학과의원'), findsOneWidget);
    expect(find.textContaining('서울특별시 강남구 중심에서'), findsOneWidget);
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
    expect(find.text('1. 강남재활의학과의원'), findsNothing);
    expect(find.text('지난번 조건으로 다시 찾기'), findsOneWidget);
  });

  testWidgets('지난번 조건으로 찾다가 지역을 못 불러오면, 다시 누를 때 다시 읽는다', (tester) async {
    // 병원 찾기 화면과 홈의 내 주변 병원이 켜질 때 한 번씩 지역을 읽으므로 세 번 실패하게 한다.
    await pumpApp(
      tester,
      await makeServices(
        repository: FlakyRepository(regionFailures: 3),
        searchStore: FakeSearchStore(gangnamRehab),
      ),
    );
    await searchAgain(tester);
    expect(find.text('지역 정보를 불러오지 못했어요. 다시 눌러 주세요.'), findsOneWidget);

    await searchAgain(tester);
    expect(find.text('1. 강남재활의학과의원'), findsOneWidget);
  });

  group('홈 검색창', () {
    testWidgets('병원 이름·지역으로 바로 찾아 결과를 아래에 보여 주고, 눌러서 병원 정보를 연다', (tester) async {
      await pumpApp(tester, await makeServices());
      expect(find.textContaining('검색 결과'), findsNothing);

      await tester.enterText(find.byType(TextField), '없는병원');
      await tester.pumpAndSettle();
      expect(find.textContaining('검색 결과가 없어요'), findsOneWidget);

      await tester.enterText(find.byType(TextField), '강남 피부');
      await tester.pumpAndSettle();
      expect(find.text('검색 결과 1곳'), findsOneWidget);
      expect(find.text('의원 · 서울특별시 강남구'), findsOneWidget);

      await tapAndSettle(tester, '강남피부과의원');
      expect(find.text('서울특별시 강남구 테헤란로 3'), findsOneWidget);
      // 추천에서 연 게 아니므로 거리와 추천 이유는 없다.
      expect(find.text('추천 이유'), findsNothing);
      expect(find.textContaining('km'), findsNothing);
    });

    testWidgets('검색어 지우기를 누르면 결과가 사라지고, 결과의 하트로 즐겨찾기에 넣는다', (tester) async {
      final favorites = FakeSavedHospitalsStore();
      await pumpApp(tester, await makeServices(favoritesStore: favorites));

      await tester.enterText(find.byType(TextField), '재활');
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('강남재활의학과의원 즐겨찾기에 넣기'));
      await tester.pumpAndSettle();
      expect(favorites.saved.single.name, '강남재활의학과의원');
      expect(find.byTooltip('강남재활의학과의원 즐겨찾기에서 빼기'), findsOneWidget);

      await tester.tap(find.byTooltip('검색어 지우기'));
      await tester.pumpAndSettle();
      expect(find.textContaining('검색 결과'), findsNothing);
    });
  });

  group('내 주변 병원', () {
    testWidgets('위치는 현재 위치로 보기를 누를 때만 묻고, 가까운 병원을 보여 주며 진료과로 거른다', (tester) async {
      final location = FakeLocationService(const LocationResult(37.5172, 127.0473));
      await pumpApp(tester, await makeServices(locationService: location));
      expect(location.calls, 0);

      await tapAndSettle(tester, '현재 위치로 보기');
      expect(location.calls, 1);
      expect(find.text('현재 위치 기준 · 가까운 순'), findsOneWidget);
      expect(find.text('강남재활의학과의원'), findsOneWidget);
      expect(find.text('강남안과의원'), findsOneWidget);

      await tapAndSettle(tester, '내과');
      expect(find.text('해당 진료과 병원이 근처에 없어요'), findsOneWidget);
      await tapAndSettle(tester, '내과');
      expect(find.text('강남재활의학과의원'), findsOneWidget);
      // 다시 그려도 위치를 또 묻지 않는다.
      expect(location.calls, 1);
    });

    testWidgets('위치를 못 얻으면 이유를 알려 주고 다시 누를 수 있다', (tester) async {
      await pumpApp(
        tester,
        await makeServices(here: const LocationResult.error('위치 권한을 허용해야 현재 위치로 찾을 수 있어요.')),
      );
      await tapAndSettle(tester, '현재 위치로 보기');
      expect(find.text('위치 권한을 허용해야 현재 위치로 찾을 수 있어요.'), findsOneWidget);
      expect(find.text('현재 위치로 보기'), findsOneWidget);
    });

    testWidgets('지난번 조건에 지역이 있으면 위치를 묻지 않고 그 지역 주변 병원을 보여 주고, 하트로 즐겨찾기한다', (tester) async {
      final location = FakeLocationService(const LocationResult(37.5172, 127.0473));
      final favorites = FakeSavedHospitalsStore();
      await pumpApp(
        tester,
        await makeServices(
          locationService: location,
          searchStore: FakeSearchStore(gangnamRehab),
          favoritesStore: favorites,
        ),
      );
      // 홈의 'AI로 말해서 찾기' 카드 아래에 있어서 굴려서 본다.
      await scrollTo(tester, find.text('서울특별시 강남구 기준 · 가까운 순'));
      expect(find.text('서울특별시 강남구 기준 · 가까운 순'), findsOneWidget);
      expect(location.calls, 0);

      await scrollTo(tester, find.byTooltip('강남안과의원 즐겨찾기에 넣기'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('강남안과의원 즐겨찾기에 넣기'));
      await tester.pumpAndSettle();
      expect(favorites.saved.single.name, '강남안과의원');
    });
  });

  testWidgets('즐겨찾기에 넣고, 탭에서 열고 전화하고, 뺀다. 본 병원은 최근 본 병원에 남는다', (tester) async {
    final opened = mockUrlLauncher(tester);
    final favorites = FakeSavedHospitalsStore();
    final recent = FakeSavedHospitalsStore();
    await pumpApp(tester, await makeServices(favoritesStore: favorites, recentStore: recent));
    await tapTab(tester, '즐겨찾기');
    expect(find.text('저장한 병원 0곳'), findsOneWidget);
    expect(find.textContaining(_noFavorites), findsOneWidget);
    expect(find.textContaining('최근 본 병원이 없어요'), findsOneWidget);

    await tapTab(tester, '홈');
    await tester.enterText(find.byType(TextField), '재활');
    await tester.pumpAndSettle();
    await tapAndSettle(tester, '강남재활의학과의원');
    await tapAndSettle(tester, '즐겨찾기에 넣기');
    expect(find.text('즐겨찾기에서 빼기'), findsOneWidget);
    expect(favorites.saved.single.name, '강남재활의학과의원');

    await goBack(tester);
    await tapTab(tester, '즐겨찾기');
    expect(find.text('저장한 병원 1곳'), findsOneWidget);
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

    await tester.tap(find.byTooltip('강남재활의학과의원 즐겨찾기에서 빼기'));
    await tester.pumpAndSettle();
    expect(find.textContaining(_noFavorites), findsOneWidget);
    expect(favorites.saved, isEmpty);
  });

  testWidgets('앱을 다시 켜면 저장해 둔 즐겨찾기·최근 본 병원을 바꾸기 전에도 바로 보여 준다', (tester) async {
    final favorites = FakeSavedHospitalsStore()..saved = [SavedHospital.of(defaultHospitals.first)];
    final recent = FakeSavedHospitalsStore()..saved = [SavedHospital.of(defaultHospitals.last)];
    await pumpApp(tester, await makeServices(favoritesStore: favorites, recentStore: recent));

    await tapTab(tester, '즐겨찾기');
    expect(find.text('강남재활의학과의원'), findsOneWidget);
    expect(find.text('강남피부과의원'), findsOneWidget);
    expect(find.textContaining(_noFavorites), findsNothing);

    // 병원 정보에서도 이미 즐겨찾기한 병원으로 보인다.
    await tester.tap(find.text('강남재활의학과의원'));
    await tester.pumpAndSettle();
    expect(find.text('즐겨찾기에서 빼기'), findsOneWidget);
  });

  group('마이페이지', () {
    testWidgets('진료 카드가 없으면 만들기를, 설정을 연다', (tester) async {
      await pumpApp(tester, await makeServices());
      await tapTab(tester, '마이페이지');

      expect(find.text('아직 만들지 않았어요'), findsOneWidget);
      await tapAndSettle(tester, '진료 카드 만들기');
      expect(find.text('이름 또는 불러 주었으면 하는 이름'), findsOneWidget);
      await goBack(tester);

      await tapAndSettle(tester, '설정');
      expect(find.text('고대비 모드'), findsOneWidget);
    });

    testWidgets('진료 카드가 있으면 이름과 꼬리표를 보여 주고, 병원에 보여 주기를 바로 연다', (tester) async {
      await pumpApp(
        tester,
        await makeServices(
          careCardStore: FakeCareCardStore(const CareCard(
            name: '김함께',
            types: {DisabilityType.hearing},
            severity: Severity.severe,
            help: {HelpNeed.wheelchair},
          )),
        ),
      );
      await tapTab(tester, '마이페이지');

      expect(find.text('김함께 님'), findsOneWidget);
      expect(find.text('청각장애'), findsOneWidget);
      expect(find.text('휠체어 이동'), findsOneWidget);
      await tapAndSettle(tester, '병원에 보여 주기');
      expect(find.text('안녕하세요. 저는 김함께예요.'), findsOneWidget);
    });
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
      expect(find.textContaining(_noFavorites), findsOneWidget);
      // 한 번 연 바로가기는 비워서, 탭을 다시 만들어도 또 열지 않는다.
      expect(services.shortcut.value, isNull);

      services.shortcut.value = AppShortcut.card;
      await tester.pumpAndSettle();
      expect(find.text('안녕하세요. 저는 김함께예요.'), findsOneWidget);
      expect(find.text('나의 진료 카드'), findsNothing);
    });

    testWidgets('카드를 아직 만들지 않았으면 진료 카드 바로가기는 카드 화면만 연다', (tester) async {
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
