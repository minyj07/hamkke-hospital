import '../models/hospital.dart';

/// 화면에 보여 줄 거리 (예: 약 1.4km).
String kmLabel(double km) => '약 ${km.toStringAsFixed(1)}km';

/// 꼬리표에 쓰는 짧은 지정 기관 이름 (예: '장애인 건강주치의' → '건강주치의').
String categoryTag(InstitutionCategory c) => switch (c) {
      InstitutionCategory.rehabHospital => '권역재활병원',
      InstitutionCategory.rehabDesignated => '재활의료기관',
      InstitutionCategory.childRehab => '어린이재활',
      InstitutionCategory.friendlyCheckup => '장애친화 검진',
      InstitutionCategory.dentalCenter => '구강진료센터',
      InstitutionCategory.primaryCare => '건강주치의',
      InstitutionCategory.dentalPrimaryCare => '치과 주치의',
      InstitutionCategory.friendlyObgyn => '장애친화 산부인과',
      InstitutionCategory.mentalHealthCenter => '국립 정신건강',
    };

/// 병원 꼬리표: 지정 기관과 있다고 확인된 편의시설, 앞에서 [max] 개.
List<String> hospitalTags(Hospital h, {int max = 3}) => [
      for (final c in InstitutionCategory.values)
        if (h.categories.contains(c)) categoryTag(c),
      for (final f in Facility.values)
        if (h.facilities.contains(f)) f.label,
    ].take(max).toList();
