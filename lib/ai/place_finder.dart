import 'dart:math' as math;

import '../data/regions.dart';
import 'intent_features.dart';

/// 글에서 찾은 지역.
class PlaceMatch {
  const PlaceMatch(this.region, [this.district]);

  final Region region;

  /// 시·군·구. 시·도 이름만 적었으면 null.
  final Area? district;

  /// 화면에 보여 줄 이름 (예: 서울특별시 강남구).
  String get label => [region.name, ?district?.name].join(' ');
}

/// 시·도 코드 → 줄여 부르는 이름. 광주는 2026년 전남과 합쳐졌고, '광주'는 그 안의 구들로 찾는다.
const _regionShortNames = <String, List<String>>{
  '110000': ['서울'],
  '210000': ['부산'],
  '220000': ['인천'],
  '230000': ['대구'],
  '250000': ['대전'],
  '260000': ['울산'],
  '320000': ['강원'],
  '330000': ['충북', '충청북도'],
  '340000': ['충남', '충청남도'],
  '350000': ['전북', '전라북도'],
  '360000': ['전남', '전라남도'],
  '370000': ['경북', '경상북도'],
  '380000': ['경남', '경상남도'],
  '390000': ['제주'],
  '410000': ['세종'],
};

/// 혼자서는 지역으로 보지 않는 줄임말. '경기'는 경련(경기를 해요)일 수 있어서 '경기 수원'처럼
/// 그 시·도의 다른 이름과 함께 적었을 때만 센다.
const _weakRegionNames = <String, String>{'경기': '310000'};

/// 흔한 낱말과 같아서 '구·군·시'를 떼고는 찾지 않는 이름 (음성 안내, 고령, 영양, 근력 강화 등).
/// '음성군'처럼 끝까지 적으면 찾는다.
const _commonWords = {
  '음성', '고령', '영양', '동작', '수영', '강화', '상주', '공주', '장수', '영광',
  '보은', '진도', '예산', '연수', '기장', '인제', '사상', '부여', '남동', '달성',
};

/// 지역 이름 뒤에 붙는 말 (강남에서, 수원 근처). 긴 것부터 뗀다.
const _placeEndings = ['에서는', '에서도', '에서', '에는', '에도', '으로', '근처', '주변', '지역', '쪽에', '쪽', '에', '로'];

/// '강남구는', '수원시가'처럼 구·군·시·도로 끝나는 이름 뒤에서만 떼는 조사 ('고양이'의 '이'는 떼지 않는다).
const _particles = ['은', '는', '이', '가', '을', '를', '의', '도', '와', '과', '랑'];

/// 이름이 얼마나 분명한지. 같은 낱말이 여러 지역에 맞으면 더 분명한 쪽을 고른다.
enum _Strength { weak, stem, short, full }

class _Hit {
  const _Hit(this.region, this.district, this.strength, {this.group = false});

  final Region region;
  final Area? district;
  final _Strength strength;

  /// 여러 구를 묶어 부르는 이름(수원, 일산)이라 그중 첫 구를 기준으로 삼은 것.
  final bool group;
}

/// 글에 적은 지역 이름(시·도, 시·군·구)을 지역 목록에서 찾는다. AI 모델이 아니라 지역 이름표로 찾는다.
///
/// '강남', '수원에', '부산 해운대', '서울강남구'처럼 줄이거나 붙여 써도 찾는다. 같은 이름이 여러 시·도에 있으면
/// (중구, 고성 등) 시·도 이름도 함께 적었을 때만 고른다.
class PlaceFinder {
  PlaceFinder(List<Region> regions) {
    for (final r in regions) {
      _add(r.name, _Hit(r, null, _Strength.full));
      for (final short in _regionShortNames[r.code] ?? const <String>[]) {
        for (final name in [short, '$short시', '$short도']) {
          _add(name, _Hit(r, null, _Strength.short));
        }
      }
      for (final MapEntry(key: name, value: code) in _weakRegionNames.entries) {
        if (code == r.code) _add(name, _Hit(r, null, _Strength.weak));
      }
      for (final d in r.districts) {
        _addDistrict(r, d);
      }
    }
    _regionNames.sort((a, b) => b.$1.length.compareTo(a.$1.length));
  }

  /// 이름 → 맞는 지역들.
  final _names = <String, List<_Hit>>{};

  /// 글 앞부분이 같으면 찾는 시·군·구 이름 ('강남구청'의 강남구). 세 글자 이상만 둔다.
  final _prefixNames = <String, List<_Hit>>{};

  /// 붙여 쓴 글('서울강남구')의 앞에서 떼어 낼 시·도 이름. 긴 것부터.
  final _regionNames = <(String, _Hit)>[];

  void _add(String name, _Hit hit) {
    (_names[name] ??= []).add(hit);
    if (hit.district == null && hit.strength != _Strength.weak) _regionNames.add((name, hit));
  }

