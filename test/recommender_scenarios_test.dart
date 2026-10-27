import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/regions.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/user_profile.dart';
import 'package:hamkke_hospital/services/recommender.dart';
import 'package:hamkke_hospital/services/score_weights.dart';

import 'recommender_helpers.dart';

// 기획서 7.2 "장애 유형 × 진료 목적 대표 조합(최소 30개)에 대한 기대 결과 테스트".
//
// 기대값은 ScoreWeights.standard 로 손으로 계산했다.
//   지정 기관 +50 / 핵심 과 +20 (최대 2개) / 일반 과(내과·가정의학과) +5 (최대 2개)
//   이름에 핵심 과를 내건 의원(전문의 신호) +15 / 어린이인데 소아청소년과 있음 +10
//   편의시설 있음 +8, 없다고 확인 −6, 정보 없음 0 / 직접 고른 시설은 +12, −10
//   거리: 권역 기관(재활·어린이재활·검진·구강진료센터·산부인과)은 −0.2/km (최대 30),
//        그 밖(동네 병원, 건강주치의, 치과 주치의, 정신건강 전문기관)은 −2/km
// hospital() 의 이름은 id 와 같으므로, id 에 핵심 과 이름이 들어가면 전문의 15점이 붙는다.

/// 시나리오 하나. [order] 에 적은 병원은 그 순서대로 모두 나와야 하고(첫 번째가 1순위),
/// [excluded] 에 적은 병원은 나오면 안 된다. 표에 넣은 병원은 둘 중 한쪽에 꼭 적는다.
class Scenario {
  const Scenario(
    this.name, {
    required this.profile,
    required this.hospitals,
    required this.order,
    this.excluded = const [],
    this.reasons = const {},
    this.exactReasons = const {},
    this.present = const {},
    this.missing = const {},
    this.unknown = const {},
    this.designated = const {},
    this.categories,
    this.facilities,
    this.unmatchedTexts,
    this.weights = ScoreWeights.standard,
  });

  final String name;
  final UserProfile profile;
  final List<Hospital> hospitals;

  /// 기대 순서. 첫 번째가 1순위다.
  final List<String> order;

  /// 추천하면 안 되는 병원.
  final List<String> excluded;

  /// 병원별로 추천 이유에 들어 있어야 하는 문구.
  final Map<String, List<String>> reasons;

  /// 병원별 추천 이유 전체 (순서까지).
  final Map<String, List<String>> exactReasons;

  /// 병원별 있는·없는·정보 없는 편의시설과 지정 기관 여부.
  final Map<String, List<Facility>> present;
  final Map<String, List<Facility>> missing;
  final Map<String, List<Facility>> unknown;
  final Map<String, bool> designated;

  /// 조건에서 뽑은 요구사항의 기대값. null 이면 보지 않는다.
  final Set<InstitutionCategory>? categories;
  final Set<Facility>? facilities;
  final List<String>? unmatchedTexts;

  final ScoreWeights weights;
}

const _mobility = {Facility.wheelchair, Facility.parking, Facility.toilet};
const _mobilitySevere = {..._mobility, Facility.lift};
const _mobilityList = [Facility.wheelchair, Facility.parking, Facility.toilet, Facility.lift];

