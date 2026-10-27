import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/hospital.dart';

/// 즐겨찾기 파일. 어떤 병원에 다니는지는 건강 정보라 휴대폰 백업에서도 뺀다
/// (android/app/src/main/res/xml 의 규칙, ios/Runner/AppDelegate.swift).
const favoritesFileName = 'favorites.json';

/// 즐겨찾기한 병원. 목록을 바로 보여줄 수 있게 이름·종별·주소도 둔다.
/// 자세한 정보는 열 때 시·도 파일에서 [id] 로 다시 읽어서 늘 지금 데이터를 보여준다.
class FavoriteHospital {
  const FavoriteHospital({
    required this.id,
    required this.region,
    required this.name,
    this.kind = '',
    this.address = '',
  });

  FavoriteHospital.of(Hospital h)
      : this(id: h.id, region: h.region, name: h.name, kind: h.kind, address: h.address);

  final String id;
  final String region;
  final String name;
  final String kind;
  final String address;

  Map<String, dynamic> toJson() =>
      {'id': id, 'region': region, 'name': name, 'kind': kind, 'address': address};

  factory FavoriteHospital.fromJson(Map<String, dynamic> json) => FavoriteHospital(
        id: json['id'] as String,
        region: json['region'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );
}

/// 저장이 안 되어도 앱은 그대로 써야 하므로, 실패하면 기록만 남기고 오류를 던지지 않는다.
abstract class FavoritesStore {
  Future<List<FavoriteHospital>> load();
  Future<void> save(List<FavoriteHospital> favorites);
}

/// 앱 전용 저장 공간(Application Support)의 [favoritesFileName] 에 둔다.
class FileFavoritesStore implements FavoritesStore {
  FileFavoritesStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> get _file async =>
      File('${(await _directory()).path}/$favoritesFileName');

  @override
  Future<List<FavoriteHospital>> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return [];
      return [
        for (final f in jsonDecode(await file.readAsString()) as List)
          FavoriteHospital.fromJson(f as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('즐겨찾기를 읽지 못했어요: $e');
      return [];
    }
  }

  @override
  Future<void> save(List<FavoriteHospital> favorites) async {
    try {
      final file = await _file;
      await file.parent.create(recursive: true);
      final part = File('${file.path}.part');
      await part.writeAsString(jsonEncode([for (final f in favorites) f.toJson()]), flush: true);
      await part.rename(file.path);
    } catch (e) {
      debugPrint('즐겨찾기를 저장하지 못했어요: $e');
    }
  }
}

/// 즐겨찾기 목록. 여러 화면이 같은 목록을 보도록 앱에 하나만 두고, 바뀌면 알린다.
class Favorites extends ChangeNotifier {
  Favorites(this._store);

  final FavoritesStore _store;
  List<FavoriteHospital> _items = const [];
  late final Future<void> _ready = _store.load().then((items) {
    _items = items;
    notifyListeners();
  });

  /// 저장해 둔 목록을 읽는다. 여러 번 불러도 한 번만 읽는다.
  Future<void> load() => _ready;

  /// 최근에 넣은 병원이 앞에 온다.
  List<FavoriteHospital> get items => _items;

  bool contains(String id) => _items.any((f) => f.id == id);

  /// 즐겨찾기에 있으면 빼고, 없으면 맨 앞에 넣는다.
  Future<void> toggle(Hospital h) async {
    await _ready;
    _items = contains(h.id)
        ? [for (final f in _items) if (f.id != h.id) f]
        : [FavoriteHospital.of(h), ..._items];
    notifyListeners();
    await _store.save(_items);
  }

  Future<void> remove(String id) async {
    await _ready;
    _items = [for (final f in _items) if (f.id != id) f];
    notifyListeners();
    await _store.save(_items);
  }
}