  void _addDistrict(Region r, Area d) {
    final name = d.name;
    _add(name, _Hit(r, d, _Strength.full));
    if (name.length >= 3) (_prefixNames[name] ??= []).add(_Hit(r, d, _Strength.full));
    _addStem(name, _Hit(r, d, _Strength.stem));

    // '수원영통구'처럼 시 이름과 구 이름을 붙인 곳: 수원·수원시는 그 시의 첫 구로, 영통구·영통은 그 구로 찾는다.
    final city = _cityOf(name, r.districts);
    if (city == null) return;
    final gu = name.substring(city.length);
    _add(gu, _Hit(r, d, _Strength.full));
    _addStem(gu, _Hit(r, d, _Strength.stem));
    final first = r.districts.firstWhere((other) => other.name.startsWith(city));
    if (identical(first, d)) {
      _add(city, _Hit(r, d, _Strength.short, group: true));
      _add('$city시', _Hit(r, d, _Strength.full, group: true));
    }
    // '고양일산동구·고양일산서구'의 일산처럼 같은 시 안의 구들이 앞 글자를 나눠 쓰면 그 이름으로도 찾는다.
    for (var len = 2; len <= gu.length - 2; len++) {
      final part = gu.substring(0, len);
      final siblings = [
        for (final other in r.districts)
          if (other.name.startsWith(city + part)) other,
      ];
      if (siblings.length < 2) continue;
      if (identical(siblings.first, d)) _add(part, _Hit(r, d, _Strength.stem, group: true));
      break;
    }
  }

  /// '강남구'의 강남처럼 구·군·시를 뗀 이름. 두 글자보다 짧거나 흔한 낱말이면 넣지 않는다.
  void _addStem(String name, _Hit hit) {
    if (!'구군시'.contains(name[name.length - 1])) return;
    final stem = name.substring(0, name.length - 1);
    if (stem.length >= 2 && !_commonWords.contains(stem)) _add(stem, hit);
  }

  /// '수원영통구'처럼 시 이름 + 구 이름이면 시 이름(수원). 같은 시의 구가 둘 이상일 때만 그렇게 본다.
  static String? _cityOf(String name, List<Area> districts) {
    if (!name.endsWith('구')) return null;
    for (var len = 2; len <= name.length - 2; len++) {
      final city = name.substring(0, len);
      final sibling = districts.any((d) =>
          d.name != name && d.name.startsWith(city) && d.name.endsWith('구') && d.name.length - len >= 2);
      if (sibling) return city;
    }
    return null;
  }

  /// [word] 와 거기서 지역 이름 뒤에 붙는 말을 뗀 것들.
  static Iterable<String> _forms(String word) sync* {
    yield word;
    for (final ending in _placeEndings) {
      if (word.length - ending.length >= 2 && word.endsWith(ending)) {
        yield word.substring(0, word.length - ending.length);
        break;
      }
    }
    for (final p in _particles) {
      if (word.length - p.length < 2 || !word.endsWith(p)) continue;
      final base = word.substring(0, word.length - p.length);
      if ('구군시도'.contains(base[base.length - 1])) yield base;
    }
  }

  void _match(String word, void Function(_Hit) found, {bool peel = true}) {
    for (final form in _forms(word)) {
      _names[form]?.forEach(found);
    }
    for (final MapEntry(key: name, value: hits) in _prefixNames.entries) {
      if (word.length > name.length && word.startsWith(name)) hits.forEach(found);
    }
    if (!peel) return;
    for (final (name, hit) in _regionNames) {
      if (word.length > name.length && word.startsWith(name)) {
        found(hit);
        _match(word.substring(name.length), found, peel: false);
        break;
      }
    }
  }

  /// [text] 에 적은 지역. 없거나 어느 곳인지 정할 수 없으면 null.
  ///
  /// 지역마다 그 지역에 맞는 낱말 수를 세어 가장 많은 곳을 고르고, 같으면 더 분명한 이름이 맞은 곳을 고른다.
  /// 그래도 같으면(중구처럼 여러 곳에 있는 이름만 적었으면) 고르지 않는다.
  PlaceMatch? find(String text) {
    final normalized = normalizeIntentText(text);
    if (normalized.isEmpty) return null;
    // 시·도 코드 → 낱말 번호 → 그 낱말로 맞은 이름들.
    final byRegion = <String, Map<int, List<_Hit>>>{};
    for (final (i, word) in normalized.split(' ').indexed) {
      _match(word, (hit) => ((byRegion[hit.region.code] ??= {})[i] ??= []).add(hit));
    }

    (int, int) score(Map<int, List<_Hit>> words) => (
          words.length,
          words.values.expand((hits) => hits).map((h) => h.strength.index).reduce(math.max),
        );
    final ranked = byRegion.entries.map((e) => (e.value, score(e.value))).toList()
      ..sort((a, b) => a.$2.$1 != b.$2.$1 ? b.$2.$1 - a.$2.$1 : b.$2.$2 - a.$2.$2);
    if (ranked.isEmpty) return null;
    final (words, best) = ranked.first;
    if (best.$2 == _Strength.weak.index) return null;
    if (ranked.length > 1 && ranked[1].$2 == best) return null;

    final districts = [
      for (final MapEntry(key: i, value: hits) in words.entries)
        for (final h in hits)
          if (h.district != null) (i, h),
    ]..sort((a, b) {
        if (a.$2.strength != b.$2.strength) return b.$2.strength.index - a.$2.strength.index;
        if (a.$2.group != b.$2.group) return a.$2.group ? 1 : -1;
        return a.$1 - b.$1;
      });
    final region = words.values.first.first.region;
    return PlaceMatch(region, districts.firstOrNull?.$2.district);
  }
}
