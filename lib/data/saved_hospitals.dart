import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/hospital.dart';

/// 즐겨찾기와 최근 본 병원 파일. 어떤 병원에 다니는지는 건강 정보라 휴대폰 백업에서도 뺀다
/// (android/app/src/main/res/xml 의 규칙, ios/Runner/AppDelegate.swift).
const favoritesFileName = 'favorites.json';
const recentFileName = 'recent_hospitals.json';

/// 저장해 둔 병원. 목록을 바로 보여줄 수 있게 이름·종별·주소도 둔다.
/// 자세한 정보는 열 때 시·도 파일에서 [id] 로 다시 읽어서 늘 지금 데이터를 보여준다.
class SavedHospital {
  const SavedHospital({
    required this.id,
    required this.region,
    required this.name,
    this.kind = '',
    this.address = '',
  });

  SavedHospital.of(Hospital h)
      : this(id: h.id, region: h.region, name: h.name, kind: h.kind, address: h.address);

  final String id;
  final String region;
  final String name;
  final String kind;
  final String address;

  Map<String, dynamic> toJson() =>
      {'id': id, 'region': region, 'name': name, 'kind': kind, 'address': address};

  factory SavedHospital.fromJson(Map<String, dynamic> json) => SavedHospital(
        id: json['id'] as String,
        region: json['region'] as String,
        name: json['name'] as String,
        kind: json['kind'] as String? ?? '',
        address: json['address'] as String? ?? '',
      );
}

/// 저장이 안 되어도 앱은 그대로 써야 하므로, 실패하면 기록만 남기고 오류를 던지지 않는다.
abstract class SavedHospitalsStore {
  Future<List<SavedHospital>> load();
  Future<void> save(List<SavedHospital> hospitals);
}

/// 앱 전용 저장 공간(Application Support)의 [fileName] 에 둔다.
class FileSavedHospitalsStore implements SavedHospitalsStore {
  FileSavedHospitalsStore(this.fileName, {Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final String fileName;
  final Future<Directory> Function() _directory;

  Future<File> get _file async => File('${(await _directory()).path}/$fileName');

  @override
  Future<List<SavedHospital>> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return [];
      return [
        for (final h in jsonDecode(await file.readAsString()) as List)
          SavedHospital.fromJson(h as Map<String, dynamic>),
      ];
    } catch (e) {
      debugPrint('$fileName 을 읽지 못했어요: $e');
      return [];
    }
  }

  @override
  Future<void> save(List<SavedHospital> hospitals) async {
    try {
      final file = await _file;
      await file.parent.create(recursive: true);
      final part = File('${file.path}.part');
      await part.writeAsString(jsonEncode([for (final h in hospitals) h.toJson()]), flush: true);
      await part.rename(file.path);
    } catch (e) {
      debugPrint('$fileName 을 저장하지 못했어요: $e');
    }
  }
}

/// 저장해 둔 병원 목록. 여러 화면이 같은 목록을 보도록 앱에 하나만 두고, 바뀌면 알린다.
abstract class SavedHospitals extends ChangeNotifier {
  SavedHospitals(this._store);

  final SavedHospitalsStore _store;
  List<SavedHospital> _items = const [];
  late final Future<void> _ready = _store.load().then((items) {
    _items = items;
    notifyListeners();
  });

  /// 저장해 둔 목록을 읽는다. 여러 번 불러도 한 번만 읽는다.
  Future<void> load() => _ready;

  /// 최근에 넣은 병원이 앞에 온다.
  List<SavedHospital> get items => _items;

  bool contains(String id) => _items.any((h) => h.id == id);

  Future<void> remove(String id) => _update((items) => [
        for (final h in items)
          if (h.id != id) h,
      ]);

  Future<void> clear() => _update((_) => const []);

  /// 목록에 둘 수 있는 만큼만 남긴다.
  List<SavedHospital> _limit(List<SavedHospital> items) => items;

  /// 지운 목록을 되돌린다. 그사이 새로 들어온 병원은 앞에 그대로 둔다.
  Future<void> restore(List<SavedHospital> cleared) => _update((items) => [
        ...items,
        for (final h in cleared)
          if (!items.any((i) => i.id == h.id)) h,
      ]);

  /// 읽기가 끝난 뒤에 바꿔서, 읽기 전에 바꿔도 저장해 둔 목록을 지우지 않는다.
  Future<void> _update(List<SavedHospital> Function(List<SavedHospital> items) change) async {
    await _ready;
    _items = _limit(change(_items));
    notifyListeners();
    await _store.save(_items);
  }
}

/// 즐겨찾기한 병원.
class Favorites extends SavedHospitals {
  Favorites(super.store);

  /// 즐겨찾기에 있으면 빼고, 없으면 맨 앞에 넣는다.
  Future<void> toggle(Hospital h) => _update((items) => items.any((f) => f.id == h.id)
      ? [
          for (final f in items)
            if (f.id != h.id) f,
        ]
      : [SavedHospital.of(h), ...items]);
}

/// 최근에 정보를 본 병원. 최근 [limit] 곳만 둔다.
class RecentHospitals extends SavedHospitals {
  RecentHospitals(super.store);

  static const limit = 20;

  @override
  List<SavedHospital> _limit(List<SavedHospital> items) => items.take(limit).toList();

  /// 맨 앞에 넣는다. 이미 있으면 앞으로 옮긴다.
  Future<void> add(Hospital h) => _update((items) => [
        SavedHospital.of(h),
        for (final r in items)
          if (r.id != h.id) r,
      ]);
}
