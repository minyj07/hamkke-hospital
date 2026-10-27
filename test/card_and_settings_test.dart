import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/saved_hospitals.dart';
import 'package:hamkke_hospital/models/care_card.dart';
import 'package:hamkke_hospital/models/disability.dart';

import 'fakes.dart';

const card = CareCard(
  name: '김함께',
  types: {DisabilityType.hearing},
  severity: Severity.severe,
  communication: {Communication.writing},
  guardianName: '엄마',
  guardianPhone: '010-1234-5678',
);

void main() {
  Future<void> openSettings(WidgetTester tester) async {
    await tapTab(tester, '홈');
    await tester.tap(find.byTooltip('설정'));
    await tester.pumpAndSettle();
  }

  group('나의 진료 카드', () {
    testWidgets('만들어 저장하면 탭에 보이고, 병원에 보여 주는 동안 화면을 켜 둔다', (tester) async {
      final store = FakeCareCardStore();
      final screenOn = <bool>[];
      await pumpApp(tester, await makeServices(careCardStore: store, screenOn: screenOn));
      await tapTab(tester, '진료 카드');
      await tapAndSettle(tester, '진료 카드 만들기');

      await tester.enterText(find.widgetWithText(TextField, '이름 또는 불러 주었으면 하는 이름'), '이지현');
      await tapAndSettle(tester, '청각장애');
      await tapAndSettle(tester, '장애의 정도가 심한 장애인');
      await tapAndSettle(tester, '필담(글로 쓰기)');
      await tapAndSettle(tester, '차례 알려 주기');
      await tester.enterText(find.widgetWithText(TextField, '주의할 점'), '큰 소리에 놀라요.');
      await tapAndSettle(tester, '저장하기');

      expect(find.text('진료 카드를 저장했어요.'), findsOneWidget);
      expect(store.saved?.name, '이지현');
      expect(find.text('안녕하세요. 저는 이지현이에요.'), findsOneWidget);
      expect(find.text('저는 청각장애가 있어요.'), findsOneWidget);

      await tapAndSettle(tester, '병원에 보여 주기');
      expect(find.text('글로 써 주세요.'), findsOneWidget);
      expect(find.text('제 차례가 되면 직접 와서 알려 주세요.'), findsOneWidget);
      expect(find.text('큰 소리에 놀라요.'), findsOneWidget);
      expect(screenOn, [true]);
      await goBack(tester);
      await tester.pumpAndSettle();
      expect(screenOn, [true, false]);
    });

    testWidgets('자주 쓰는 문장을 누르면 크게 보여 준다', (tester) async {
      await pumpApp(tester, await makeServices());
      await tapTab(tester, '진료 카드');
      await tapAndSettle(tester, '자주 쓰는 문장');
      await tapAndSettle(tester, '화장실에 가고 싶어요.');

      expect(find.text('크게 보기'), findsOneWidget);
      expect(find.text('화장실에 가고 싶어요.'), findsOneWidget);
    });

    testWidgets('보호자에게 바로 전화하고, 병원 정보에서도 카드를 연다', (tester) async {
      final opened = mockUrlLauncher(tester);
      await pumpApp(
        tester,
        await makeServices(
          careCardStore: FakeCareCardStore(card),
          searchStore: FakeSearchStore(gangnamRehab),
        ),
      );
      await tapTab(tester, '진료 카드');
      await tapAndSettle(tester, '보호자에게 전화 (엄마)');
      expect(opened, ['tel:010-1234-5678']);

      await tapTab(tester, '홈');
      await tapAndSettle(tester, '지난번 조건으로 다시 찾기');
      await tester.tap(find.text('1. 강남재활의학과의원'));
      await tester.pumpAndSettle();
      await tapAndSettle(tester, '진료 카드 보여 주기');
      expect(find.text('안녕하세요. 저는 김함께예요.'), findsOneWidget);
    });

    testWidgets('고치다가 그냥 나가려 하면 한 번 묻는다', (tester) async {
      final store = FakeCareCardStore(card);
      await pumpApp(tester, await makeServices(careCardStore: store));
      await tapTab(tester, '진료 카드');
      await tapAndSettle(tester, '카드 고치기');
      await tester.enterText(find.widgetWithText(TextField, '이름 또는 불러 주었으면 하는 이름'), '다른이름');
      await tester.pump();

      await goBack(tester);
      await tester.pumpAndSettle();
      expect(find.text('저장하지 않고 나갈까요?'), findsOneWidget);
      await tester.tap(find.text('나가기'));
      await tester.pumpAndSettle();
      expect(find.text('카드 고치기'), findsOneWidget);
      expect(store.saved?.name, '김함께');
    });
  });

  group('설정', () {
    testWidgets('글자 크기와 고대비를 바꾸면 바로 적용하고 저장한다', (tester) async {
      final store = FakeSettingsStore();
      await pumpApp(tester, await makeServices(settingsStore: store));
      await openSettings(tester);
      double scale() => MediaQuery.textScalerOf(tester.element(find.text('고대비 모드'))).scale(10);
      final before = Theme.of(tester.element(find.text('고대비 모드'))).colorScheme.onSurfaceVariant;

      await tapAndSettle(tester, '휴대폰 글자 크기 따르기');
      expect(store.saved['textScale'], 1.0);
      await tester.drag(find.byType(Slider), const Offset(600, 0));
      await tester.pumpAndSettle();
      expect(store.saved['textScale'], 2.0);
      expect(scale(), 20);

      await tapAndSettle(tester, '고대비 모드');
      expect(store.saved['highContrast'], isTrue);
      expect(Theme.of(tester.element(find.text('고대비 모드'))).colorScheme.onSurfaceVariant,
          isNot(before));
    });

    testWidgets('내 정보 전부 지우기는 카드·조건·즐겨찾기·최근 본 병원을 지우고 찾기 화면도 비운다',
        (tester) async {
      final cardStore = FakeCareCardStore(card);
      final searchStore = FakeSearchStore(gangnamRehab);
      final favorites = FakeSavedHospitalsStore()
        ..saved = [SavedHospital.of(defaultHospitals.first)];
      final recent = FakeSavedHospitalsStore()..saved = [SavedHospital.of(defaultHospitals.last)];
      final services = await makeServices(
        careCardStore: cardStore,
        searchStore: searchStore,
        favoritesStore: favorites,
        recentStore: recent,
      );
      await pumpApp(tester, services);
      await tapTab(tester, '병원 찾기');
      await tapNext(tester);
      expect(find.text('2 / 6 단계'), findsOneWidget);

      await openSettings(tester);
      await tapAndSettle(tester, '내 정보 전부 지우기');
      await tester.tap(find.text('모두 지우기'));
      await tester.pumpAndSettle();

      expect(find.text('내 정보를 모두 지웠어요.'), findsOneWidget);
      expect(cardStore.saved, isNull);
      expect(searchStore.saved, isNull);
      expect(favorites.saved, isEmpty);
      expect(recent.saved, isEmpty);
      await goBack(tester);
      await tester.pumpAndSettle();
      expect(find.text('지난번 조건'), findsNothing);
      await tapTab(tester, '병원 찾기');
      expect(find.text('1 / 6 단계'), findsOneWidget);
      expect(nextEnabled(tester), isFalse);
    });

    testWidgets('휴대폰에 잠금이 없으면 앱 잠금을 켜지 않고 알려 준다', (tester) async {
      final lock = FakeAppLock(available: false);
      final store = FakeSettingsStore();
      await pumpApp(tester, await makeServices(appLock: lock, settingsStore: store));
      await openSettings(tester);
      await tapAndSettle(tester, '앱 잠금');

      expect(find.textContaining('화면 잠금(PIN·패턴·지문 등)을 먼저 설정해 주세요'), findsOneWidget);
      expect(store.saved['appLock'], isNot(true));
      expect(lock.unlocks, 0);
    });

    testWidgets('앱 잠금을 켜면 한 번 풀어 보고, 다음에 켤 때 잠금 화면을 보여 준다', (tester) async {
      final lock = FakeAppLock();
      final store = FakeSettingsStore();
      await pumpApp(tester, await makeServices(appLock: lock, settingsStore: store));
      await openSettings(tester);
      await tapAndSettle(tester, '앱 잠금');
      expect(lock.unlocks, 1);
      expect(store.saved['appLock'], isTrue);

      // 앱을 다시 켠다. 처음 자동으로 띄운 확인은 실패한다.
      lock.succeeds = false;
      await tester.pumpWidget(const SizedBox());
      await pumpApp(
        tester,
        await makeServices(appLock: lock, settingsStore: store, careCardStore: FakeCareCardStore(card)),
      );
      expect(find.text('함께병원이 잠겨 있어요'), findsOneWidget);
      expect(find.textContaining('잠금을 풀지 못했어요'), findsOneWidget);
      expect(find.text('무엇을 도와드릴까요?'), findsNothing);
      // 잠겨 있을 때 카드를 보여 주는 것은 기본으로 꺼져 있다.
      expect(find.text('병원에 보여 주기'), findsNothing);

      lock.succeeds = true;
      await tester.tap(find.text('잠금 풀기'));
      await tester.pumpAndSettle();
      expect(find.text('무엇을 도와드릴까요?'), findsOneWidget);
    });

    testWidgets('잠겨 있어도 보여 주기를 켜면 잠금 화면에서 진료 카드를 연다', (tester) async {
      final lock = FakeAppLock(succeeds: false);
      await pumpApp(
        tester,
        await makeServices(
          appLock: lock,
          settingsStore: FakeSettingsStore(
              {'onboardingDone': true, 'appLock': true, 'showCardWhenLocked': true}),
          careCardStore: FakeCareCardStore(card),
        ),
      );
      expect(find.text('함께병원이 잠겨 있어요'), findsOneWidget);

      await tester.tap(find.text('병원에 보여 주기'));
      await tester.pumpAndSettle();
      expect(find.text('안녕하세요. 저는 김함께예요.'), findsOneWidget);
      expect(find.text('나의 진료 카드'), findsNothing);
    });
  });
}
