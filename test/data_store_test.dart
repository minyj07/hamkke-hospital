import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/data_store.dart';
import 'package:hamkke_hospital/data/hospital_repository.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// 메모리에 든 데이터([dataSet])를 assets/data/ 아래 에셋처럼 읽게 한다.
class FakeBundle extends CachingAssetBundle {
  FakeBundle(this.data);

  final Map<String, String> data;

  @override
  Future<ByteData> load(String key) async {
    final text = data[key.replaceFirst('assets/data/', '')];
    if (text == null) throw StateError('없는 에셋: $key');
    return ByteData.sublistView(utf8.encode(text));
  }
}

String hospitals(String name) => jsonEncode([
      {'id': name, 'n': name, 'a': '서울특별시 중구 세종대로 110', 'y': 37.5665, 'x': 126.978, 'dp': ['21']},
    ]);

const regions = '[{"code":"110000","name":"서울특별시","lat":37.5665,"lng":126.978}]';

/// meta.json 과 데이터 파일 묶음. meta.json 의 sha256 은 파일 내용으로 만든다.
Map<String, String> dataSet(String version, Map<String, String> files,
        {int schema = dataSchema}) =>
    {
      ...files,
      'meta.json': jsonEncode({
        'schema': schema,
        'version': version,
        'generatedAt': version.substring(0, 10),
        'sources': ['테스트 자료'],
        'files': {
          for (final MapEntry(:key, :value) in files.entries)
            key: sha256.convert(utf8.encode(value)).toString(),
        },
      }),
    };

final base = Uri.parse('https://example.com/hamkke/v1/');

/// 앱에 든 데이터: 2026-10-08 판.
final bundled = dataSet('2026-10-08', {
  'regions.json': regions,
  'hospitals/110000.json': hospitals('예전서울병원'),
  'hospitals/210000.json': hospitals('부산병원'),
});

/// 새로 올라온 데이터: 서울만 바뀌었다.
final remote = dataSet('2026-10-26T18:00:00Z', {
  'regions.json': regions,
  'hospitals/110000.json': hospitals('새서울병원'),
  'hospitals/210000.json': hospitals('부산병원'),
});

