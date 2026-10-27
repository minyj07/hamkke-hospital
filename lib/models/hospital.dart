/// 장애인 의료 지원 사업 지정 기관 종류. 출처는 data/designated_sources.md.
enum InstitutionCategory {
  rehabHospital('권역재활병원·국립재활원'),
  rehabDesignated('보건복지부 지정 재활의료기관'),
  childRehab('공공어린이재활병원·센터'),
  friendlyCheckup('장애친화 건강검진기관'),
  dentalCenter('장애인구강진료센터'),
  primaryCare('장애인 건강주치의'),
  dentalPrimaryCare('장애인 치과 주치의'),
  friendlyObgyn('장애친화 산부인과'),
  mentalHealthCenter('국립 정신건강 전문기관');

  const InstitutionCategory(this.label);
  final String label;
}

/// 병원 편의시설·지원 서비스.
enum Facility {
  wheelchair('휠체어 접근'),
  parking('장애인 주차'),
  toilet('장애인 화장실'),
  lift('이동식 리프트·전동 검사대'),
  signLanguage('수어 통역'),
  braille('점자·음성 안내'),
  sedation('진정·수면 치료'),
  quietRoom('조용한 대기 공간'),
  dialysis('인공신장실');

  const Facility(this.label);
  final String label;
}

/// 병원에 편의시설이 있는지. 조사한 자료가 없으면 [unknown] 이고, 없다고 하지 않는다.
enum FacilityStatus {
  present('있음'),
  absent('없음'),
  unknown('정보 없음');

  const FacilityStatus(this.label);
  final String label;
}

/// 심평원 진료과목코드 → 이름. tools/build_data.py 의 DEPARTMENTS 와 같아야 한다.
const departmentNames = <String, String>{
  '01': '내과',
  '02': '신경과',
  '03': '정신건강의학과',
  '04': '외과',
  '05': '정형외과',
  '06': '신경외과',
  '08': '성형외과',
  '09': '마취통증의학과',
  '10': '산부인과',
  '11': '소아청소년과',
  '12': '안과',
  '13': '이비인후과',
  '14': '피부과',
  '15': '비뇨의학과',
  '21': '재활의학과',
  '23': '가정의학과',
  '49': '치과',
};

// 새로 받은 데이터에 이 앱이 모르는 종류가 있어도 건너뛰고 읽도록 이름으로 찾는다.
final _categoryByName = InstitutionCategory.values.asNameMap();
final _facilityByName = Facility.values.asNameMap();

class Hospital {
  const Hospital({
    required this.id,
    required this.name,
    required this.address,
    required this.lat,
    required this.lng,
    this.region = '',
    this.kind = '',
    this.district = '',
    this.phone = '',
    this.doctors = 0,
    this.specialists = 0,
    this.openedYear,
    this.homepage = '',
    this.departments = const {},
    this.categories = const {},
    this.facilities = const {},
    this.absentFacilities = const {},
    this.notes = const [],
  });

  final String id;
  final String name;

  /// 시·도 코드 (예: 110000). 시·도 파일을 읽을 때 정한다.
  final String region;

  /// 종별 (예: 의원, 종합병원, 치과의원).
  final String kind;
  final String address;

  /// 시·군·구 (예: 강남구).
  final String district;
  final String phone;
  final double lat;
  final double lng;

  /// 의사 수와 그중 전문의 수 (의과·치과·한의 합). 0 이면 정보가 없다.
  final int doctors;
  final int specialists;

  /// 개원한 해. 정보가 없으면 null.
  final int? openedYear;

  /// 홈페이지 주소. 없으면 빈 글.
  final String homepage;

  /// 진료과목 이름 (예: 재활의학과).
  final Set<String> departments;
  final Set<InstitutionCategory> categories;

  /// 있다고 확인된 편의시설.
  final Set<Facility> facilities;

  /// 조사해서 없다고 확인된 편의시설. [facilities] 에도 여기에도 없으면 정보가 없는 것이다.
  final Set<Facility> absentFacilities;

  /// 지정 현황 등 화면에 그대로 보여줄 설명 (예: 장애인 건강주치의 (주장애관리)).
  final List<String> notes;

  FacilityStatus facilityStatus(Facility f) => facilities.contains(f)
      ? FacilityStatus.present
      : absentFacilities.contains(f)
          ? FacilityStatus.absent
          : FacilityStatus.unknown;

  /// 편의시설을 하나라도 조사한 병원인지.
  bool get hasFacilityInfo => facilities.isNotEmpty || absentFacilities.isNotEmpty;

  /// tools/build_data.py 가 만든 압축 형식(짧은 키)을 읽는다. [region] 은 읽은 시·도 파일의 코드.
  factory Hospital.fromJson(Map<String, dynamic> json, {String region = ''}) {
    List<String> strings(String key) => [...?(json[key] as List?)?.cast<String>()];
    return Hospital(
      id: json['id'] as String,
      name: json['n'] as String,
      region: region,
      kind: json['k'] as String? ?? '',
      address: json['a'] as String,
      phone: json['p'] as String? ?? '',
      district: json['d'] as String? ?? '',
      lat: (json['y'] as num).toDouble(),
      lng: (json['x'] as num).toDouble(),
      doctors: json['dr'] as int? ?? 0,
      specialists: json['sd'] as int? ?? 0,
      openedYear: json['e'] as int?,
      homepage: json['u'] as String? ?? '',
      departments: {
        for (final code in strings('dp')) ?departmentNames[code],
      },
      categories: {
        for (final c in strings('c')) ?_categoryByName[c],
      },
      facilities: {
        for (final f in strings('f')) ?_facilityByName[f],
      },
      absentFacilities: {
        for (final f in strings('fx')) ?_facilityByName[f],
      },
      notes: strings('nt'),
    );
  }
}
