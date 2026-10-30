import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../models/disability.dart';
import '../models/hospital.dart';
import 'intent_features.dart';

/// AI 가 글에서 알아낸 병원 찾기 조건. 글에 없어서 모르는 것은 null 이나 빈 값이다.
class IntentResult {
  const IntentResult({
    this.types = const {},
    this.need,
    this.severity,
    this.child = false,
    this.facilities = const {},
    this.departments = const {},
  });

  final Set<DisabilityType> types;
  final CareNeed? need;
  final Severity? severity;

  /// 진료받을 사람이 어린이·청소년인지.
  final bool child;

  /// 글에 적은 편의시설 (예: '수어 통역 되는 곳').
  final Set<Facility> facilities;

  /// 글에 적은 진료과 (심평원 진료과목 이름, 예: 피부과).
  final Set<String> departments;
}

/// 출력 갈래 하나. [start] 부터 [labels] 수만큼이 이 갈래의 출력이다.
class _Head {
  const _Head(this.name, this.softmax, this.labels, this.start);

  final String name;

  /// 하나만 고르면 softmax, 여러 개를 고르면 sigmoid.
  final bool softmax;
  final List<String> labels;
  final int start;
}

/// 휴대폰 안에서 도는 상황 이해 모델. tools/train_intent.py 가 학습해 assets/ai/intent_model.bin 으로 내보낸다.
///
/// fastText 방식의 얕은 신경망이다: 문장의 특징([intentFeatures])마다 임베딩 벡터(8비트)를 찾아 평균을 내고,
/// 선형 출력 한 층에 갈래마다 sigmoid(여러 개 고르기)나 softmax(하나 고르기)를 씌운다.
/// 계산이 작아 휴대폰에서 1ms 안팎이고, 인터넷을 쓰지 않는다.
///
/// 파일: 'MDAI', 판 번호(uint16), 머리말 길이(uint32), 머리말 JSON, 줄마다의 배율(float32 × 칸 수),
/// 임베딩(int8 × 칸 수 × 차원), 출력 가중치(float32 × 차원 × 출력 수), 출력 치우침(float32 × 출력 수).
/// 숫자는 모두 리틀 엔디언이다.
class IntentModel {
  IntentModel._(
    this.buckets,
    this.dim,
    this.trained,
    List<_Head> heads,
    this._scales,
    this._embeddings,
    this._weights,
    this._bias,
  ) : _heads = {for (final h in heads) h.name: h};

  factory IntentModel.fromBytes(ByteData data) {
    const magic = 'MDAI';
    final bytes = Uint8List.sublistView(data);
    if (bytes.length < 10 || String.fromCharCodes(bytes, 0, 4) != magic) {
      throw const FormatException('메디움 AI 모델 파일이 아니에요.');
    }
    final version = data.getUint16(4, Endian.little);
    if (version != 1) throw FormatException('모르는 모델 판이에요: $version');
    final headerLength = data.getUint32(6, Endian.little);
    final header = jsonDecode(utf8.decode(Uint8List.sublistView(bytes, 10, 10 + headerLength)))
        as Map<String, dynamic>;
    final buckets = header['buckets'] as int;
    final dim = header['dim'] as int;
    final heads = <_Head>[];
    var k = 0;
    for (final h in header['heads'] as List) {
      final head = h as Map<String, dynamic>;
      final labels = (head['labels'] as List).cast<String>();
      heads.add(_Head(head['name'] as String, head['kind'] == 'softmax', labels, k));
      k += labels.length;
    }

    var offset = 10 + headerLength;
    if (bytes.length != offset + buckets * 4 + buckets * dim + dim * k * 4 + k * 4) {
      throw const FormatException('AI 모델 파일의 크기가 머리말과 맞지 않아요.');
    }
    Float64List floats(int count) {
      final out = Float64List(count);
      for (var i = 0; i < count; i++) {
        out[i] = data.getFloat32(offset + i * 4, Endian.little);
      }
      offset += count * 4;
      return out;
    }

    final scales = floats(buckets);
    final embeddings = Int8List.sublistView(data, offset, offset + buckets * dim);
    offset += buckets * dim;
    final weights = floats(dim * k);
    final bias = floats(k);
    return IntentModel._(
        buckets, dim, header['trained'] as String? ?? '', heads, scales, embeddings, weights, bias);
  }

  /// 특징을 보내는 칸 수와 임베딩 차원.
  final int buckets;
  final int dim;

  /// 학습한 날 (예: 2026-10-30).
  final String trained;