/// [files] 를 올려 둔 서버. 받아 간 파일 이름을 [requested] 에 남긴다.
MockClient server(Map<String, String> files, [List<String>? requested]) =>
    MockClient((request) async {
      final name = request.url.path.substring(base.path.length);
      requested?.add(name);
      final body = files[name];
      return body == null
          ? http.Response('', 404)
          : http.Response.bytes(utf8.encode(body), 200);
    });

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('hamkke_data_'));
  tearDown(() => dir.deleteSync(recursive: true));

  DataStore store({Map<String, String>? app, http.Client? client}) => DataStore(
        bundle: FakeBundle(app ?? bundled),
        baseUrl: base,
        directory: () async => dir,
        client: client ?? server(remote),
      );

  test('주소가 없으면 앱에 든 데이터만 쓴다', () async {
    final s = DataStore(bundle: FakeBundle(bundled));
    expect(await s.update(), UpdateResult.disabled);
    expect(await s.read('hospitals/110000.json'), hospitals('예전서울병원'));
    expect((await s.info).generatedAt, '2026-10-08');
  });

  test('새 데이터가 있으면 바뀐 파일만 받아서 바로 쓴다', () async {
    final requested = <String>[];
    final s = store(client: server(remote, requested));
    expect(await s.read('hospitals/110000.json'), hospitals('예전서울병원'));

    expect(await s.update(), UpdateResult.updated);

    expect(requested, ['meta.json', 'hospitals/110000.json']);
    expect(await s.read('hospitals/110000.json'), hospitals('새서울병원'));
    expect(await s.read('hospitals/210000.json'), hospitals('부산병원'));
    expect((await s.info).generatedAt, '2026-10-26');
  });

  test('받은 데이터는 앱을 다시 켜도 쓰고, 같은 판은 다시 받지 않는다', () async {
    await store().update();

    final requested = <String>[];
    final again = store(client: server(remote, requested));
    expect(await again.read('hospitals/110000.json'), hospitals('새서울병원'));
    expect(await again.update(), UpdateResult.upToDate);
    expect(requested, ['meta.json']);
  });

  test('판이 바뀔 때마다 바뀐 파일만 받고, 다시 켜면 지난 판 파일을 지운다', () async {
    await store().update();
    final next = dataSet('2026-11-02T18:00:00Z', {
      'regions.json': regions,
      'hospitals/110000.json': hospitals('새서울병원'),
      'hospitals/210000.json': hospitals('새부산병원'),
    });
    final requested = <String>[];
    expect(await store(client: server(next, requested)).update(), UpdateResult.updated);
    expect(requested, ['meta.json', 'hospitals/210000.json']);

    final later = dataSet('2026-11-09T18:00:00Z', {
      'regions.json': regions,
      'hospitals/110000.json': hospitals('더새서울병원'),
      'hospitals/210000.json': hospitals('새부산병원'),
    });
    expect(await store(client: server(later)).update(), UpdateResult.updated);
    expect(Directory('${dir.path}/files').listSync(), hasLength(3));

    final reopened = store();
    expect(await reopened.read('hospitals/110000.json'), hospitals('더새서울병원'));
    expect(await reopened.read('hospitals/210000.json'), hospitals('새부산병원'));
    // 지난 판에만 쓰던 '새서울병원' 파일은 지웠다.
    expect(Directory('${dir.path}/files').listSync(), hasLength(2));
  });

  test('받은 내용이 sha256 과 다르면 예전 데이터를 그대로 쓴다', () async {
    final s = store(client: server({...remote, 'hospitals/110000.json': '[]'}));

    expect(await s.update(), UpdateResult.failed);

    expect(await s.read('hospitals/110000.json'), hospitals('예전서울병원'));
    expect(File('${dir.path}/meta.json').existsSync(), isFalse);
    expect(await store().read('hospitals/110000.json'), hospitals('예전서울병원'));
  });

  test('네트워크 오류면 실패를 알리고 예전 데이터를 쓴다', () async {
    final s = store(
      client: MockClient((_) async => throw http.ClientException('연결 끊김')),
    );
    expect(await s.update(), UpdateResult.failed);
    expect(await s.read('hospitals/110000.json'), hospitals('예전서울병원'));
  });

  test('이 앱이 읽을 수 없는 새 형식이면 받지 않는다', () async {
    final newFormat = dataSet(
      '2026-10-26T18:00:00Z',
      {'regions.json': regions, 'hospitals/110000.json': '{}'},
      schema: dataSchema + 1,
    );
    final requested = <String>[];
    final s = store(client: server(newFormat, requested));

    expect(await s.update(), UpdateResult.upToDate);
    expect(requested, ['meta.json']);
    expect(await s.read('hospitals/110000.json'), hospitals('예전서울병원'));
  });

  test('목록의 이름이나 sha256 모양이 이상하면 아무것도 받지 않는다', () async {
    // 이름은 주소에, sha256 은 저장 경로에 들어간다.
    for (final (name, hash) in [
      ('../outside.json', '0' * 64),
      ('hospitals/999999.json', '../../outside'),
    ]) {
      final tampered = jsonDecode(remote['meta.json']!) as Map<String, dynamic>;
      (tampered['files'] as Map<String, dynamic>)[name] = hash;
      final requested = <String>[];
      final s = store(
        client: server({...remote, 'meta.json': jsonEncode(tampered)}, requested),
      );

      expect(await s.update(), UpdateResult.failed, reason: name);
      expect(requested, ['meta.json'], reason: name);
    }
  });

  test('앱을 업데이트해 든 데이터가 더 새로우면 받아 둔 데이터를 지운다', () async {
    await store().update();
    final newerApp = dataSet('2026-11-09', {
      'regions.json': regions,
      'hospitals/110000.json': hospitals('앱에든서울병원'),
      'hospitals/210000.json': hospitals('부산병원'),
    });

    final s = store(app: newerApp);
    expect(await s.read('hospitals/110000.json'), hospitals('앱에든서울병원'));
    expect(File('${dir.path}/meta.json').existsSync(), isFalse);
    expect(Directory('${dir.path}/files').listSync(), isEmpty);
  });

  test('동시에 여러 번 확인해도 한 번만 받는다', () async {
    final requested = <String>[];
    final s = store(client: server(remote, requested));

    expect(await Future.wait([s.update(), s.update()]),
        [UpdateResult.updated, UpdateResult.updated]);
    expect(requested, ['meta.json', 'hospitals/110000.json']);
  });

  test('저장소는 실패한 읽기를 기억하지 않고, 성공한 읽기만 기억한다', () async {
    final files = {...bundled}..remove('hospitals/110000.json');
    final repository = LocalHospitalRepository(DataStore(bundle: FakeBundle(files)));
    await expectLater(repository.loadHospitals('110000'), throwsStateError);

    files['hospitals/110000.json'] = hospitals('예전서울병원');
    expect((await repository.loadHospitals('110000')).single.name, '예전서울병원');

    // 성공한 뒤에는 파일이 없어져도 다시 읽지 않는다.
    files.remove('hospitals/110000.json');
    expect((await repository.loadHospitals('110000')).single.name, '예전서울병원');
  });

  test('저장소는 새 데이터를 받으면 다시 읽는다', () async {
    final repository = LocalHospitalRepository(store());
    expect((await repository.loadHospitals('110000')).single.name, '예전서울병원');

    expect(await repository.update(), UpdateResult.updated);

    expect((await repository.loadHospitals('110000')).single.name, '새서울병원');
    expect((await repository.loadInfo()).generatedAt, '2026-10-26');
    expect((await repository.loadRegions()).single.name, '서울특별시');
  });
}