final scenarios = <Scenario>[
  // ───────────── 지체장애 ─────────────
  Scenario(
    '지체장애(심함) 재활: 권역재활병원 > 지정 재활의료기관 > 동네 재활의학과, 정형외과·내과는 뺀다',
    profile: profile({DisabilityType.physical}, CareNeed.rehab),
    hospitals: [
      // 50 + 20 + 시설 4개 32 − 30km×0.2 = 96
      hospital('권역재활병원',
          km: 30,
          departments: {'재활의학과'},
          categories: {InstitutionCategory.rehabHospital},
          facilities: _mobilitySevere),
      // 50 + 20 + 8 − 10km×0.2 = 76
      hospital('지정재활의료기관',
          km: 10,
          departments: {'재활의학과'},
          categories: {InstitutionCategory.rehabDesignated},
          facilities: {Facility.wheelchair}),
      // 20 + 전문의 15 − 1km×2 = 33
      hospital('동네재활의학과의원', km: 1, departments: {'재활의학과'}),
      // 재활 치료는 재활의학과만 찾으므로 지체장애의 정형외과도 뺀다.
      hospital('정형외과의원', km: 1, departments: {'정형외과'}),
      hospital('내과의원', km: 1, departments: {'내과'}),
    ],
    order: ['권역재활병원', '지정재활의료기관', '동네재활의학과의원'],
    excluded: ['정형외과의원', '내과의원'],
    reasons: {
      '권역재활병원': [
        '권역재활병원·국립재활원',
        '편의시설: 휠체어 접근, 장애인 주차, 장애인 화장실, 이동식 리프트·전동 검사대',
      ],
      '동네재활의학과의원': ['재활의학과 전문의 진료'],
    },
    unknown: {'동네재활의학과의원': _mobilityList},
    designated: {'권역재활병원': true, '동네재활의학과의원': false},
    categories: {InstitutionCategory.rehabHospital, InstitutionCategory.rehabDesignated},
    facilities: _mobilitySevere,
  ),
  Scenario(
    '지체장애(심하지 않음) 재활: 리프트는 요구하지 않아서 리프트가 없어도 감점하지 않는다',
    profile: profile({DisabilityType.physical}, CareNeed.rehab, severity: Severity.mild),
    hospitals: [
      // 20 + 시설 3개 24 − 2 = 42. 리프트는 찾는 시설이 아니라 missing 에 들지 않는다.
      hospital('리프트없는재활의원',
          km: 1, departments: {'재활의학과'}, facilities: _mobility, absent: {Facility.lift}),
      // 20 − 휠체어 없음 6 − 2 = 12. 리프트가 있어도 점수에 들지 않는다.
      hospital('리프트있는재활의원',
          km: 1,
          departments: {'재활의학과'},
          facilities: {Facility.lift},
          absent: {Facility.wheelchair}),
    ],
    order: ['리프트없는재활의원', '리프트있는재활의원'],
    present: {'리프트있는재활의원': []},
    missing: {'리프트없는재활의원': [], '리프트있는재활의원': [Facility.wheelchair]},
    facilities: _mobility,
  ),
  Scenario(
    '지체장애(심하지 않음) 치과: 치과 주치의만 찾고 구강진료센터는 지정 기관으로 치지 않는다',
    profile: profile({DisabilityType.physical}, CareNeed.dental, severity: Severity.mild),
    hospitals: [
      // 센터는 찾는 지정 기관이 아니라 치과 20 − 10 = 10 점만 받는다.
      hospital('장애인구강진료센터',
          km: 5, departments: {'치과'}, categories: {InstitutionCategory.dentalCenter}),
      // 50 + 20 − 4km×2(치과 주치의는 동네 병원처럼 감점) = 62
      hospital('치과주치의치과의원',
          km: 4, departments: {'치과'}, categories: {InstitutionCategory.dentalPrimaryCare}),
      // 20 + 시설 3개 24 − 2 = 42
      hospital('가까운치과의원', km: 1, departments: {'치과'}, facilities: _mobility),
    ],
    order: ['치과주치의치과의원', '가까운치과의원', '장애인구강진료센터'],
    designated: {'장애인구강진료센터': false, '치과주치의치과의원': true},
    categories: {InstitutionCategory.dentalPrimaryCare},
    facilities: _mobility,
  ),
  Scenario(
    '지체장애(심함) 재활, 시설은 자동 추정: 리프트 하나 없는 곳이 주차·화장실 없는 곳보다 낫다',
    profile: profile({DisabilityType.physical}, CareNeed.rehab),
    hospitals: [
      // 20 + 16 − 12 − 2 = 22
      hospital('리프트는있는재활의원',
          km: 1,
          departments: {'재활의학과'},
          facilities: {Facility.wheelchair, Facility.lift},
          absent: {Facility.parking, Facility.toilet}),
      // 20 + 24 − 6 − 2 = 36
      hospital('리프트만없는재활의원',
          km: 1, departments: {'재활의학과'}, facilities: _mobility, absent: {Facility.lift}),
    ],
    order: ['리프트만없는재활의원', '리프트는있는재활의원'],
    missing: {
      '리프트는있는재활의원': [Facility.parking, Facility.toilet],
      '리프트만없는재활의원': [Facility.lift],
    },
  ),
  Scenario(
    '지체장애(심함) 재활, 리프트만 직접 골랐으면 리프트 있는 곳이 먼저다 (직접 고른 시설 +12/−10)',
    profile: profile({DisabilityType.physical}, CareNeed.rehab,
        chosenFacilities: {Facility.lift}),
    hospitals: [
      // 20 + 12 − 2 = 30
      hospital('리프트는있는재활의원',
          km: 1,
          departments: {'재활의학과'},
          facilities: {Facility.wheelchair, Facility.lift},
          absent: {Facility.parking, Facility.toilet}),
      // 20 − 10 − 2 = 8
      hospital('리프트만없는재활의원',
          km: 1, departments: {'재활의학과'}, facilities: _mobility, absent: {Facility.lift}),
    ],
    order: ['리프트는있는재활의원', '리프트만없는재활의원'],
    missing: {'리프트는있는재활의원': [], '리프트만없는재활의원': [Facility.lift]},
    facilities: {Facility.lift},
  ),
  Scenario(
    '지체장애(심함) 재활: 권역재활병원은 200km 떨어져도 감점이 30에서 멈춰 동네 의원보다 위다',
    profile: profile({DisabilityType.physical}, CareNeed.rehab),
    hospitals: [
      // 50 + 20 − min(40, 30) = 40
      hospital('아주먼권역재활병원',
          km: 200, departments: {'재활의학과'}, categories: {InstitutionCategory.rehabHospital}),
      // 20 + 15 − 2 = 33
      hospital('동네재활의학과의원', km: 1, departments: {'재활의학과'}),
      // 20 − 10 = 10
      hospital('중간재활의원', km: 5, departments: {'재활의학과'}),
    ],
    order: ['아주먼권역재활병원', '동네재활의학과의원', '중간재활의원'],
  ),
  Scenario(
    '지체장애(심함) 재활, 점수표에서 지정 기관을 10점으로 낮추면 가까운 전문의 의원이 먼저다',
    profile: profile({DisabilityType.physical}, CareNeed.rehab),
    weights: ScoreWeights.fromJson({'designated': 10}),
    hospitals: [
      // 10 + 20 − 8 = 22 (기본 점수표면 62)
      hospital('권역재활병원',
          km: 40, departments: {'재활의학과'}, categories: {InstitutionCategory.rehabHospital}),
      // 20 + 15 − 2 = 33
      hospital('동네재활의학과의원', km: 1, departments: {'재활의학과'}),
    ],
    order: ['동네재활의학과의원', '권역재활병원'],
  ),
  Scenario(
    '지체장애(심하지 않음) 임신·출산: 장애친화 산부인과가 멀어도 먼저, 내과는 뺀다',
    profile: profile({DisabilityType.physical}, CareNeed.pregnancy, severity: Severity.mild),
    hospitals: [
      // 50 + 20 + 전문의 15 + 24 − 25km×0.2 = 104
      hospital('장애친화산부인과',
          km: 25,
          departments: {'산부인과'},
          categories: {InstitutionCategory.friendlyObgyn},
          facilities: _mobility),
      // 20 + 15 − 6 − 4 = 25
      hospital('동네산부인과의원',
          km: 2, departments: {'산부인과'}, absent: {Facility.wheelchair}),
      // 20 − 2 = 18. 임신·출산은 산부인과만 찾으므로 내과는 점수에 들지 않는다.
      hospital('여성병원', km: 1, departments: {'산부인과', '내과'}),
      hospital('내과의원', km: 1, departments: {'내과'}),
    ],
    order: ['장애친화산부인과', '동네산부인과의원', '여성병원'],
    excluded: ['내과의원'],
    reasons: {'장애친화산부인과': ['장애친화 산부인과', '산부인과 전문의 진료']},
    exactReasons: {'여성병원': ['진료과: 산부인과']},
    missing: {'동네산부인과의원': [Facility.wheelchair]},
    categories: {InstitutionCategory.friendlyObgyn},
    facilities: _mobility,
  ),
  Scenario(
    '지체장애(심하지 않음) 기타 진료 "피부 질환": 피부과만 찾고 재활의학과는 뺀다',
    profile: profile({DisabilityType.physical}, CareNeed.other,
        severity: Severity.mild, otherNeed: '피부 질환'),
    hospitals: [
      // 20 + 15 + 8 − 6 = 37
      hospital('맑은피부과의원', km: 3, departments: {'피부과'}, facilities: {Facility.wheelchair}),
      // 20 − 12 − 2 = 6. 재활의학과·정형외과는 찾는 과가 아니다.
      hospital('종합병원',
          km: 1,
          departments: {'피부과', '재활의학과', '정형외과'},
          absent: {Facility.wheelchair, Facility.parking}),
      hospital('재활의학과의원', km: 0.5, departments: {'재활의학과'}),
    ],
    order: ['맑은피부과의원', '종합병원'],
    excluded: ['재활의학과의원'],
    exactReasons: {'종합병원': ['진료과: 피부과']},
    missing: {'종합병원': [Facility.wheelchair, Facility.parking]},
    facilities: _mobility,
    unmatchedTexts: [],
  ),

  // ───────────── 뇌병변장애 ─────────────
  Scenario(
    '기획서 5.2-A 휠체어 뇌병변(심함) 재활, 현재 위치: 재활의료기관·권역재활병원이 위에, 신경과는 뺀다',
    profile: profile({DisabilityType.brainLesion}, CareNeed.rehab,
        location: Area('현재 위치', seoul.lat, seoul.lng + 20 / 88.2)),
    hospitals: [
      // 현재 위치에서 40km: 50 + 20 + 32 − 8 = 94
      hospital('제3기재활의료기관',
          km: 60,
          departments: {'재활의학과'},
          categories: {InstitutionCategory.rehabDesignated},
          facilities: _mobilitySevere),
      // 현재 위치 바로 옆: 50 + 20 + 16 − 주차 없음 6 = 80
      hospital('권역재활병원',
          km: 20,
          departments: {'재활의학과'},
          categories: {InstitutionCategory.rehabHospital},
          facilities: {Facility.wheelchair, Facility.lift},
          absent: {Facility.parking}),
      // 1km: 20 + 15 − 2 = 33
      hospital('가까운재활의학과의원', km: 21, departments: {'재활의학과'}),
      // 뇌병변의 신경과는 재활 치료에서는 찾지 않는다.
      hospital('동네신경과의원', km: 20, departments: {'신경과'}),
    ],
    order: ['제3기재활의료기관', '권역재활병원', '가까운재활의학과의원'],
    excluded: ['동네신경과의원'],
    present: {'권역재활병원': [Facility.wheelchair, Facility.lift]},
    missing: {'권역재활병원': [Facility.parking]},
    unknown: {'권역재활병원': [Facility.toilet]},
    facilities: _mobilitySevere,
  ),
  Scenario(
    '뇌병변(심함) 어린이 재활: 공공어린이재활병원이 먼저, 소아청소년과 있으면 10점 더',
    profile: profile({DisabilityType.brainLesion}, CareNeed.rehab, age: AgeGroup.child),
    hospitals: [
      // 50 + 20 + 어린이 10 − 8 = 72
      hospital('공공어린이재활병원',
          km: 40,
          departments: {'재활의학과', '소아청소년과'},
          categories: {InstitutionCategory.childRehab}),
      // 50 + 20 − 1 = 69
      hospital('권역재활병원',
          km: 5, departments: {'재활의학과'}, categories: {InstitutionCategory.rehabHospital}),
      // 진료과 없이 지정만: 50 − 3 = 47
      hospital('공공어린이재활센터', km: 15, categories: {InstitutionCategory.childRehab}),
      // 20 + 10 − 4 = 26
      hospital('소아재활의원', km: 2, departments: {'재활의학과', '소아청소년과'}),
      // 20 − 2 = 18
      hospital('재활의원', km: 1, departments: {'재활의학과'}),
    ],
    order: ['공공어린이재활병원', '권역재활병원', '공공어린이재활센터', '소아재활의원', '재활의원'],
    reasons: {
      '공공어린이재활병원': ['공공어린이재활병원·센터', '어린이 진료: 소아청소년과'],
      '소아재활의원': ['어린이 진료: 소아청소년과'],
    },
    categories: {
      InstitutionCategory.rehabHospital,
      InstitutionCategory.rehabDesignated,
      InstitutionCategory.childRehab,
    },
  ),
  Scenario(
    '뇌병변(심함) 성인 재활: 어린이 재활 기관은 찾지 않고, 소아청소년과도 가산하지 않는다',
    profile: profile({DisabilityType.brainLesion}, CareNeed.rehab),
    hospitals: [
      // 지정 기관으로 치지 않고 재활의학과 20 − 8 = 12
      hospital('공공어린이재활병원',
          km: 40,
          departments: {'재활의학과', '소아청소년과'},
          categories: {InstitutionCategory.childRehab}),
      // 69
      hospital('권역재활병원',
          km: 5, departments: {'재활의학과'}, categories: {InstitutionCategory.rehabHospital}),
      // 진료과도 없고 찾는 지정 기관도 아니라 뺀다.
      hospital('공공어린이재활센터', km: 15, categories: {InstitutionCategory.childRehab}),
      // 20 − 4 = 16
      hospital('소아재활의원', km: 2, departments: {'재활의학과', '소아청소년과'}),
      // 18
      hospital('재활의원', km: 1, departments: {'재활의학과'}),
    ],
    order: ['권역재활병원', '재활의원', '소아재활의원', '공공어린이재활병원'],
    excluded: ['공공어린이재활센터'],
    exactReasons: {'소아재활의원': ['진료과: 재활의학과']},
    designated: {'공공어린이재활병원': false},
    categories: {InstitutionCategory.rehabHospital, InstitutionCategory.rehabDesignated},
  ),
  Scenario(
    '뇌병변(심함) 치과: 구강진료센터 + 진정 치료 + 휠체어·리프트, 치과는 전문의 신호가 없다',
    profile: profile({DisabilityType.brainLesion}, CareNeed.dental),
    hospitals: [
      // 50 + 20 + 시설 5개 40 − 25km×0.2 = 105
      hospital('장애인구강진료센터',
          km: 25,
          departments: {'치과'},
          categories: {InstitutionCategory.dentalCenter},
          facilities: {..._mobilitySevere, Facility.sedation}),
      // 50 + 20 + 8 − 3km×2 = 72
      hospital('치과주치의치과의원',
          km: 3,
          departments: {'치과'},
          categories: {InstitutionCategory.dentalPrimaryCare},
          facilities: {Facility.wheelchair}),
      // 20 − 2 = 18. 치과의원은 모두 이름에 치과가 있어 전문의 15점이 없다.
      hospital('동네치과의원', km: 1, departments: {'치과'}),
      hospital('내과의원', km: 1, departments: {'내과'}),
    ],
    order: ['장애인구강진료센터', '치과주치의치과의원', '동네치과의원'],
    excluded: ['내과의원'],
    reasons: {
      '장애인구강진료센터': [
        '장애인구강진료센터',
        '편의시설: 휠체어 접근, 장애인 주차, 장애인 화장실, 이동식 리프트·전동 검사대, 진정·수면 치료',
      ],
    },
    exactReasons: {'동네치과의원': ['진료과: 치과']},
    categories: {InstitutionCategory.dentalPrimaryCare, InstitutionCategory.dentalCenter},
    facilities: {..._mobilitySevere, Facility.sedation},
  ),
  Scenario(
    '뇌병변(심함) 재활: 편의시설이 있다고 확인된 곳 > 정보 없는 곳 > 없다고 확인된 곳',
    profile: profile({DisabilityType.brainLesion}, CareNeed.rehab),
    hospitals: [
      // 20 + 32 − 6 = 46
      hospital('있음재활의원', km: 3, departments: {'재활의학과'}, facilities: _mobilitySevere),
      // 20 − 2 = 18. 정보가 없으면 빼지 않는다.
      hospital('정보없음재활의원', km: 1, departments: {'재활의학과'}),
      // 20 − 24 − 2 = −6
      hospital('없음재활의원', km: 1, departments: {'재활의학과'}, absent: _mobilitySevere),
    ],
    order: ['있음재활의원', '정보없음재활의원', '없음재활의원'],
    exactReasons: {'정보없음재활의원': ['진료과: 재활의학과']},
    present: {'있음재활의원': _mobilityList},
    unknown: {'정보없음재활의원': _mobilityList},
    missing: {'없음재활의원': _mobilityList},
  ),
  Scenario(
    '뇌병변 + 기타 "아이 뇌성마비" 재활(나이는 성인): 글에서 아이를 읽어 어린이 재활 기관도 찾는다',
    profile: profile({DisabilityType.brainLesion, DisabilityType.other}, CareNeed.rehab,
        otherDisability: '아이 뇌성마비'),
    hospitals: [
      // 50 + 20 − 6 = 64
      hospital('공공어린이재활병원',
          km: 30, departments: {'재활의학과'}, categories: {InstitutionCategory.childRehab}),
      // 50 + 20 − 8 = 62
      hospital('권역재활병원',
          km: 40, departments: {'재활의학과'}, categories: {InstitutionCategory.rehabHospital}),
      // 20 − 2 = 18. 나이가 성인이라 소아청소년과 가산은 없다.
      hospital('소아재활의원', km: 1, departments: {'재활의학과', '소아청소년과'}),
    ],
    order: ['공공어린이재활병원', '권역재활병원', '소아재활의원'],
    exactReasons: {'소아재활의원': ['진료과: 재활의학과']},
    categories: {
      InstitutionCategory.rehabHospital,
      InstitutionCategory.rehabDesignated,
      InstitutionCategory.childRehab,
    },
    unmatchedTexts: [],
  ),

  // ───────────── 시각장애 ─────────────
  Scenario(
    '시각장애(심하지 않음) 일반 진료: 점자 안내 있는 안과 전문의 > 종합병원 > 가정의학과',
    profile: profile({DisabilityType.visual}, CareNeed.general, severity: Severity.mild),
    hospitals: [
      // 20 + 15 + 8 − 6 = 37
      hospital('밝은안과의원', km: 3, departments: {'안과'}, facilities: {Facility.braille}),
      // 핵심 안과 20 + 일반 과 2개 10 − 4 = 26
      hospital('종합병원', km: 2, departments: {'안과', '내과', '가정의학과'}),
      // 일반 과만 5 − 1 = 4. 핵심 과가 아니라 이름이 같아도 전문의 점수는 없다.
      hospital('가정의학과의원', km: 0.5, departments: {'가정의학과'}),
      hospital('피부과의원', km: 0.5, departments: {'피부과'}),
    ],
    order: ['밝은안과의원', '종합병원', '가정의학과의원'],
    excluded: ['피부과의원'],
    reasons: {
      '밝은안과의원': ['안과 전문의 진료', '편의시설: 점자·음성 안내'],
      '종합병원': ['진료과: 안과, 가정의학과, 내과'],
    },
    exactReasons: {'가정의학과의원': ['진료과: 가정의학과']},
    facilities: {Facility.braille},
  ),
  Scenario(
    '시각장애(심하지 않음) 기타 진료 "잘 모르겠어요": 일반 진료처럼 찾고 그 글을 알려 준다',
    profile: profile({DisabilityType.visual}, CareNeed.other,
        severity: Severity.mild, otherNeed: '잘 모르겠어요'),
    hospitals: [
      // 20 + 15 − 4 = 31
      hospital('안과의원', km: 2, departments: {'안과'}),
      // 5 − 2 = 3
      hospital('내과의원', km: 1, departments: {'내과'}),
      hospital('피부과의원', km: 0.5, departments: {'피부과'}),
    ],
    order: ['안과의원', '내과의원'],
    excluded: ['피부과의원'],
    unmatchedTexts: ['잘 모르겠어요'],
  ),

  // ───────────── 청각장애 ─────────────
  Scenario(
    '기획서 5.2-C 청각장애(심함) 일반 진료: 수어 통역 있는 이비인후과가 먼저, 없다고 확인되면 경고',
    profile: profile({DisabilityType.hearing}, CareNeed.general),
    hospitals: [
      // 20 + 15 + 8 − 8 = 35
      hospital('수어통역이비인후과의원',
          km: 4, departments: {'이비인후과'}, facilities: {Facility.signLanguage}),
      // 20 + 15 − 6 − 2 = 27
      hospital('이비인후과의원', km: 1, departments: {'이비인후과'}, absent: {Facility.signLanguage}),
      // 5 − 1 = 4
      hospital('내과의원', km: 0.5, departments: {'내과'}),
      hospital('안과의원', km: 0.5, departments: {'안과'}),
    ],
    order: ['수어통역이비인후과의원', '이비인후과의원', '내과의원'],
    excluded: ['안과의원'],
    reasons: {'수어통역이비인후과의원': ['편의시설: 수어 통역']},
    present: {'수어통역이비인후과의원': [Facility.signLanguage]},
    missing: {'이비인후과의원': [Facility.signLanguage]},
    facilities: {Facility.signLanguage},
  ),
  Scenario(
    '청각장애(심하지 않음) 만성질환: 건강주치의는 동네 병원처럼 감점해 8km 면 먼저, 30km 면 뒤로 간다',
    profile: profile({DisabilityType.hearing}, CareNeed.chronic, severity: Severity.mild),
    hospitals: [
      // 50 + 일반 과 5 − 8km×2 = 39
      hospital('건강주치의의원',
          km: 8, departments: {'내과'}, categories: {InstitutionCategory.primaryCare}),
      // 20 + 15 − 2 = 33
      hospital('이비인후과의원', km: 1, departments: {'이비인후과'}),
      // 50 + 5 − 60 = −5
      hospital('먼건강주치의',
          km: 30, departments: {'가정의학과'}, categories: {InstitutionCategory.primaryCare}),
    ],
    order: ['건강주치의의원', '이비인후과의원', '먼건강주치의'],
    exactReasons: {'건강주치의의원': ['장애인 건강주치의', '진료과: 내과']},
    categories: {InstitutionCategory.primaryCare},
    facilities: {Facility.signLanguage},
  ),

  // ───────────── 언어장애 ─────────────
  Scenario(
    '언어장애(심하지 않음) 재활: 재활의료기관 > 재활의학과 전문의, 이비인후과는 재활에서 찾지 않는다',
    profile: profile({DisabilityType.speech}, CareNeed.rehab, severity: Severity.mild),
    hospitals: [
      // 50 + 20 − 3 = 67
      hospital('재활의료기관',
          km: 15, departments: {'재활의학과'}, categories: {InstitutionCategory.rehabDesignated}),
      // 20 + 15 − 4 = 31
      hospital('언어재활의학과의원', km: 2, departments: {'재활의학과'}),
      hospital('이비인후과의원', km: 1, departments: {'이비인후과'}),
    ],
    order: ['재활의료기관', '언어재활의학과의원'],
    excluded: ['이비인후과의원'],
    // 언어장애에는 미리 정하는 편의시설이 없다.
    unknown: {'재활의료기관': [], '언어재활의학과의원': []},
    facilities: {},
  ),
  Scenario(
    '언어장애(심하지 않음) 일반 진료: 이비인후과·재활의학과 둘 다 핵심 과(최대 2개)라 둘 다 있는 곳이 위',
    profile: profile({DisabilityType.speech}, CareNeed.general, severity: Severity.mild),
    hospitals: [
      // 핵심 2개 40 + 일반 2개 10 − 4 = 46 (정형외과는 들지 않는다)
      hospital('종합병원',
          km: 2, departments: {'이비인후과', '재활의학과', '내과', '가정의학과', '정형외과'}),
      // 40 − 5 = 35
      hospital('두과모두의원', km: 2.5, departments: {'이비인후과', '재활의학과'}),
      // 20 + 15 − 2 = 33
      hospital('이비인후과의원', km: 1, departments: {'이비인후과'}),
    ],
    order: ['종합병원', '두과모두의원', '이비인후과의원'],
    exactReasons: {'종합병원': ['진료과: 이비인후과, 재활의학과, 가정의학과, 내과']},
  ),

  // ───────────── 지적장애 ─────────────
  Scenario(
    '지적장애(심하지 않음) 성인 치과: 발달장애라 구강진료센터도 찾고, 진정 치료 없다고 확인되면 감점',
    profile: profile({DisabilityType.intellectual}, CareNeed.dental, severity: Severity.mild),
    hospitals: [
      // 50 + 20 + 16 − 50km×0.2 = 76
      hospital('장애인구강진료센터',
          km: 50,
          departments: {'치과'},
          categories: {InstitutionCategory.dentalCenter},
          facilities: {Facility.sedation, Facility.quietRoom}),
      // 50 + 20 − 6 − 4 = 60
      hospital('치과주치의치과의원',
          km: 2,
          departments: {'치과'},
          categories: {InstitutionCategory.dentalPrimaryCare},
          absent: {Facility.sedation}),
      // 18
      hospital('동네치과의원', km: 1, departments: {'치과'}),
    ],
    order: ['장애인구강진료센터', '치과주치의치과의원', '동네치과의원'],
    missing: {'치과주치의치과의원': [Facility.sedation]},
    categories: {InstitutionCategory.dentalPrimaryCare, InstitutionCategory.dentalCenter},
    facilities: {Facility.sedation, Facility.quietRoom},
  ),
  Scenario(
    '지적장애(심함) 마음 건강: 국립 정신건강 전문기관은 동네 병원처럼 감점해 12km 면 먼저, 40km 면 뒤',
    profile: profile({DisabilityType.intellectual}, CareNeed.mentalHealth),
    hospitals: [
      // 50 + 20 + 8 − 12km×2 = 54
      hospital('국립정신건강센터',
          km: 12,
          departments: {'정신건강의학과'},
          categories: {InstitutionCategory.mentalHealthCenter},
          facilities: {Facility.quietRoom}),
      // 20 + 15 + 8 − 2 = 41
      hospital('마음정신건강의학과의원',
          km: 1, departments: {'정신건강의학과'}, facilities: {Facility.quietRoom}),
      // 50 + 20 − 80 = −10
      hospital('먼국립병원',
          km: 40,
          departments: {'정신건강의학과'},
          categories: {InstitutionCategory.mentalHealthCenter}),
      hospital('내과의원', km: 0.5, departments: {'내과'}),
    ],
    order: ['국립정신건강센터', '마음정신건강의학과의원', '먼국립병원'],
    excluded: ['내과의원'],
    designated: {'먼국립병원': true, '마음정신건강의학과의원': false},
    categories: {InstitutionCategory.mentalHealthCenter},
    facilities: {Facility.quietRoom},
  ),
  Scenario(
    '지적장애(심하지 않음) 어린이 일반 진료: 소아청소년과는 핵심 과(+20)이고 어린이 가산은 겹치지 않는다',
    profile: profile({DisabilityType.intellectual}, CareNeed.general,
        severity: Severity.mild, age: AgeGroup.child),
    hospitals: [
      // 핵심 2개 40 − 6 = 34
      hospital('둘다병원', km: 3, departments: {'소아청소년과', '정신건강의학과'}),
      // 20 + 15 − 2 = 33
      hospital('정신건강의학과의원', km: 1, departments: {'정신건강의학과'}),
      // 20 + 15 − 4 = 31 (어린이 10점은 따로 붙지 않는다)
      hospital('소아청소년과의원', km: 2, departments: {'소아청소년과'}),
      // 5 − 1 = 4
      hospital('내과의원', km: 0.5, departments: {'내과'}),
    ],
    order: ['둘다병원', '정신건강의학과의원', '소아청소년과의원', '내과의원'],
    exactReasons: {
      '소아청소년과의원': ['진료과: 소아청소년과', '소아청소년과 전문의 진료'],
      '둘다병원': ['진료과: 정신건강의학과, 소아청소년과'],
    },
    facilities: {Facility.quietRoom},
  ),

  // ───────────── 자폐성장애 ─────────────
  Scenario(
    '기획서 5.2-B 자폐성장애(심함) 어린이 치과: 진정 치료·조용한 대기 공간 있는 구강진료센터가 먼저',
    profile: profile({DisabilityType.autism}, CareNeed.dental, age: AgeGroup.child),
    hospitals: [
      // 50 + 20 + 16 − 4 = 82
      hospital('장애인구강진료센터',
          km: 20,
          departments: {'치과'},
          categories: {InstitutionCategory.dentalCenter},
          facilities: {Facility.sedation, Facility.quietRoom}),
      // 20 + 어린이 10 − 4 = 26
      hospital('어린이치과의원', km: 2, departments: {'치과', '소아청소년과'}),
      // 20 + 8 − 6 = 22
      hospital('진정치료치과의원', km: 3, departments: {'치과'}, facilities: {Facility.sedation}),
      // 18
      hospital('동네치과의원', km: 1, departments: {'치과'}),
      hospital('안과의원', km: 1, departments: {'안과'}),
    ],
    order: ['장애인구강진료센터', '어린이치과의원', '진정치료치과의원', '동네치과의원'],
    excluded: ['안과의원'],
    reasons: {
      '장애인구강진료센터': ['장애인구강진료센터', '편의시설: 진정·수면 치료, 조용한 대기 공간'],
      '어린이치과의원': ['어린이 진료: 소아청소년과'],
    },
    unknown: {'어린이치과의원': [Facility.sedation, Facility.quietRoom]},
    categories: {InstitutionCategory.dentalPrimaryCare, InstitutionCategory.dentalCenter},
    facilities: {Facility.sedation, Facility.quietRoom},
  ),
  Scenario(
    '자폐성장애(심하지 않음) 일반 진료, 주차·조용한 대기 공간을 직접 고름: 둘 다 있는 곳이 5km 여도 먼저',
    profile: profile({DisabilityType.autism}, CareNeed.general,
        severity: Severity.mild, chosenFacilities: {Facility.quietRoom, Facility.parking}),
    hospitals: [
      // 20 + 15 + 직접 고른 시설 2개 24 − 10 = 49
      hospital('조용한정신건강의학과의원',
          km: 5,
          departments: {'정신건강의학과'},
          facilities: {Facility.quietRoom, Facility.parking}),
      // 20 + 15 − 10 − 2 = 23
      hospital('정신건강의학과의원',
          km: 1, departments: {'정신건강의학과'}, absent: {Facility.quietRoom}),
      // 5 − 2 = 3
      hospital('가정의학과의원', km: 1, departments: {'가정의학과'}),
    ],
    order: ['조용한정신건강의학과의원', '정신건강의학과의원', '가정의학과의원'],
    reasons: {'조용한정신건강의학과의원': ['편의시설: 장애인 주차, 조용한 대기 공간']},
    missing: {'정신건강의학과의원': [Facility.quietRoom]},
    facilities: {Facility.parking, Facility.quietRoom},
  ),

  // ───────────── 정신장애 ─────────────
  Scenario(
    '정신장애(심하지 않음) 마음 건강: 전문의 의원이 6km 여도 먼저, 내과는 점수에 들지 않는다',
    profile: profile({DisabilityType.mental}, CareNeed.mentalHealth, severity: Severity.mild),
    hospitals: [
      // 20 + 15 − 12 = 23
      hospital('행복정신건강의학과의원', km: 6, departments: {'정신건강의학과'}),
      // 20 − 2 = 18
      hospital('동네의원', km: 1, departments: {'정신건강의학과'}),
      // 20 − 4 = 16
      hospital('종합병원', km: 2, departments: {'정신건강의학과', '내과'}),
    ],
    order: ['행복정신건강의학과의원', '동네의원', '종합병원'],
    exactReasons: {'종합병원': ['진료과: 정신건강의학과']},
    facilities: {},
  ),

  // ───────────── 신장장애 ─────────────
  Scenario(
    '신장장애(심함) 만성질환: 인공신장실 있는 건강주치의 내과가 먼저, 내과가 핵심 과다',
    profile: profile({DisabilityType.kidney}, CareNeed.chronic),
    hospitals: [
      // 50 + 20 + 15 + 8 − 6 = 87
      hospital('건강주치의내과의원',
          km: 3,
          departments: {'내과'},
          categories: {InstitutionCategory.primaryCare},
          facilities: {Facility.dialysis}),
      // 20 + 15 + 8 − 2 = 41
      hospital('투석내과의원', km: 1, departments: {'내과'}, facilities: {Facility.dialysis}),
      // 20 + 15 − 6 − 2 = 27
      hospital('내과의원', km: 1, departments: {'내과'}, absent: {Facility.dialysis}),
      // 5 − 1 = 4
      hospital('가정의학과의원', km: 0.5, departments: {'가정의학과'}),
    ],
    order: ['건강주치의내과의원', '투석내과의원', '내과의원', '가정의학과의원'],
    exactReasons: {
      '건강주치의내과의원': ['장애인 건강주치의', '진료과: 내과', '내과 전문의 진료', '편의시설: 인공신장실'],
    },
    missing: {'내과의원': [Facility.dialysis]},
    categories: {InstitutionCategory.primaryCare},
    facilities: {Facility.dialysis},
  ),
  Scenario(
    '신장장애(심하지 않음) 일반 진료: 인공신장실은 만성질환 관리에서만 찾으므로 점수에 들지 않는다',
    profile: profile({DisabilityType.kidney}, CareNeed.general, severity: Severity.mild),
    hospitals: [
      // 20 + 15 − 2 = 33 (인공신장실 없음은 감점하지 않는다)
      hospital('내과의원', km: 1, departments: {'내과'}, absent: {Facility.dialysis}),
      // 20 + 15 − 6 = 29
      hospital('투석내과의원', km: 3, departments: {'내과'}, facilities: {Facility.dialysis}),
    ],
    order: ['내과의원', '투석내과의원'],
    present: {'투석내과의원': []},
    missing: {'내과의원': []},
    facilities: {},
  ),

  // ───────────── 심장장애 ─────────────
  Scenario(
    '심장장애(심하지 않음) 건강검진: 장애친화 건강검진기관이 35km 여도 먼저, 검진은 가정의학과만 찾는다',
    profile: profile({DisabilityType.heart}, CareNeed.checkup, severity: Severity.mild),
    hospitals: [
      // 50 + 20 − 7 = 63 (내과는 검진에서 찾는 과가 아니다)
      hospital('장애친화건강검진기관',
          km: 35,
          departments: {'가정의학과', '내과'},
          categories: {InstitutionCategory.friendlyCheckup}),
      // 20 + 15 − 2 = 33
      hospital('가정의학과의원', km: 1, departments: {'가정의학과'}),
      hospital('내과의원', km: 0.5, departments: {'내과'}),
    ],
    order: ['장애친화건강검진기관', '가정의학과의원'],
    excluded: ['내과의원'],
    exactReasons: {'장애친화건강검진기관': ['장애친화 건강검진기관', '진료과: 가정의학과']},
    categories: {InstitutionCategory.friendlyCheckup},
    facilities: {},
  ),
  Scenario(
    '심장장애(심하지 않음) 어린이 만성질환: 소아청소년과와 내과가 핵심 과, 건강주치의가 먼저',
    profile: profile({DisabilityType.heart}, CareNeed.chronic,
        severity: Severity.mild, age: AgeGroup.child),
    hospitals: [
      // 50 + 20 − 8 = 62 (소아청소년과가 이미 핵심 과라 어린이 10점은 따로 없다)
      hospital('어린이건강주치의',
          km: 4, departments: {'소아청소년과'}, categories: {InstitutionCategory.primaryCare}),
      // 20 + 15 − 2 = 33
      hospital('소아청소년과의원', km: 1, departments: {'소아청소년과'}),
      // 20 + 15 − 4 = 31
      hospital('내과의원', km: 2, departments: {'내과'}),
      // 5 − 1 = 4
      hospital('가정의학과의원', km: 0.5, departments: {'가정의학과'}),
    ],
    order: ['어린이건강주치의', '소아청소년과의원', '내과의원', '가정의학과의원'],
    exactReasons: {'어린이건강주치의': ['장애인 건강주치의', '진료과: 소아청소년과']},
    categories: {InstitutionCategory.primaryCare},
  ),

  // ───────────── 호흡기·간장애 ─────────────
  Scenario(
    '호흡기장애(심함) 일반 진료: 내과 전문의 > 종합병원(내과+가정의학과) > 가정의학과만',
    profile: profile({DisabilityType.respiratory}, CareNeed.general),
    hospitals: [
      // 20 + 15 − 4 = 31
      hospital('숨내과의원', km: 2, departments: {'내과'}),
      // 20 + 5 − 6 = 19
      hospital('종합병원', km: 3, departments: {'내과', '가정의학과', '정형외과'}),
      // 5 − 1 = 4
      hospital('가정의학과의원', km: 0.5, departments: {'가정의학과'}),
    ],
    order: ['숨내과의원', '종합병원', '가정의학과의원'],
    exactReasons: {'종합병원': ['진료과: 내과, 가정의학과']},
  ),
  Scenario(
    '간장애(심하지 않음) 만성질환: 5km 건강주치의 > 가까운 내과 전문의 > 40km 건강주치의',
    profile: profile({DisabilityType.liver}, CareNeed.chronic, severity: Severity.mild),
    hospitals: [
      // 50 + 5 − 10 = 45
      hospital('가까운건강주치의',
          km: 5, departments: {'가정의학과'}, categories: {InstitutionCategory.primaryCare}),
      // 20 + 15 − 2 = 33
      hospital('가까운내과의원', km: 1, departments: {'내과'}),
      // 50 + 20 − 80 = −10
      hospital('먼건강주치의',
          km: 40, departments: {'내과'}, categories: {InstitutionCategory.primaryCare}),
    ],
    order: ['가까운건강주치의', '가까운내과의원', '먼건강주치의'],
    categories: {InstitutionCategory.primaryCare},
  ),

  // ───────────── 안면·장루·뇌전증 ─────────────
  Scenario(
    '안면장애(심하지 않음) 일반 진료: 성형외과 전문의가 먼저, 외과는 다른 과라 뺀다',
    profile: profile({DisabilityType.facial}, CareNeed.general, severity: Severity.mild),
    hospitals: [
      // 20 + 15 − 6 = 29
      hospital('아름성형외과의원', km: 3, departments: {'성형외과'}),
      // 20 + 5 − 2 = 23
      hospital('종합병원', km: 1, departments: {'성형외과', '내과'}),
      hospital('외과의원', km: 0.5, departments: {'외과'}),
    ],
    order: ['아름성형외과의원', '종합병원'],
    excluded: ['외과의원'],
    reasons: {'아름성형외과의원': ['성형외과 전문의 진료']},
    facilities: {},
  ),
  Scenario(
    '장루·요루장애(심하지 않음) 일반 진료: 외과·비뇨의학과가 핵심 과, 장애인 화장실 필요, 정형외과는 뺀다',
    profile: profile({DisabilityType.ostomy}, CareNeed.general, severity: Severity.mild),
    hospitals: [
      // 핵심 2개 40 + 일반 5 + 8 − 8 = 45
      hospital('종합병원',
          km: 4, departments: {'외과', '비뇨의학과', '내과'}, facilities: {Facility.toilet}),
      // 20 + 15 + 8 − 4 = 39
      hospital('비뇨의학과의원', km: 2, departments: {'비뇨의학과'}, facilities: {Facility.toilet}),
      // 20 + 15 − 6 − 6 = 23
      hospital('서울외과의원', km: 3, departments: {'외과'}, absent: {Facility.toilet}),
      hospital('정형외과의원', km: 0.5, departments: {'정형외과'}),
    ],
    order: ['종합병원', '비뇨의학과의원', '서울외과의원'],
    excluded: ['정형외과의원'],
    reasons: {'서울외과의원': ['외과 전문의 진료']},
    missing: {'서울외과의원': [Facility.toilet]},
    facilities: {Facility.toilet},
  ),
  Scenario(
    '뇌전증장애(심함) 일반 진료: 신경과 전문의가 먼저, 신경외과는 다른 과라 뺀다',
    profile: profile({DisabilityType.epilepsy}, CareNeed.general),
    hospitals: [
      // 20 + 15 − 10 = 25
      hospital('뇌전증신경과의원', km: 5, departments: {'신경과'}),
      // 5 − 1 = 4
      hospital('내과의원', km: 0.5, departments: {'내과'}),
      hospital('신경외과의원', km: 0.5, departments: {'신경외과'}),
    ],
    order: ['뇌전증신경과의원', '내과의원'],
    excluded: ['신경외과의원'],
    facilities: {},
  ),
  Scenario(
    '뇌전증장애(심하지 않음) 기타 진료 "수면 장애": 글에서 정신건강의학과·신경과를 찾고 내과는 더하지 않는다',
    profile: profile({DisabilityType.epilepsy}, CareNeed.other,
        severity: Severity.mild, otherNeed: '수면 장애'),
    hospitals: [
      // 20 + 15 − 4 = 31
      hospital('신경과의원', km: 2, departments: {'신경과'}),
      // 20 + 15 − 6 = 29
      hospital('마음정신건강의학과의원', km: 3, departments: {'정신건강의학과'}),
      hospital('내과의원', km: 0.5, departments: {'내과'}),
    ],
    order: ['신경과의원', '마음정신건강의학과의원'],
    excluded: ['내과의원'],
    unmatchedTexts: [],
  ),

  // ───────────── 기타 장애 ─────────────
  Scenario(
    '기타 장애 "척수손상"(심하지 않음) 일반 진료: 재활의학과·신경외과가 핵심 과, 정형외과는 뺀다',
    profile: profile({DisabilityType.other}, CareNeed.general,
        severity: Severity.mild, otherDisability: '척수손상'),
    hospitals: [
      // 20 + 15 − 4 = 31
      hospital('신경외과의원', km: 2, departments: {'신경외과'}),
      // 20 + 15 − 6 = 29
      hospital('척수재활의학과의원', km: 3, departments: {'재활의학과'}),
      // 5 − 1 = 4
      hospital('내과의원', km: 0.5, departments: {'내과'}),
      hospital('정형외과의원', km: 0.5, departments: {'정형외과'}),
    ],
    order: ['신경외과의원', '척수재활의학과의원', '내과의원'],
    excluded: ['정형외과의원'],
    facilities: {},
    unmatchedTexts: [],
  ),

  // ───────────── 중복장애 ─────────────
  Scenario(
    '지체 + 시각(심함) 일반 진료: 핵심 과는 최대 2개까지만 세고, 휠체어·점자 안내를 함께 찾는다',
    profile: profile({DisabilityType.physical, DisabilityType.visual}, CareNeed.general),
    hospitals: [
      // 핵심 2개 40 + 시설 2개 16 − 4 = 52
      hospital('두과병원',
          km: 2,
          departments: {'정형외과', '안과'},
          facilities: {Facility.wheelchair, Facility.braille}),
      // 20 + 15 − 2 = 33
      hospital('안과의원', km: 1, departments: {'안과'}),
      // 핵심 과가 3개여도 40 − 10 = 30
      hospital('세과종합병원', km: 5, departments: {'재활의학과', '정형외과', '안과'}),
    ],
    order: ['두과병원', '안과의원', '세과종합병원'],
    present: {'두과병원': [Facility.wheelchair, Facility.braille]},
    unknown: {'두과병원': [Facility.parking, Facility.toilet, Facility.lift]},
    facilities: {..._mobilitySevere, Facility.braille},
  ),
  Scenario(
    '청각 + 지적(심함) 치과: 수어 통역·진정 치료·조용한 대기 공간을 모두 찾고, 없다고 확인된 것만 경고',
    profile: profile({DisabilityType.hearing, DisabilityType.intellectual}, CareNeed.dental),
    hospitals: [
      // 50 + 20 + 16 − 수어 없음 6 − 4 = 76
      hospital('장애인구강진료센터',
          km: 20,
          departments: {'치과'},
          categories: {InstitutionCategory.dentalCenter},
          facilities: {Facility.sedation, Facility.quietRoom},
          absent: {Facility.signLanguage}),
      // 50 + 20 + 8 − 6 = 72
      hospital('치과주치의치과의원',
          km: 3,
          departments: {'치과'},
          categories: {InstitutionCategory.dentalPrimaryCare},
          facilities: {Facility.signLanguage}),
      // 18
      hospital('동네치과의원', km: 1, departments: {'치과'}),
    ],
    order: ['장애인구강진료센터', '치과주치의치과의원', '동네치과의원'],
    missing: {'장애인구강진료센터': [Facility.signLanguage]},
    unknown: {'치과주치의치과의원': [Facility.sedation, Facility.quietRoom]},
    facilities: {Facility.signLanguage, Facility.sedation, Facility.quietRoom},
  ),
];

