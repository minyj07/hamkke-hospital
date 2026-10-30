import 'dart:convert';

// 말하듯 적은 문장을 AI 모델의 입력(특징 번호 목록)으로 바꾼다.
//
// tools/intent_features.py 와 글자 하나까지 똑같이 계산해야 한다. 바꾸면 둘 다 바꾸고 모델을 다시 학습한다
// (python tools/train_intent.py). test/ai/intent_model_test.dart 가 파이썬이 만든 정답과 같은지 검사한다.
//
// 특징은 fastText 방식이다: 낱말, 낱말 안의 글자 1~3개 묶음, 이웃한 두 낱말.
// 문자열을 FNV-1a 32비트로 해시해 [intentBuckets] 칸 중 하나로 보낸다.

const intentBuckets = 1 << 14;

/// 한글 음절, 영문 소문자, 숫자만 남기고 나머지는 띄어쓰기로 본다.
final _drop = RegExp(r'[^0-9a-z가-힣]+');

String normalizeIntentText(String text) => text
    .toLowerCase()
    .replaceAll(_drop, ' ')
    .split(' ')
    .where((w) => w.isNotEmpty)
    .join(' ');

/// FNV-1a 32비트 해시 (UTF-8 바이트로 센다).
int fnv1a(String text) {
  var h = 0x811C9DC5;
  for (final byte in utf8.encode(text)) {
    h ^= byte;
    h = (h * 0x01000193) & 0xFFFFFFFF;
  }
  return h;
}

List<String> intentFeatureStrings(String text) {
  final normalized = normalizeIntentText(text);
  final words = normalized.isEmpty ? const <String>[] : normalized.split(' ');
  final feats = <String>[];
  for (final w in words) {
    feats.add('w:$w');
    final padded = '<$w>';
    for (var n = 1; n <= 3; n++) {
      for (var i = 0; i + n <= padded.length; i++) {
        final gram = padded.substring(i, i + n);
        if (gram == '<' || gram == '>') continue;
        feats.add('c$n:$gram');
      }
    }
  }
  for (var i = 0; i + 1 < words.length; i++) {
    feats.add('b:${words[i]}_${words[i + 1]}');
  }
  return feats;
}

List<int> intentFeatures(String text, [int buckets = intentBuckets]) =>
    [for (final f in intentFeatureStrings(text)) fnv1a(f) % buckets];
