import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/regions.dart';
import 'package:hamkke_hospital/services/location.dart';

const seoul = Region(
  code: '110000',
  name: '서울특별시',
  lat: 37.5665,
  lng: 126.978,
  districts: [Area('강남구', 37.5172, 127.0473), Area('강서구', 37.5509, 126.8495)],
);
const gyeonggi = Region(
  code: '310000',
  name: '경기도',
  lat: 37.2752,
  lng: 127.0095,
  districts: [Area('부천원미구', 37.5034, 126.7660), Area('수원영통구', 37.2596, 127.0466)],
);
const busan = Region(
  code: '210000',
  name: '부산광역시',
  lat: 35.1796,
  lng: 129.0756,
  districts: [Area('해운대구', 35.1631, 129.1636)],
);

void main() {
  const regions = [seoul, gyeonggi, busan];

  test('가장 가까운 시·군·구가 있는 시·도를 고른다', () {
    final near = regionsNear(regions, 37.5172, 127.0473)!;
    expect(near.region.name, '서울특별시');
    expect(near.nearby, isEmpty);
  });

  test('시·도 경계 근처면 이웃 시·도도 함께 찾는다', () {
    // 서울 강서구와 경기 부천 사이
    final near = regionsNear(regions, 37.53, 126.81)!;
    expect(near.region.name, '서울특별시');
    expect(near.nearby.map((r) => r.name), ['경기도']);
  });

  test('국내에서 너무 멀면(해외 등) 찾지 않는다', () {
    expect(regionsNear(regions, 37.4220, -122.0841), isNull);
  });
}
