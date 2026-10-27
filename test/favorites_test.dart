import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/favorites.dart';
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

void main() {
  late Directory dir;
  late FileFavoritesStore store;

  setUp(() {
    dir = Directory.systemTemp.createTempSync('hamkke_favorites_');
    store = FileFavoritesStore(directory: () async => dir);
  });
  tearDown(() => dir.deleteSync(recursive: true));

  test('넣고 빼면 알리고, 앱을 다시 켜도 남아 있다', () async {
    final favorites = Favorites(store);
    var notified = 0;
    favorites.addListener(() => notified++);
    await favorites.load();
    expect(favorites.items, isEmpty);

    await favorites.toggle(clinic);
    await favorites.toggle(dentist);
    expect(favorites.contains('h1'), isTrue);
    // 최근에 넣은 병원이 앞에 온다.
    expect([for (final f in favorites.items) f.id], ['h2', 'h1']);

    final reopened = Favorites(FileFavoritesStore(directory: () async => dir));
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
    await store.save([FavoriteHospital.of(dentist)]);
    final favorites = Favorites(store);
    await favorites.toggle(clinic);
    expect([for (final f in favorites.items) f.id], ['h1', 'h2']);
  });
}
