import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../models/search_conditions.dart';

/// 마지막으로 찾은 조건이 든 파일. 장애 정보가 들어 있으므로 휴대폰 백업에서도 뺀다
/// (android/app/src/main/res/xml 의 규칙, ios/Runner/AppDelegate.swift).
const lastSearchFileName = 'last_search.json';

/// 마지막으로 찾은 조건. 장애 정보가 들어 있으므로 기기에만 두고 앱이 밖으로 보내지 않는다.
/// 저장이 안 되어도 찾기는 그대로 되어야 하므로, 실패하면 기록만 남기고 오류를 던지지 않는다.
abstract class LastSearchStore {
  Future<SearchConditions?> load();
  Future<void> save(SearchConditions conditions);
  Future<void> clear();
}

/// 앱 전용 저장 공간(Application Support)의 [lastSearchFileName] 에 둔다.
class FileLastSearchStore implements LastSearchStore {
  FileLastSearchStore({Future<Directory> Function()? directory})
      : _directory = directory ?? getApplicationSupportDirectory;

  final Future<Directory> Function() _directory;

  Future<File> get _file async =>
      File('${(await _directory()).path}/$lastSearchFileName');

  @override
  Future<SearchConditions?> load() async {
    try {
      final file = await _file;
      if (!await file.exists()) return null;
      return SearchConditions.fromJson(
          jsonDecode(await file.readAsString()) as Map<String, dynamic>);
    } catch (e) {
      // 망가졌거나 앱 업데이트로 모르는 값이 들어 있으면 없는 것으로 본다.
      debugPrint('지난번 검색 조건을 읽지 못했어요: $e');
      return null;
    }
  }

  @override
  Future<void> save(SearchConditions conditions) async {
    try {
      final file = await _file;
      await file.parent.create(recursive: true);
      final part = File('${file.path}.part');
      await part.writeAsString(jsonEncode(conditions.toJson()), flush: true);
      await part.rename(file.path);
    } catch (e) {
      debugPrint('검색 조건을 저장하지 못했어요: $e');
    }
  }

  @override
  Future<void> clear() async {
    try {
      final file = await _file;
      if (await file.exists()) await file.delete();
    } catch (e) {
      debugPrint('검색 조건을 지우지 못했어요: $e');
    }
  }
}

/// 지난번 조건. 홈과 병원 찾기 화면이 같은 조건을 보도록 앱에 하나만 두고, 바뀌면 알린다.
class LastSearch extends ChangeNotifier {
  LastSearch(this._store);

  final LastSearchStore _store;
  SearchConditions? _value;
  late final Future<void> _ready = _store.load().then((value) {
    _value = value;
    notifyListeners();
  });

  /// 저장해 둔 조건을 읽는다. 여러 번 불러도 한 번만 읽는다.
  Future<void> load() => _ready;

  SearchConditions? get value => _value;

  Future<void> save(SearchConditions conditions) async {
    await _ready;
    _value = conditions;
    notifyListeners();
    await _store.save(conditions);
  }

  Future<void> clear() async {
    await _ready;
    _value = null;
    notifyListeners();
    await _store.clear();
  }
}
