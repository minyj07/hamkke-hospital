/// 추천 점수표. 병원 데이터와 함께 받는 scoring.json (원본은 data/scoring.json) 으로
/// 앱을 업데이트하지 않고 조정할 수 있다. 파일에 없는 값은 [standard] 를 쓴다.
class ScoreWeights {
  const ScoreWeights({
    this.designated = 50,
    this.coreDepartment = 20,
    this.coreDepartmentMax = 2,
    this.generalDepartment = 5,
    this.generalDepartmentMax = 2,
    this.specialist = 15,
    this.child = 10,
    this.facility = 8,
    this.facilityMissing = 6,
    this.chosenFacility = 12,
    this.chosenFacilityMissing = 10,
    this.regionalPerKm = 0.2,
    this.regionalMaxPenalty = 30,
    this.localPerKm = 2,
  });

  static const standard = ScoreWeights();

  /// 찾는 진료에 맞는 정부 지정 기관.
  final double designated;

  /// 장애 유형·진료에 꼭 맞는 과 하나마다, 최대 [coreDepartmentMax] 개까지.
  final double coreDepartment;
  final int coreDepartmentMax;

  /// 누구에게나 더하는 내과·가정의학과 하나마다, 최대 [generalDepartmentMax] 개까지.
  final double generalDepartment;
  final int generalDepartmentMax;

  /// 이름에 핵심 과를 내건 의원 (전문의 신호).
  final double specialist;

  /// 어린이일 때 소아청소년과가 있는 병원.
  final double child;

  /// 장애 유형으로 정한 편의시설이 있을 때 더하고, 없다고 확인되면 뺀다. 정보가 없으면 그대로 둔다.
  final double facility;
  final double facilityMissing;

  /// 사용자가 직접 고른 편의시설.
  final double chosenFacility;
  final double chosenFacilityMissing;

  /// 권역 지정 기관은 멀어도 갈 만하므로 1km 마다 조금만 빼고 [regionalMaxPenalty] 까지만 뺀다.
  final double regionalPerKm;
  final double regionalMaxPenalty;

  /// 동네 병원은 1km 마다 뺀다.
  final double localPerKm;

  factory ScoreWeights.fromJson(Map<String, dynamic> json) {
    const s = standard;
    double read(String key, double fallback) => (json[key] as num?)?.toDouble() ?? fallback;
    return ScoreWeights(
      designated: read('designated', s.designated),
      coreDepartment: read('coreDepartment', s.coreDepartment),
      coreDepartmentMax: read('coreDepartmentMax', s.coreDepartmentMax.toDouble()).toInt(),
      generalDepartment: read('generalDepartment', s.generalDepartment),
      generalDepartmentMax:
          read('generalDepartmentMax', s.generalDepartmentMax.toDouble()).toInt(),
      specialist: read('specialist', s.specialist),
      child: read('child', s.child),
      facility: read('facility', s.facility),
      facilityMissing: read('facilityMissing', s.facilityMissing),
      chosenFacility: read('chosenFacility', s.chosenFacility),
      chosenFacilityMissing: read('chosenFacilityMissing', s.chosenFacilityMissing),
      regionalPerKm: read('regionalPerKm', s.regionalPerKm),
      regionalMaxPenalty: read('regionalMaxPenalty', s.regionalMaxPenalty),
      localPerKm: read('localPerKm', s.localPerKm),
    );
  }

  Map<String, num> toJson() => {
        'designated': designated,
        'coreDepartment': coreDepartment,
        'coreDepartmentMax': coreDepartmentMax,
        'generalDepartment': generalDepartment,
        'generalDepartmentMax': generalDepartmentMax,
        'specialist': specialist,
        'child': child,
        'facility': facility,
        'facilityMissing': facilityMissing,
        'chosenFacility': chosenFacility,
        'chosenFacilityMissing': chosenFacilityMissing,
        'regionalPerKm': regionalPerKm,
        'regionalMaxPenalty': regionalMaxPenalty,
        'localPerKm': localPerKm,
      };
}
