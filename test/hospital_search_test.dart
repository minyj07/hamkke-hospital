import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/services/hospital_search.dart';

final index = parseSearchIndex(jsonEncode({
  '110000': [
    ['a', '서울대학교병원', '종로구', '상급종합'],
    ['b', '강남 바른정형외과의원', '강남구', '의원'],
    ['c', '바른내과의원', '강남구', '의원'],
  ],
  '210000': [
    ['d', '해운대정형외과의원', '해운대구', '의원'],
  ],
}));

List<String> names(String query) => [for (final e in searchHospitals(index, query)) e.name];

void main() {
  test('색인은 시·도 코드와 함께 읽는다', () {
    expect(index, hasLength(4));
    expect(index.last.region, '210000');
    expect((index.first.district, index.first.kind), ('종로구', '상급종합'));
  });

  test('띄어쓰기를 무시하고 이름의 일부로 찾는다', () {
    expect(names('서울대'), ['서울대학교병원']);
    expect(names('바른정형'), ['강남 바른정형외과의원']);
    expect(names('ㅁㄴㅇ'), isEmpty);
    expect(names('  '), isEmpty);
  });

  test('여러 낱말은 모두 들어 있어야 하고, 시·군·구와 종별로도 찾는다', () {
    expect(names('강남 정형외과'), ['강남 바른정형외과의원']);
    expect(names('해운대 의원'), ['해운대정형외과의원']);
    expect(names('강남 상급종합'), isEmpty);
  });

  test('이름이 검색어로 시작하는 병원을 먼저 둔다', () {
    expect(names('바른'), ['바른내과의원', '강남 바른정형외과의원']);
  });
}
