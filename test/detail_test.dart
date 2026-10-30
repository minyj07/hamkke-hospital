// 병원 정보·정보 오류 신고·설정의 병원 정보 업데이트 화면 테스트.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/data_store.dart';

import 'fakes.dart';

void main() {
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
    expect(mail, startsWith('mailto:help@example.com?subject=[메디움 정보 오류] 강남재활의학과의원'));
    expect(mail, contains('병원 ID: h1'));
    expect(mail, contains('틀린 정보: 전화번호'));
    expect(mail, contains('자세한 내용: 번호가 바뀌었어요'));
    expect(mail, contains('앱 버전: 1.0.0 (1)'));
    expect(mail, contains('데이터 기준일: 2026-10-07'));
    expect(mail, isNot(contains('지체장애')));
    expect(find.textContaining('메일 앱에서 보내 주시면'), findsOneWidget);
  });

  testWidgets('병원 정보 기준일을 보여주고, 설정에서 새 정보를 바로 받을 수 있다', (tester) async {
    await pumpApp(tester, await makeServices(repository: FakeRepository(updateResult: UpdateResult.updated)));
    await openSettings(tester);
    await scrollTo(tester, find.text('2026-10-07 기준 공공데이터'));

    await tapAndSettle(tester, '지금 새 정보 확인하기');
    expect(find.text('새 병원 정보를 받았어요.'), findsOneWidget);
    expect(find.text('2026-10-26 기준 공공데이터'), findsOneWidget);
  });

  testWidgets('새 정보를 확인하지 못하면 이유를 알려준다', (tester) async {
    await pumpApp(tester, await makeServices(repository: FakeRepository(updateResult: UpdateResult.failed)));
    await openSettings(tester);

    await tapAndSettle(tester, '지금 새 정보 확인하기');
    expect(find.textContaining('인터넷 연결을 확인'), findsOneWidget);
    expect(find.text('2026-10-07 기준 공공데이터'), findsOneWidget);
  });
}