  final Map<String, _Head> _heads;
  final Float64List _scales;
  final Int8List _embeddings;
  final Float64List _weights;
  final Float64List _bias;

  /// 출력마다의 확률 (머리말의 갈래 순서대로 이어 붙인 것). 특징이 없는 글이면 치우침만으로 정한다.
  List<double> probabilities(String text) => _probabilities(intentFeatures(text, buckets));

  List<double> _probabilities(List<int> features) {
    final hidden = Float64List(dim);
    for (final f in features) {
      final scale = _scales[f];
      final row = f * dim;
      for (var i = 0; i < dim; i++) {
        hidden[i] += _embeddings[row + i] * scale;
      }
    }
    if (features.isNotEmpty) {
      for (var i = 0; i < dim; i++) {
        hidden[i] /= features.length;
      }
    }

    final k = _bias.length;
    final out = Float64List.fromList(_bias);
    for (var i = 0; i < dim; i++) {
      final h = hidden[i];
      if (h == 0) continue;
      final row = i * k;
      for (var j = 0; j < k; j++) {
        out[j] += h * _weights[row + j];
      }
    }
    for (final head in _heads.values) {
      final end = head.start + head.labels.length;
      if (head.softmax) {
        var top = double.negativeInfinity;
        for (var j = head.start; j < end; j++) {
          top = math.max(top, out[j]);
        }
        var sum = 0.0;
        for (var j = head.start; j < end; j++) {
          out[j] = math.exp(out[j] - top);
          sum += out[j];
        }
        for (var j = head.start; j < end; j++) {
          out[j] /= sum;
        }
      } else {
        for (var j = head.start; j < end; j++) {
          // 아주 큰 음수면 exp 가 무한대가 되어 0 이 된다 (학습 스크립트와 같다).
          out[j] = 1 / (1 + math.exp(-out[j]));
        }
      }
    }
    return out;
  }

  /// [text] 에서 조건을 알아낸다. 여러 개를 고르는 갈래는 확률 0.5 이상을, 하나를 고르는 갈래는 가장 높은 것을 고른다.
  /// 이름이 'none' 인 답(진료·장애 정도를 글에 적지 않음)은 null 로 둔다.
  /// 특징이 하나도 없는 글(ㅋㅋ, 이모티콘만 쓴 글)은 모델을 돌리지 않고 아무 조건도 없다고 본다 (학습 스크립트와 같다).
  IntentResult understand(String text) {
    final features = intentFeatures(text, buckets);
    if (features.isEmpty) return const IntentResult();
    final p = _probabilities(features);

    List<String> chosen(String name) {
      final head = _heads[name];
      if (head == null) return const [];
      return [
        for (final (i, label) in head.labels.indexed)
          if (p[head.start + i] >= 0.5) label,
      ];
    }

    String? top(String name) {
      final head = _heads[name];
      if (head == null) return null;
      var best = 0;
      for (var i = 1; i < head.labels.length; i++) {
        if (p[head.start + i] > p[head.start + best]) best = i;
      }
      return head.labels[best];
    }

    // 모델이 앱보다 새 이름을 알면 모르는 이름은 건너뛴다.
    T? byName<T extends Enum>(Map<String, T> values, String? name) =>
        name == null ? null : values[name];
    final types = DisabilityType.values.asNameMap();
    final facilities = Facility.values.asNameMap();
    final departments = departmentNames.values.toSet();
    return IntentResult(
      types: {for (final t in chosen('types')) ?types[t]},
      need: byName(CareNeed.values.asNameMap(), top('need')),
      severity: byName(Severity.values.asNameMap(), top('severity')),
      child: chosen('child').isNotEmpty,
      facilities: {for (final f in chosen('facilities')) ?facilities[f]},
      departments: {
        for (final d in chosen('departments'))
          if (departments.contains(d)) d,
      },
    );
  }
}

/// 상황 이해 모델을 처음 쓸 때 한 번 읽어 둔다. 실패한 읽기는 기억하지 않아서 다시 부르면 다시 읽는다.
class IntentService {
  IntentService({Future<ByteData> Function()? read}) : _read = read ?? (() => rootBundle.load(asset));

  static const asset = 'assets/ai/intent_model.bin';

  final Future<ByteData> Function() _read;
  Future<IntentModel>? _model;

  Future<IntentModel> load() {
    if (_model case final model?) return model;
    final future = _read().then(IntentModel.fromBytes);
    _model = future;
    future.then<void>((_) {}, onError: (Object _) {
      if (identical(_model, future)) _model = null;
    });
    return future;
  }
}
