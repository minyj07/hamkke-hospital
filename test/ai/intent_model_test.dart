import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/ai/intent_features.dart';
import 'package:hamkke_hospital/ai/intent_model.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';

// 앱의 AI 계산이 학습 스크립트(tools/train_intent.py)와 같은지, 파이썬이 만든 정답 파일
// (test/ai/intent_golden.json)로 검사한다. 모델을 다시 학습하면 정답 파일도 새로 만들어진다.

const _modelPath = 'assets/ai/intent_model.bin';

ByteData _modelBytes() => ByteData.sublistView(File(_modelPath).readAsBytesSync());

void main() {
  final golden = jsonDecode(File('test/ai/intent_golden.json').readAsStringSync()) as Map<String, dynamic>;
  final cases = (golden['cases'] as List).cast<Map<String, dynamic>>();
  final model = IntentModel.fromBytes(_modelBytes());

  test('정규화는 소문자·한글·숫자만 남긴다', () {
    expect(normalizeIntentText('  ADHD 아이,  소아과!! '), 'adhd 아이 소아과');
    expect(normalizeIntentText('ㅠㅠ 😀'), '');
    expect(intentFeatures(''), isEmpty);
  });

  test('FNV-1a 는 32비트다', () {
    expect(fnv1a(''), 0x811C9DC5);
    expect(fnv1a('a'), 0xE40C292C);
  });

  test('특징 번호가 파이썬과 같다', () {
    for (final c in cases) {
      expect(intentFeatures(c['text'] as String), c['features'], reason: c['text'] as String);
    }
  });

  test('확률이 파이썬과 같다', () {
    expect(cases, hasLength(greaterThan(20)));
    for (final c in cases) {
      final expected = (c['probabilities'] as List).cast<num>();
      final actual = model.probabilities(c['text'] as String);
      expect(actual, hasLength(expected.length));
      for (var i = 0; i < actual.length; i++) {
        expect(actual[i], closeTo(expected[i], 1e-6), reason: '"${c['text']}"의 $i번째 출력');
      }
    }
  });

  test('알아낸 조건이 파이썬과 같다', () {
    for (final c in cases) {
      final text = c['text'] as String;
      final d = c['decoded'] as Map<String, dynamic>;
      final r = model.understand(text);
      expect({for (final t in r.types) t.name}, (d['types'] as List).toSet(), reason: text);
      expect(r.need?.name ?? 'none', d['need'], reason: text);
      expect(r.severity?.name ?? 'none', d['severity'], reason: text);
      expect(r.child, d['child'], reason: text);
      expect({for (final f in r.facilities) f.name}, (d['facilities'] as List).toSet(), reason: text);
      expect(r.departments, (d['departments'] as List).toSet(), reason: text);
    }
  });

  test('말하듯 적은 문장에서 조건을 알아낸다', () {
    final r = model.understand('아버지가 휠체어 타시는데 당뇨 때문에 꾸준히 다닐 병원 찾아요');
    expect(r.types, {DisabilityType.physical});
    expect(r.need, CareNeed.chronic);
    expect(r.severity, isNull);
    expect(r.facilities, {Facility.wheelchair});
    expect(model.trained, isNotEmpty);
  });

  test('모델 파일이 아니거나 잘렸으면 읽지 않는다', () {
    expect(() => IntentModel.fromBytes(ByteData(16)), throwsFormatException);
    final raw = File(_modelPath).readAsBytesSync();
    expect(() => IntentModel.fromBytes(ByteData.sublistView(raw, 0, raw.length - 4)), throwsFormatException);
  });

  test('모델 읽기에 실패하면 다음에 다시 읽고, 읽은 모델은 다시 쓴다', () async {
    var reads = 0;
    final service = IntentService(read: () async {
      if (++reads == 1) throw StateError('읽기 실패');
      return _modelBytes();
    });
    await expectLater(service.load(), throwsStateError);
    final loaded = await service.load();
    expect(await service.load(), same(loaded));
    expect(reads, 2);
  });
}
