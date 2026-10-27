/// 거리 계산의 기준이 되는 지역. 좌표는 그 지역 병원들의 중앙값이다.
class Area {
  const Area(this.name, this.lat, this.lng);

  final String name;
  final double lat;
  final double lng;

  factory Area.fromJson(Map<String, dynamic> json) => Area(
        json['name'] as String,
        (json['lat'] as num).toDouble(),
        (json['lng'] as num).toDouble(),
      );
}

/// 시·도. 병원 데이터는 시·도별 파일로 나뉘어 있다.
class Region extends Area {
  const Region({
    required this.code,
    required String name,
    required double lat,
    required double lng,
    this.districts = const [],
  }) : super(name, lat, lng);

  /// 심평원 시·도 코드 (예: 110000). assets/data/hospitals/<code>.json 과 같다.
  final String code;

  /// 시·군·구.
  final List<Area> districts;

  factory Region.fromJson(Map<String, dynamic> json) => Region(
        code: json['code'] as String,
        name: json['name'] as String,
        lat: (json['lat'] as num).toDouble(),
        lng: (json['lng'] as num).toDouble(),
        districts: [
          for (final d in json['districts'] as List? ?? const [])
            Area.fromJson(d as Map<String, dynamic>),
        ],
      );
}

/// 데이터 기준일과 출처. 공공데이터 이용 조건에 따라 화면에 표시한다.
class DataInfo {
  const DataInfo({required this.generatedAt, required this.sources});

  final String generatedAt;
  final List<String> sources;

  factory DataInfo.fromJson(Map<String, dynamic> json) => DataInfo(
        generatedAt: json['generatedAt'] as String,
        sources: (json['sources'] as List).cast<String>(),
      );
}
