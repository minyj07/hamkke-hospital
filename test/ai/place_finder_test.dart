import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/ai/place_finder.dart';
import 'package:hamkke_hospital/data/regions.dart';

// 글에서 지역 이름을 찾는 이름표 검사. 앱에 든 지역 데이터(assets/data/regions.json)를 쓴다.

void main() {
  final regions = [
    for (final r in jsonDecode(File('assets/data/regions.json').readAsStringSync()) as List)
      Region.fromJson(r as Map<String, dynamic>),
  ];
  final finder = PlaceFinder(regions);
  String? place(String text) => finder.find(text)?.label;

  test('시·군·구 이름은 줄이거나 조사를 붙여도 찾는다', () {
    expect(place('강남에서 재활병원 찾아요'), '서울특별시 강남구');
    expect(place('서울 강남구 근처'), '서울특별시 강남구');
    expect(place('서울강남구 치과'), '서울특별시 강남구');
    expect(place('강남구청 앞'), '서울특별시 강남구');
    expect(place('종로에서 가까운 곳'), '서울특별시 종로구');
    expect(place('부산 해운대 사는 엄마'), '부산광역시 해운대구');
    expect(place('부산진구'), '부산광역시 진구');
    expect(place('서귀포시에 있는 병원'), '제주특별자치도 서귀포시');
  });

  test('시 이름과 구 이름을 붙인 곳은 시 이름이나 구 이름으로도 찾는다', () {
    expect(place('수원에 사는 아버지'), '경기도 수원권선구');
    expect(place('수원 영통구'), '경기도 수원영통구');
    expect(place('분당 정형외과'), '경기도 성남분당구');
    expect(place('일산 치과'), '경기도 고양일산동구');
    expect(place('창원 마산'), '경상남도 창원마산합포구');
    expect(place('청주시'), '충청북도 청주상당구');
  });

  test('시·도 이름만 적으면 시·도 전체로 찾는다', () {
    expect(place('서울에서 찾아요'), '서울특별시');
    expect(place('경기도 병원'), '경기도');
    expect(place('충북'), '충청북도');
    expect(place('제주'), '제주특별자치도 제주시');
  });

  test('같은 이름이 여러 곳에 있으면 시·도 이름도 적었을 때만 고른다', () {
    expect(place('중구 내과'), isNull);
    expect(place('서울 중구 내과'), '서울특별시 중구');
    expect(place('대구 중구'), '대구광역시 중구');
    expect(place('고성'), isNull);
    expect(place('강원 고성'), '강원특별자치도 고성군');
    expect(place('광주 재활병원'), '전남광주통합특별시 광주광산구');
    expect(place('광주 남구'), '전남광주통합특별시 광주남구');
    expect(place('경기 광주'), '경기도 광주시');
  });

  test('흔한 낱말과 같은 이름은 지역으로 보지 않는다', () {
    expect(place('점자나 음성 안내 되는 곳'), isNull);
    expect(place('고령 어르신 진료'), isNull);
    expect(place('영양 상담'), isNull);
    expect(place('동작이 느려요'), isNull);
    expect(place('고양이 알레르기'), isNull);
    expect(place('아이가 경기를 해요'), isNull);
    expect(place('근력 강화 운동'), isNull);
    expect(place('음성군 보건소'), '충청북도 음성군');
    expect(place('경기 수원'), '경기도 수원권선구');
  });

  test('지역이 없으면 null', () {
    expect(place(''), isNull);
    expect(place('휠체어 타시는 아버지 당뇨 관리'), isNull);
  });
}
