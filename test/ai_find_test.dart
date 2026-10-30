// AI로 말해서 찾기 화면 테스트. 앱에 든 AI 모델(assets/ai/intent_model.bin)을 그대로 쓴다.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/ai/intent_model.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/screens/ai_find_screen.dart';
import 'package:hamkke_hospital/screens/results_screen.dart';
import 'package:hamkke_hospital/ui/widgets.dart';

import 'fakes.dart';

const _understood = 'AI가 이렇게 이해했어요';

/// 화면 아래의 큰 버튼.
FilledButton _primary(WidgetTester tester) => tester.widget<FilledButton>(find.byType(FilledButton));

Future<void> _openAi(WidgetTester tester) => tapAndSettle(tester, 'AI로 말해서 찾기');

/// 글 칸에 [text] 를 적고 'AI로 조건 알아보기'를 누른다.
Future<void> _ask(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField), text);
  await tester.pump();
  await tester.tap(find.text('AI로 조건 알아보기'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('홈의 카드로 열고, 적은 글에서 조건을 알아내 그 조건으로 바로 찾는다', (tester) async {
    final store = FakeSearchStore();
    await pumpApp(tester, await makeServices(searchStore: store));
    await _openAi(tester);
    expect(find.text('어떤 병원을 찾으세요?'), findsOneWidget);
    // 글을 적기 전에는 알아볼 수 없다.
    expect(_primary(tester).onPressed, isNull);
    await scrollTo(tester, find.textContaining('인터넷으로 보내거나 저장하지 않아요'));

    await _ask(tester, '청각장애가 심해서 수어 통역 되는 내과를 찾아요 강남');
    expect(find.text(_understood), findsOneWidget);
    expect(find.text('청각장애'), findsOneWidget);
    expect(find.text(Severity.severe.label), findsOneWidget);
    expect(find.text('일반 진료'), findsOneWidget);
    expect(find.text('서울특별시 강남구'), findsOneWidget);
    expect(find.textContaining('수어 통역'), findsWidgets);

    await tester.tap(find.text('이 조건으로 병원 찾기'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
    // 적은 글이 아니라 알아낸 조건만 지난번 검색 조건으로 저장된다.
    final saved = store.saved!;
    expect(saved.types, {DisabilityType.hearing});
    expect(saved.severity, Severity.severe);
    expect(saved.need, CareNeed.general);
    expect(saved.age, AgeGroup.adult);
    expect((saved.regionCode, saved.districtName), ('110000', '강남구'));
    expect(saved.facilities, contains(Facility.signLanguage));
  });

  testWidgets('글에 장애 정도가 없으면 그것만 묻고, 지역이 없으면 현재 위치로 찾는다', (tester) async {
    final store = FakeSearchStore();
    await pumpApp(tester, await makeServices(searchStore: store));
    await _openAi(tester);

    // 예시를 누르면 글 칸을 채우고 바로 알아본다.
    await tapAndSettle(tester, aiExamples[1]);
    expect(find.text(_understood), findsOneWidget);
    expect(find.text('자폐성장애'), findsOneWidget);
    expect(find.text('치과 진료'), findsOneWidget);
    expect(find.text('어린이·청소년'), findsOneWidget);
    expect(find.text('현재 위치'), findsOneWidget);
    expect(find.text('장애의 정도만 골라 주시면 바로 찾을 수 있어요.'), findsOneWidget);
    expect(_primary(tester).onPressed, isNull);

    await tapAndSettle(tester, Severity.mild.label);
    expect(_primary(tester).onPressed, isNotNull);
    await tester.tap(find.text('이 조건으로 병원 찾기'));
    await tester.pumpAndSettle();
    expect(find.byType(ResultsScreen), findsOneWidget);
    final saved = store.saved!;
    expect(saved.types, {DisabilityType.autism});
    expect(saved.severity, Severity.mild);
    expect(saved.need, CareNeed.dental);
    expect(saved.age, AgeGroup.child);
    expect(saved.nearMe, isTrue);
  });

  testWidgets('조건 고쳐서 찾기는 알아낸 조건으로 병원 찾기를 채우고 모르는 단계를 연다', (tester) async {
    await pumpApp(tester, await makeServices());
    await _openAi(tester);
    await tapAndSettle(tester, aiExamples[0]);
    expect(find.text('지체장애'), findsOneWidget);
    expect(find.text('만성질환 관리'), findsOneWidget);

    await tapAndSettle(tester, '조건 고쳐서 찾기');
    expect(find.text('장애의 정도를 알려주세요'), findsOneWidget);
    await tapAndSettle(tester, Severity.severe.label);
    await tapNext(tester);
    // 진료는 AI 가 알아낸 대로 골라져 있다.
    final chronic = find.widgetWithText(OptionTile, '만성질환 관리');
    await scrollTo(tester, chronic);
    expect(tester.widget<OptionTile>(chronic).selected, isTrue);

    // 첫 단계로 돌아가면 AI 가 골라 둔 장애와 그 안내가 보인다.
    await tester.tap(find.byTooltip('이전 단계'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('이전 단계'));
    await tester.pumpAndSettle();
    expect(find.textContaining('AI가 알아들은 조건으로 미리 골라 두었어요'), findsOneWidget);
    expect(tester.widget<OptionTile>(find.widgetWithText(OptionTile, '지체장애')).selected, isTrue);
  });

  testWidgets('장애를 알아듣지 못하면 단계별로 고르게 한다', (tester) async {
    await pumpApp(tester, await makeServices());
    await _openAi(tester);
    await _ask(tester, '안녕하세요');
    expect(find.text('알아듣지 못했어요'), findsOneWidget);
    expect(find.textContaining('장애를 알아듣지 못했어요'), findsOneWidget);

    await tester.tap(find.text('단계별로 골라서 찾기'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);
  });

  testWidgets('글을 고치면 알아낸 것을 지우고, 내 정보를 지우면 적은 글도 지운다', (tester) async {
    final services = await makeServices();
    await pumpApp(tester, services);
    await _openAi(tester);
    await tapAndSettle(tester, aiExamples[2]);
    expect(find.text(_understood), findsOneWidget);

    // 알아본 뒤에는 알아낸 것이 보이게 굴려 두므로, 글 칸까지 올라가서 고친다.
    await tester.scrollUntilVisible(find.byType(TextField), -200, scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byType(TextField), '청각장애가 심해서');
    await tester.pump();
    expect(find.text(_understood), findsNothing);
    expect(find.text('AI로 조건 알아보기'), findsOneWidget);

    await services.clearPersonalData();
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, isEmpty);
    expect(_primary(tester).onPressed, isNull);
  });

  testWidgets('뒤로 가기와 AI 설명', (tester) async {
    await pumpApp(tester, await makeServices());
    await _openAi(tester);
    await tapAndSettle(tester, 'AI는 어떻게 알아듣나요?');
    expect(find.textContaining('이 휴대폰에서만 글을 읽어요'), findsOneWidget);
    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('홈으로'));
    await tester.pumpAndSettle();
    expect(find.text('어떤 병원을 찾으세요?'), findsNothing);
    expect(find.text('상황을 말하듯 적으면 AI가 조건을 골라 드려요'), findsOneWidget);

    // 휴대폰의 뒤로 가기도 홈으로 간다. 다시 열면 하던 자리(굴린 곳)가 그대로다.
    await _openAi(tester);
    expect(find.widgetWithText(AppBar, 'AI로 말해서 찾기'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AppBar, 'AI로 말해서 찾기'), findsNothing);
    expect(find.text('상황을 말하듯 적으면 AI가 조건을 골라 드려요'), findsOneWidget);
  });

  testWidgets('AI 모델을 읽지 못하면 알리고, 다시 시도하면 쓸 수 있다', (tester) async {
    var fail = true;
    final services = await makeServices(
      intent: IntentService(read: () async {
        if (fail) throw StateError('모델 읽기 실패');
        return modelBytes();
      }),
    );
    await pumpApp(tester, services);
    await _openAi(tester);
    expect(find.text('AI를 불러오지 못했어요.'), findsOneWidget);

    fail = false;
    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('AI를 불러오지 못했어요.'), findsNothing);
    await _ask(tester, '휠체어 타는 엄마 재활 치료');
    expect(find.text(_understood), findsOneWidget);
  });
}
