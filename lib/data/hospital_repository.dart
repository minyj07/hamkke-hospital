import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/hospital.dart';
import '../services/hospital_search.dart';
import 'data_store.dart';
import 'regions.dart';

/// 병원 데이터 출처. 앱에는 tools/build_data.py 가 만든 JSON 이 들어 있고,
/// 같은 형식의 새 데이터가 올라오면 내려받아 쓴다.
abstract class HospitalRepository {
  Future<List<Region>> loadRegions();
  Future<List<Hospital>> loadHospitals(String regionCode);
  Future<DataInfo> loadInfo();

  /// 병원 이름 검색 색인 (전국).
  Future<List<SearchEntry>> loadSearchIndex();

  /// [region] 시·도의 [id] 병원. 데이터에서 없어졌으면(문을 닫는 등) null.
  Future<Hospital?> findHospital(String region, String id);

  /// 새 데이터가 있으면 받는다. 받으면 다음에 불러올 때부터 새 데이터를 쓴다.
  Future<UpdateResult> update();
}

/// 기기 안의 데이터(앱에 든 것, 또는 새로 받아 둔 것)를 읽는다. 인터넷이 없어도 동작한다.
class LocalHospitalRepository implements HospitalRepository {
  LocalHospitalRepository([DataStore? store]) : _store = store ?? DataStore();

  final DataStore _store;

  /// 파일 이름 → 해석한 내용. 한 번 읽은 파일은 다시 읽지 않는다.
  final _cache = <String, Future<Object>>{};

  @override
  Future<List<Region>> loadRegions() => _load(
      'regions.json',
      (raw) => [
            for (final r in jsonDecode(raw) as List)
              Region.fromJson(r as Map<String, dynamic>),
          ]);

  @override
  Future<List<Hospital>> loadHospitals(String regionCode) => _load(
      'hospitals/$regionCode.json',
      // 서울은 1만 곳이 넘으므로 화면이 멈추지 않게 별도 isolate 에서 해석한다.
      (raw) => compute(_parseHospitals, (raw, regionCode)));

  @override
  Future<DataInfo> loadInfo() => _store.info;

  @override
  Future<List<SearchEntry>> loadSearchIndex() =>
      _load('search.json', (raw) => compute(parseSearchIndex, raw));

  @override
  Future<Hospital?> findHospital(String region, String id) async =>
      (await loadHospitals(region)).where((h) => h.id == id).firstOrNull;

  @override
  Future<UpdateResult> update() async {
    final result = await _store.update();
    if (result == UpdateResult.updated) {
      // 이미 해석해 둔 예전 데이터를 버리고 다음부터 새 데이터를 읽는다.
      _cache.clear();
    }
    return result;
  }

  /// [name] 파일을 읽어 [parse] 한 결과. 실패한 읽기는 기억하지 않아서 다시 부르면 다시 읽는다.
  Future<T> _load<T extends Object>(String name, FutureOr<T> Function(String raw) parse) {
    if (_cache[name] case final cached?) return cached as Future<T>;
    final future = _store.read(name).then(parse);
    _cache[name] = future;
    future.then<void>((_) {}, onError: (Object _) {
      if (identical(_cache[name], future)) _cache.remove(name);
    });
    return future;
  }
}

List<Hospital> _parseHospitals((String, String) file) {
  final (raw, region) = file;
  return [
    for (final h in jsonDecode(raw) as List)
      Hospital.fromJson(h as Map<String, dynamic>, region: region),
  ];
}
