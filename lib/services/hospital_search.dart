import 'dart:convert';

/// 병원 이름 검색 색인(search.json)의 한 병원. 고르면 시·도 파일에서 [id] 로 자세한 정보를 읽는다.
class SearchEntry {
  SearchEntry({
    required this.id,
    required this.name,
    required this.region,
    this.district = '',
    this.kind = '',
  })  : _name = _normalize(name),
        _text = _normalize('$name$district$kind');

  final String id;
  final String name;

  /// 시·도 코드 (예: 110000).
  final String region;
  final String district;
  final String kind;

  // 글자를 칠 때마다 6만 곳을 훑으므로 비교용 글은 미리 만들어 둔다.
  final String _name;
  final String _text;
}

/// tools/build_data.py 가 만든 search.json (시·도 코드 → [id, 이름, 시·군·구, 종별]).
List<SearchEntry> parseSearchIndex(String raw) => [
      for (final MapEntry(key: region, value: rows)
          in (jsonDecode(raw) as Map<String, dynamic>).entries)
        for (final row in rows as List)
          SearchEntry(
            id: row[0] as String,
            name: row[1] as String,
            region: region,
            district: row[2] as String,
            kind: row[3] as String,
          ),
    ];

String _normalize(String text) =>
    text.toLowerCase().replaceAll(RegExp(r'[\s()·.,\-]'), '');

/// 검색어의 낱말이 모두 이름·시·군·구·종별에 들어 있는 병원 (예: '강남 정형외과').
/// 이름이 첫 낱말로 시작하는 곳을 먼저, 그다음은 이름 순으로 둔다.
List<SearchEntry> searchHospitals(Iterable<SearchEntry> entries, String query) {
  final words = [
    for (final w in query.split(RegExp(r'\s+')))
      if (_normalize(w) case final n when n.isNotEmpty) n,
  ];
  if (words.isEmpty) return const [];
  final hits = [
    for (final e in entries)
      if (words.every(e._text.contains)) (e, e._name.startsWith(words.first)),
  ]..sort((a, b) => a.$2 == b.$2 ? a.$1.name.compareTo(b.$1.name) : (a.$2 ? -1 : 1));
  return [for (final (e, _) in hits) e];
}
