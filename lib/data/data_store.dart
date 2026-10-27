import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'regions.dart';

/// 앱이 읽을 수 있는 데이터 형식. tools/build_data.py 의 SCHEMA 와 같아야 한다.
const dataSchema = 1;

/// 내려받은 데이터를 두는 폴더. 다시 받으면 되므로 휴대폰 백업에서 뺀다
/// (android/app/src/main/res/xml 의 규칙, ios/Runner/AppDelegate.swift).
const dataDirectoryName = 'hospital_data';

/// 데이터 파일 목록 (meta.json). 파일마다 내용의 sha256 이 있어서 바뀐 파일만 받는다.
class DataManifest {
  const DataManifest({
    required this.schema,
    required this.version,
    required this.info,
    required this.files,
  });

  final int schema;

  /// 판 번호. 빌드한 UTC 시각(ISO 8601)이라 문자열 순서가 곧 시간 순서다.
  final String version;
  final DataInfo info;

  /// 파일 이름(예: hospitals/110000.json) → sha256.
  final Map<String, String> files;

  bool isNewerThan(DataManifest other) => version.compareTo(other.version) > 0;

  factory DataManifest.fromJson(Map<String, dynamic> json) {
    final info = DataInfo.fromJson(json);
    return DataManifest(
      schema: json['schema'] as int? ?? 0,
      version: json['version'] as String? ?? info.generatedAt,
      info: info,
      files: {...?(json['files'] as Map<String, dynamic>?)?.cast<String, String>()},
    );
  }
}

enum UpdateResult {
  /// 새 데이터를 받았다. 다음에 읽을 때부터 쓴다.
  updated,

  /// 이미 최신이다. 이 앱이 읽을 수 없는 새 형식만 올라온 경우도 여기에 든다.
  upToDate,

  /// 네트워크·저장 오류나 내용이 맞지 않아 받지 못했다. 예전 데이터를 그대로 쓴다.
  failed,

  /// 받을 주소가 없어 앱에 든 데이터만 쓴다.
  disabled,
}

/// 병원 데이터 파일을 읽는 곳. 앱에 든 데이터(assets/data)와 새로 받은 데이터 중 새것을 쓴다.
///
/// 받은 파일은 `files/<sha256>.json` 으로 두고, 모두 받은 뒤에 meta.json 을 바꾼다.
/// 받다가 끊기거나 앱이 꺼져도 예전 데이터를 그대로 쓴다.
class DataStore {
  DataStore({
    AssetBundle? bundle,
    Uri? baseUrl,
    Future<Directory> Function()? directory,
    http.Client? client,
  })  : _bundle = bundle ?? rootBundle,
        // 'v1' 처럼 / 없이 끝나면 resolve 가 마지막 경로를 갈아 끼우므로 붙여 둔다.
        _baseUrl = baseUrl == null || baseUrl.path.endsWith('/')
            ? baseUrl
            : baseUrl.replace(path: '${baseUrl.path}/'),
        _directory = directory ?? _defaultDirectory,
        _client = client ?? http.Client();

  final AssetBundle _bundle;

  /// 새 데이터를 올려 둔 주소 (예: https://<계정>.github.io/<저장소>/v1/).
  final Uri? _baseUrl;
  final Future<Directory> Function() _directory;
  final http.Client _client;

  late final Future<void> _ready = _open();
  late DataManifest _bundled;
  late DataManifest _active;

  /// 받은 데이터를 두는 폴더. 주소가 없거나 폴더를 쓸 수 없으면 null.
  Directory? _dir;
  Future<UpdateResult>? _updating;

  /// 지금 쓰는 데이터의 기준일과 출처.
  Future<DataInfo> get info async {
    await _ready;
    return _active.info;
  }

  /// 데이터 파일(예: hospitals/110000.json)의 내용.
  Future<String> read(String name) async {
    await _ready;
    final hash = _active.files[name];
    if (_dir != null && hash != null && hash != _bundled.files[name]) {
      // 큰 파일도 화면이 멈추지 않게 별도 isolate 에서 읽는다.
      return compute(_readFile, _file(hash).path);
    }
    // 데이터는 저장소에서 해석해 두므로 원문까지 캐시하지 않는다.
    return _bundle.loadString('assets/data/$name', cache: false);
  }

  /// 공개 주소에 더 새 데이터가 있으면 바뀐 파일만 받는다. 동시에 불러도 한 번만 받는다.
  Future<UpdateResult> update() =>
      _updating ??= _update().whenComplete(() => _updating = null);

