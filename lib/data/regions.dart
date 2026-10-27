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

/// 땅이 맞닿은 시·도 (심평원 시·도 코드). 맞는 병원이 없을 때 이웃 시·도까지 넓혀 찾는다.
/// 광주는 2026년 전남과 합쳐져 360000 하나다 (tools/build_data.py 의 REGION_MERGES).
const neighborRegions = <String, List<String>>{
  '110000': ['220000', '310000'], // 서울: 인천, 경기
  '210000': ['260000', '380000'], // 부산: 울산, 경남
  '220000': ['110000', '310000'], // 인천: 서울, 경기
  '230000': ['370000', '380000'], // 대구: 경북, 경남
  '250000': ['330000', '340000', '410000'], // 대전: 충북, 충남, 세종
  '260000': ['210000', '370000', '380000'], // 울산: 부산, 경북, 경남
  '310000': ['110000', '220000', '320000', '330000', '340000'], // 경기: 서울, 인천, 강원, 충북, 충남
  '320000': ['310000', '330000', '370000'], // 강원: 경기, 충북, 경북
  '330000': ['250000', '310000', '320000', '340000', '350000', '370000', '410000'], // 충북
  '340000': ['250000', '310000', '330000', '350000', '410000'], // 충남
  '350000': ['330000', '340000', '360000', '370000', '380000'], // 전북
  '360000': ['350000', '380000'], // 전남·광주: 전북, 경남
  '370000': ['230000', '260000', '320000', '330000', '350000', '380000'], // 경북
  '380000': ['210000', '230000', '260000', '350000', '360000', '370000'], // 경남
  '390000': [], // 제주
  '410000': ['250000', '330000', '340000'], // 세종: 대전, 충북, 충남
};

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
