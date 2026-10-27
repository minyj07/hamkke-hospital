/// 장애인복지법상 15개 장애 유형과, 직접 입력하는 '기타'.
enum DisabilityType {
  physical('지체장애'),
  brainLesion('뇌병변장애'),
  visual('시각장애'),
  hearing('청각장애'),
  speech('언어장애'),
  intellectual('지적장애'),
  autism('자폐성장애'),
  mental('정신장애'),
  kidney('신장장애'),
  heart('심장장애'),
  respiratory('호흡기장애'),
  liver('간장애'),
  facial('안면장애'),
  ostomy('장루·요루장애'),
  epilepsy('뇌전증장애'),
  other('기타');

  const DisabilityType(this.label);
  final String label;
}

/// 2019년 7월 장애등급제 폐지 이후의 구분.
enum Severity {
  severe('장애의 정도가 심한 장애인', '예전 1~3급'),
  mild('장애의 정도가 심하지 않은 장애인', '예전 4~6급');

  const Severity(this.label, this.hint);
  final String label;
  final String hint;
}

/// 사용자가 병원에 가려는 목적.
enum CareNeed {
  general('일반 진료', '아플 때 진료받을 곳'),
  rehab('재활 치료', '물리·작업·언어치료 등'),
  checkup('건강검진', '국가건강검진 포함'),
  dental('치과 진료', '충치, 스케일링 등'),
  chronic('만성질환 관리', '꾸준히 다닐 주치의'),
  pregnancy('임신·출산', '산전 검사, 분만'),
  mentalHealth('마음 건강', '상담, 정신건강의학과'),
  other('기타', '직접 입력');

  const CareNeed(this.label, this.hint);
  final String label;
  final String hint;
}

/// 진료받을 사람의 나이대. 어린이면 소아청소년과와 어린이 재활 기관을 더 높이 친다.
enum AgeGroup {
  child('어린이·청소년', '만 18세 미만'),
  adult('성인', '만 18세 이상');

  const AgeGroup(this.label, this.hint);
  final String label;
  final String hint;
}

/// 화면에 보여줄 장애 유형. '기타'는 입력한 내용을 함께 보여준다.
String disabilityLabel(Iterable<DisabilityType> types, String other) => types
    .map((t) => t == DisabilityType.other && other.isNotEmpty ? '기타($other)' : t.label)
    .join(', ');

/// 화면에 보여줄 진료. '기타'는 입력한 내용을 함께 보여준다.
String careNeedLabel(CareNeed need, String other) =>
    need == CareNeed.other && other.isNotEmpty ? '기타($other)' : need.label;