void main() {
  for (final s in scenarios) {
    test(s.name, () {
      final req = buildRequirement(s.profile);
      if (s.categories != null) expect(req.categories, s.categories, reason: '찾는 지정 기관');
      if (s.facilities != null) expect(req.facilities, s.facilities, reason: '필요한 편의시설');
      if (s.unmatchedTexts != null) {
        expect(req.unmatchedTexts, s.unmatchedTexts, reason: '해석하지 못한 글');
      }

      final results = recommend(s.profile, s.hospitals, limit: null, weights: s.weights);
      final got = ids(results);
      expect(got.first, s.order.first, reason: '1순위');
      expect(got, s.order, reason: '전체 순서');
      for (final id in s.excluded) {
        expect(got, isNot(contains(id)), reason: '$id 는 추천하지 않아야 한다');
      }
      // 표의 병원은 모두 포함 또는 제외 어느 한쪽에 적혀 있어야 한다.
      expect({...s.order, ...s.excluded}, {for (final h in s.hospitals) h.id},
          reason: '표에 넣은 병원은 모두 기대 순서나 제외 목록에 있어야 한다');

      Recommendation of(String id) => results.firstWhere((r) => r.hospital.id == id);
      s.reasons.forEach((id, texts) {
        for (final text in texts) {
          expect(of(id).reasons, contains(text), reason: '$id 추천 이유');
        }
      });
      s.exactReasons.forEach((id, texts) => expect(of(id).reasons, texts, reason: '$id 추천 이유 전체'));
      s.present.forEach((id, f) => expect(of(id).present, f, reason: '$id 있는 시설'));
      s.missing.forEach((id, f) => expect(of(id).missing, f, reason: '$id 없다고 확인된 시설'));
      s.unknown.forEach((id, f) => expect(of(id).unknown, f, reason: '$id 정보 없는 시설'));
      s.designated.forEach((id, d) => expect(of(id).designated, d, reason: '$id 지정 기관 여부'));
    });
  }

  test('시나리오가 30개 이상이고 장애 유형·진료 목적·나이·정도를 모두 덮는다', () {
    expect(scenarios.length, greaterThanOrEqualTo(30));
    expect({for (final s in scenarios) ...s.profile.types}, DisabilityType.values.toSet());
    expect({for (final s in scenarios) s.profile.need}, CareNeed.values.toSet());
    expect({for (final s in scenarios) s.profile.age}, AgeGroup.values.toSet());
    expect({for (final s in scenarios) s.profile.severity}, Severity.values.toSet());
    expect({for (final s in scenarios) s.name}, hasLength(scenarios.length),
        reason: '시나리오 이름이 겹친다');
  });

  test('추천 이유에는 점수 숫자를 보여 주지 않는다 (기획서 7.2)', () {
    for (final s in scenarios) {
      for (final r in recommend(s.profile, s.hospitals, limit: null, weights: s.weights)) {
        for (final reason in r.reasons) {
          expect(reason, isNot(matches(RegExp(r'\d'))), reason: '${s.name}: $reason');
        }
      }
    }
  });
}
