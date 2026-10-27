import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/last_search_store.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/search_conditions.dart';

const gangnam = SearchConditions(
  types: {DisabilityType.physical, DisabilityType.other},
  otherDisability: '척수손상',
  severity: Severity.severe,
  need: CareNeed.other,
  otherNeed: '허리 통증',
  regionCode: '110000',
  regionName: '서울특별시',
  districtName: '강남구',
);

const nearMe = SearchConditions(
  types: {DisabilityType.visual},
  severity: Severity.mild,
  need: CareNeed.general,
);

SearchConditions roundTrip(SearchConditions c) =>
    SearchConditions.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);

void main() {
  group('SearchConditions', () {
    test('저장했다 읽어도 같은 조건이다', () {
      final c = roundTrip(gangnam);
      expect(c.types, orderedEquals([DisabilityType.physical, DisabilityType.other]));
      expect(c.severity, Severity.severe);
      expect((c.otherDisability, c.otherNeed), ('척수손상', '허리 통증'));
      expect((c.regionCode, c.districtName), ('110000', '강남구'));
      expect(c.summary, '지체장애, 기타(척수손상) · 기타(허리 통증) · 서울특별시 강남구');
    });

    test('현재 위치로 찾은 조건은 위치 없이 저장한다', () {
      expect(nearMe.toJson(), {
        'types': ['visual'],
        'severity': 'mild',
        'need': 'general',
      });
      expect(roundTrip(nearMe).nearMe, isTrue);
      expect(nearMe.summary, '시각장애 · 일반 진료 · 현재 위치');
    });

    test('시·도 전체로 찾은 조건은 시·군·구 없이 저장한다', () {
      const seoul = SearchConditions(
        types: {DisabilityType.hearing},
        severity: Severity.mild,
        need: CareNeed.checkup,
        regionCode: '110000',
        regionName: '서울특별시',
      );
      expect(roundTrip(seoul).districtName, isNull);
      expect(seoul.summary, '청각장애 · 건강검진 · 서울특별시');
    });
  });

  group('FileLastSearchStore', () {
    late Directory dir;
    late FileLastSearchStore store;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('hamkke_search_');
      store = FileLastSearchStore(directory: () async => dir);
    });
    tearDown(() => dir.deleteSync(recursive: true));

    test('저장한 조건을 앱을 다시 켜도 읽고, 지우면 없어진다', () async {
      expect(await store.load(), isNull);

      await store.save(gangnam);
      final reopened = FileLastSearchStore(directory: () async => dir);
      expect((await reopened.load())?.summary, gangnam.summary);

      await reopened.clear();
      expect(await store.load(), isNull);
      expect(dir.listSync(), isEmpty);
    });

    test('파일이 망가졌거나 앱이 모르는 값이면 없는 것으로 본다', () async {
      final file = File('${dir.path}/last_search.json');
      file.writeAsStringSync('{망가진');
      expect(await store.load(), isNull);

      file.writeAsStringSync(jsonEncode({...nearMe.toJson(), 'need': 'teleport'}));
      expect(await store.load(), isNull);
    });
  });
}