  Future<UpdateResult> _update() async {
    final baseUrl = _baseUrl;
    if (baseUrl == null) return UpdateResult.disabled;
    try {
      await _ready;
      final dir = _dir;
      if (dir == null) return UpdateResult.failed;
      final metaRes = await _client
          .get(baseUrl.resolve('meta.json'))
          .timeout(const Duration(seconds: 30));
      if (metaRes.statusCode != 200) return UpdateResult.failed;
      final remote = DataManifest.fromJson(
          jsonDecode(utf8.decode(metaRes.bodyBytes)) as Map<String, dynamic>);
      if (remote.schema != dataSchema || !remote.isNewerThan(_active)) {
        return UpdateResult.upToDate;
      }
      // 이름과 sha256 은 주소와 파일 경로에 들어가므로 모양부터 확인한다.
      if (!remote.files.containsKey('regions.json') ||
          !remote.files.entries.every((e) =>
              _fileName.hasMatch(e.key) && _sha256Hex.hasMatch(e.value))) {
        return UpdateResult.failed;
      }

      await Directory('${dir.path}/files').create(recursive: true);
      for (final MapEntry(key: name, value: hash) in _toDownload(remote).entries) {
        final file = _file(hash);
        if (await file.exists()) continue;
        // sha256 을 주소에 붙여서 CDN 이 캐시해 둔 예전 파일을 주지 않게 한다.
        final res = await _client
            .get(baseUrl.resolve('$name?v=${hash.substring(0, 16)}'))
            .timeout(const Duration(minutes: 2));
        if (res.statusCode != 200) return UpdateResult.failed;
        final part = File('${file.path}.part');
        await part.writeAsBytes(res.bodyBytes, flush: true);
        if (await compute(_sha256OfFile, part.path) != hash) {
          await part.delete();
          return UpdateResult.failed;
        }
        await part.rename(file.path);
      }

      // 파일을 모두 받은 뒤에 목록을 바꾼다. 같은 폴더 안의 rename 은 한 번에 일어난다.
      final meta = File('${dir.path}/meta.json.part');
      await meta.writeAsBytes(metaRes.bodyBytes, flush: true);
      await meta.rename('${dir.path}/meta.json');
      _active = remote;
      return UpdateResult.updated;
    } catch (e) {
      debugPrint('새 병원 데이터를 받지 못했어요: $e');
      return UpdateResult.failed;
    }
  }

  Future<void> _open() async {
    _bundled = _active = DataManifest.fromJson(jsonDecode(
            await _bundle.loadString('assets/data/meta.json', cache: false))
        as Map<String, dynamic>);
    if (_baseUrl == null) return;
    try {
      final dir = _dir = await _directory();
      final meta = File('${dir.path}/meta.json');
      try {
        final local = DataManifest.fromJson(
            jsonDecode(await meta.readAsString()) as Map<String, dynamic>);
        if (local.schema == dataSchema &&
            local.isNewerThan(_bundled) &&
            await _hasFiles(local)) {
          _active = local;
        }
      } catch (_) {
        // 받은 데이터가 없거나 망가졌으면 앱에 든 데이터를 쓴다.
      }

      // 앱 업데이트로 든 데이터가 더 새로워졌으면 받은 것은 버린다. 지난 판 파일과
      // 받다 만 파일도 지운다. 아직 아무것도 읽기 전이라 읽던 파일이 사라질 일이 없다.
      if (identical(_active, _bundled) && await meta.exists()) await meta.delete();
      final keep = {for (final hash in _toDownload(_active).values) '$hash.json'};
      final files = Directory('${dir.path}/files');
      if (await files.exists()) {
        await for (final f in files.list()) {
          if (f is File && !keep.contains(f.uri.pathSegments.last)) await f.delete();
        }
      }
    } catch (e) {
      // 저장 공간을 쓸 수 없어도 앱에 든 데이터로는 동작한다.
      debugPrint('받은 병원 데이터를 열지 못했어요: $e');
      _dir = null;
      _active = _bundled;
    }
  }

  /// [manifest] 의 파일 중 앱에 든 것과 달라서 받아 두어야 하는 파일 (이름 → sha256).
  Map<String, String> _toDownload(DataManifest manifest) => {
        for (final MapEntry(key: name, value: hash) in manifest.files.entries)
          if (hash != _bundled.files[name]) name: hash,
      };

  Future<bool> _hasFiles(DataManifest manifest) async {
    for (final hash in _toDownload(manifest).values) {
      if (!await _file(hash).exists()) return false;
    }
    return true;
  }

  File _file(String hash) => File('${_dir!.path}/files/$hash.json');
}

final _fileName = RegExp(r'^[a-z0-9_]+(/[a-z0-9_]+)*\.json$');
final _sha256Hex = RegExp(r'^[0-9a-f]{64}$');

Future<Directory> _defaultDirectory() async =>
    Directory('${(await getApplicationSupportDirectory()).path}/$dataDirectoryName');

String _readFile(String path) => File(path).readAsStringSync();

String _sha256OfFile(String path) =>
    sha256.convert(File(path).readAsBytesSync()).toString();
