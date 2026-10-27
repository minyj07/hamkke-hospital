import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/saved_hospitals.dart';
import 'package:hamkke_hospital/models/hospital.dart';

const clinic = Hospital(
  id: 'h1',
  name: '강남재활의학과의원',
  region: '110000',
  kind: '의원',
  address: '서울특별시 강남구 테헤란로 1',
  lat: 37.5,
  lng: 127.0,
);

const dentist = Hospital(
  id: 'h2',
  name: '강남치과의원',
  region: '110000',
  address: '서울특별시 강남구 테헤란로 2',
  lat: 37.5,
  lng: 127.0,
);

Hospital numbered(int i) =>
    Hospital(id: 'n$i', name: '$i번의원', region: '110000', address: '', lat: 37.5, lng: 127.0);

List<String> ids(SavedHospitals list) => [for (final h in list.items) h.id];

void main() {
  late Directory dir;
  late FileSavedHospitalsStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hamkke_saved_');
    store = FileSavedHospitalsStore(favoritesFileName, directory: () async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('즐겨찾기: 넣고 빼면 알리고, 앱을 다시 켜도 남아 있다', () async {
    final favorites = Favorites(store);
    var notified = 0;
    favorites.addListener(() => notified++);
    await favorites.load();
    expect(favorites.items, isEmpty);

    await favorites.toggle(clinic);
    await favorites.toggle(dentist);
    expect(favorites.contains('h1'), isTrue);
    // 최근에 넣은 병원이 앞에 온다.
    expect(ids(favorites), ['h2', 'h1']);

    final reopened =
        Favorites(FileSavedHospitalsStore(favoritesFileName, directory: () async => dir));
    await reopened.load();
    expect([for (final f in reopened.items) f.name], ['강남치과의원', '강남재활의학과의원']);
    expect(reopened.items.last.region, '110000');
    expect(reopened.items.last.address, '서울특별시 강남구 테헤란로 1');

    await favorites.toggle(clinic);
    await favorites.remove('h2');
    expect(favorites.items, isEmpty);
    expect(await store.load(), isEmpty);
    expect(notified, greaterThanOrEqualTo(5));
  });

  test('파일이 망가졌으면 빈 목록으로 본다', () async {
    File('${dir.path}/$favoritesFileName').writeAsStringSync('[망가진');
    expect(await store.load(), isEmpty);
  });

  test('읽기 전에 넣어도 저장해 둔 목록을 지우지 않는다', () async {
    await store.save([SavedHospital.of(dentist)]);
    final favorites = Favorites(store);
    await favorites.toggle(clinic);
    expect(ids(favorites), ['h1', 'h2']);
  });

  test('최근 본 병원: 다시 보면 앞으로 옮기고, 20곳까지만 남긴다', () async {
    final recent =
        RecentHospitals(FileSavedHospitalsStore(recentFileName, directory: () async => dir));
    for (var i = 0; i < 25; i++) {
      await recent.add(numbered(i));
    }
    expect(recent.items, hasLength(RecentHospitals.limit));
    expect(ids(recent).first, 'n24');
    expect(ids(recent), isNot(contains('n4')));

    await recent.add(numbered(10));
    expect(ids(recent).first, 'n10');
    expect(ids(recent).where((id) => id == 'n10'), hasLength(1));
    // 즐겨찾기와 다른 파일에 둔다.
    expect(File('${dir.path}/$recentFileName').existsSync(), isTrue);
    expect(File('${dir.path}/$favoritesFileName').existsSync(), isFalse);
  });

  test('지운 기록을 되돌리면 그사이 본 병원은 앞에 두고 예전 기록을 뒤에 붙인다', () async {
    final recent = RecentHospitals(store);
    await recent.add(clinic);
    await recent.add(dentist);
    final cleared = recent.items;

    await recent.clear();
    expect(recent.items, isEmpty);
    await recent.add(numbered(1));
    await recent.restore(cleared);
    expect(ids(recent), ['n1', 'h2', 'h1']);
  });
}
