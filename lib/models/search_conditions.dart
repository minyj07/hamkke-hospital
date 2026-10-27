import '../data/regions.dart';
import 'disability.dart';
import 'user_profile.dart';

/// 첫 화면에서 고른 검색 조건. 마지막으로 찾은 조건은 기기에 저장해 두고 다음에 바로 다시 찾는다.
///
/// 지역은 시·도 코드와 시·군·구 이름으로만 저장하고, 다시 찾을 때 그때의 지역 데이터에서 찾는다.
/// 현재 위치로 찾았으면 위치는 저장하지 않고 다시 찾을 때 새로 얻는다.
class SearchConditions {
  const SearchConditions({
    required this.types,
    required this.severity,
    required this.need,
    this.otherDisability = '',
    this.otherNeed = '',
    this.regionCode,
    this.regionName = '',
    this.districtName,
  });

  final Set<DisabilityType> types;
  final String otherDisability;
  final Severity severity;
  final CareNeed need;
  final String otherNeed;

  /// 시·도 코드. 없으면 현재 위치로 찾는다.
  final String? regionCode;

  /// 화면에 보여줄 시·도 이름.
  final String regionName;

  /// 시·군·구 이름. 없으면 시·도 전체를 기준으로 한다.
  final String? districtName;

  bool get nearMe => regionCode == null;

  /// 화면에 보여줄 조건 (예: 지체장애 · 재활 치료 · 서울특별시 강남구).
  String get summary => [
        disabilityLabel(types, otherDisability),
        careNeedLabel(need, otherNeed),
        nearMe ? '현재 위치' : [regionName, ?districtName].join(' '),
      ].join(' · ');

  UserProfile toProfile({
    required Region region,
    Area? district,
    Area? location,
    List<Region> nearbyRegions = const [],
  }) =>
      UserProfile(
        types: types,
        otherDisability: otherDisability,
        severity: severity,
        need: need,
        otherNeed: otherNeed,
        region: region,
        district: district,
        location: location,
        nearbyRegions: nearbyRegions,
      );

  Map<String, dynamic> toJson() => {
        'types': [for (final t in types) t.name],
        'severity': severity.name,
        'need': need.name,
        if (otherDisability.isNotEmpty) 'otherDisability': otherDisability,
        if (otherNeed.isNotEmpty) 'otherNeed': otherNeed,
        if (regionCode != null)
          'region': {'code': regionCode, 'name': regionName, 'district': ?districtName},
      };

  /// 앱이 모르는 값이 있으면 ArgumentError 를 던진다.
  factory SearchConditions.fromJson(Map<String, dynamic> json) {
    final region = json['region'] as Map<String, dynamic>?;
    return SearchConditions(
      types: {
        for (final t in json['types'] as List) DisabilityType.values.byName(t as String),
      },
      severity: Severity.values.byName(json['severity'] as String),
      need: CareNeed.values.byName(json['need'] as String),
      otherDisability: json['otherDisability'] as String? ?? '',
      otherNeed: json['otherNeed'] as String? ?? '',
      regionCode: region?['code'] as String?,
      regionName: region?['name'] as String? ?? '',
      districtName: region?['district'] as String?,
    );
  }
}
