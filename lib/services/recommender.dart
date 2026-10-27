import 'dart:math';

import '../data/regions.dart';
import '../models/disability.dart';
import '../models/hospital.dart';
import '../models/user_profile.dart';
import 'keywords.dart';

/// 사용자 조건에서 뽑아낸 "이런 병원이면 좋다"는 요구사항.
class CareRequirement {
  const CareRequirement({
    required this.categories,
    required this.departments,
    required this.facilities,
    Set<String>? coreDepartments,
    this.unmatchedTexts = const [],
  }) : coreDepartments = coreDepartments ?? departments;

  /// 정부 지정 기관 종류. 하나라도 맞으면 크게 가산한다.
  final Set<InstitutionCategory> categories;

  /// 추천 대상이 되는 진료과 전체.
  final Set<String> departments;

  /// 그중 장애 유형·진료 목적에 꼭 맞는 과 (예: 시각장애의 안과).
  /// 누구에게나 더하는 내과·가정의학과보다 높이 치고, 전문의 가산점도 이 과에만 준다.
  final Set<String> coreDepartments;

  /// 이용에 꼭 필요한 편의시설. 없으면 경고로 알려준다.
  final Set<Facility> facilities;

  /// '기타'에 입력했지만 맞는 진료과를 찾지 못한 글. 화면에서 알려준다.
  final List<String> unmatchedTexts;
}

class Recommendation {
  const Recommendation({
    required this.hospital,
    required this.score,
    required this.distanceKm,
    required this.reasons,
    required this.missing,
  });

  final Hospital hospital;
  final double score;
  final double distanceKm;

  /// 추천 이유 (화면에 그대로 보여준다).
  final List<String> reasons;

  /// 필요한데 이 병원에 없는 편의시설.
  final List<Facility> missing;
}

const _departmentsByType = <DisabilityType, Set<String>>{
  DisabilityType.physical: {'재활의학과', '정형외과'},
  DisabilityType.brainLesion: {'재활의학과', '신경과'},
  DisabilityType.visual: {'안과'},
  DisabilityType.hearing: {'이비인후과'},
  DisabilityType.speech: {'이비인후과', '재활의학과'},
  DisabilityType.intellectual: {'정신건강의학과'},
  DisabilityType.autism: {'정신건강의학과'},
  DisabilityType.mental: {'정신건강의학과'},
  // 심평원 진료과목에는 신장·순환기·호흡기·소화기내과 같은 세부 과가 없고 모두 내과다.
  DisabilityType.kidney: {'내과'},
  DisabilityType.heart: {'내과'},
  DisabilityType.respiratory: {'내과'},
  DisabilityType.liver: {'내과'},
  DisabilityType.facial: {'성형외과'},
  DisabilityType.ostomy: {'외과', '비뇨의학과'},
  DisabilityType.epilepsy: {'신경과'},
};

/// 치과 진료 시 진정 치료나 전문 센터가 특히 필요한 유형.
const _needsSpecialDental = {
  DisabilityType.intellectual,
  DisabilityType.autism,
  DisabilityType.brainLesion,
};

const _mobilityTypes = {DisabilityType.physical, DisabilityType.brainLesion};

/// 일반 진료·만성질환 관리에서 누구에게나 더하는 진료과.
const _generalDepartments = {'가정의학과', '내과'};

/// 권역마다 몇 곳 없어서 멀어도 찾아갈 만한 지정 기관.
const _regionalCategories = {
  InstitutionCategory.rehabHospital,
  InstitutionCategory.rehabDesignated,
  InstitutionCategory.childRehab,
  InstitutionCategory.friendlyCheckup,
  InstitutionCategory.dentalCenter,
  InstitutionCategory.friendlyObgyn,
};

CareRequirement buildRequirement(UserProfile p) {
  final severe = p.severity == Severity.severe;
  final categories = <InstitutionCategory>{};
  final departments = <String>{};
  final facilities = <Facility>{};

  final unmatchedTexts = <String>[];
  Set<String> fromText(String text) {
    final found = departmentsFromText(text, departmentNames.values);
    if (found.isEmpty && text.trim().isNotEmpty) unmatchedTexts.add(text.trim());
    return found;
  }

  final typeDepartments = {
    for (final t in p.types) ...?_departmentsByType[t],
    if (p.types.contains(DisabilityType.other)) ...fromText(p.otherDisability),
  };

  var core = <String>{};
  switch (p.need) {
    case CareNeed.general:
      core = typeDepartments;
      departments.addAll({...typeDepartments, ..._generalDepartments});
    case CareNeed.rehab:
      categories.addAll({
        InstitutionCategory.rehabHospital,
        InstitutionCategory.rehabDesignated,
      });
      // 나이를 따로 묻지 않으므로 '기타'에 아이·소아 등을 썼을 때만 어린이 재활 기관을 찾는다.
      final forChild = [p.otherDisability, p.otherNeed].any((text) =>
          departmentsFromText(text, departmentNames.values).contains('소아청소년과'));
      if (forChild) categories.add(InstitutionCategory.childRehab);
      departments.add('재활의학과');
    case CareNeed.checkup:
      categories.add(InstitutionCategory.friendlyCheckup);
      departments.add('가정의학과');
    case CareNeed.dental:
      categories.add(InstitutionCategory.dentalPrimaryCare);
      if (severe || p.types.any(_needsSpecialDental.contains)) {
        categories.add(InstitutionCategory.dentalCenter);
      }
      if (p.types.any(_needsSpecialDental.contains)) {
        facilities.add(Facility.sedation);
      }
      departments.add('치과');
    case CareNeed.chronic:
      categories.add(InstitutionCategory.primaryCare);
      core = typeDepartments;
      departments.addAll({...typeDepartments, ..._generalDepartments});
      if (p.types.contains(DisabilityType.kidney)) {
        facilities.add(Facility.dialysis);
      }
    case CareNeed.pregnancy:
      categories.add(InstitutionCategory.friendlyObgyn);
      departments.add('산부인과');
    case CareNeed.mentalHealth:
      categories.add(InstitutionCategory.mentalHealthCenter);
      departments.add('정신건강의학과');
    case CareNeed.other:
      final wanted = fromText(p.otherNeed);
      // 입력한 글에서 진료과를 못 찾으면 일반 진료처럼 찾는다.
      core = wanted.isNotEmpty ? wanted : typeDepartments;
      departments.addAll(
          wanted.isNotEmpty ? wanted : {...typeDepartments, ..._generalDepartments});
  }

  // 유형별로 병원 이용에 필요한 편의시설.
  if (p.types.any(_mobilityTypes.contains)) {
    facilities.addAll({Facility.wheelchair, Facility.parking, Facility.toilet});
    if (severe) facilities.add(Facility.lift);
  }
  if (p.types.contains(DisabilityType.ostomy)) facilities.add(Facility.toilet);
  if (p.types.contains(DisabilityType.visual)) facilities.add(Facility.braille);
  if (p.types.contains(DisabilityType.hearing)) {
    facilities.add(Facility.signLanguage);
  }
  if (p.types.contains(DisabilityType.intellectual) ||
      p.types.contains(DisabilityType.autism)) {
    facilities.add(Facility.quietRoom);
  }

  return CareRequirement(
    categories: categories,
    departments: departments,
    // 진료과를 하나만 정하는 진료(재활·치과 등)는 그 과가 곧 핵심 과다.
    coreDepartments: switch (p.need) {
      CareNeed.general || CareNeed.chronic || CareNeed.other => core,
      _ => departments,
    },
    facilities: facilities,
    unmatchedTexts: unmatchedTexts,
  );
}

List<Recommendation> recommend(
  UserProfile profile,
  List<Hospital> hospitals, {
  int limit = 20,
}) {
  final req = buildRequirement(profile);
  final Area(:lat, :lng) = profile.origin;
  final results = <Recommendation>[];

  for (final h in hospitals) {
    final reasons = <String>[];
    var score = 0.0;

    final matchedCategories = req.categories.intersection(h.categories);
    final matchedDepartments = req.departments.intersection(h.departments);

    // 지정 기관도 아니고 관련 진료과도 없으면 추천하지 않는다.
    if (matchedCategories.isEmpty && matchedDepartments.isEmpty) continue;

    if (matchedCategories.isNotEmpty) {
      score += 50;
      reasons.addAll(matchedCategories.map((c) => c.label));
    }
    if (matchedDepartments.isNotEmpty) {
      final matchedCore = req.coreDepartments.intersection(h.departments);
      final matchedGeneral = matchedDepartments.difference(matchedCore);
      score += min(matchedCore.length, 2) * 20 + min(matchedGeneral.length, 2) * 5;
      reasons.add('진료과: ${[...matchedCore, ...matchedGeneral].join(', ')}');
      final specialty =
          matchedCore.where((d) => advertisesSpecialty(h.name, d));
      if (specialty.isNotEmpty) {
        score += 15;
        reasons.add('${specialty.first} 전문의 진료');
      }
    }

    final matchedFacilities = req.facilities.intersection(h.facilities);
    score += matchedFacilities.length * 8;
    if (matchedFacilities.isNotEmpty) {
      reasons.add('편의시설: ${matchedFacilities.map((f) => f.label).join(', ')}');
    }
    final missing = req.facilities.difference(h.facilities).toList();
    score -= missing.length * 6;

    final km = distanceKm(lat, lng, h.lat, h.lng);
    // 권역 지정 기관은 멀어도 갈 가치가 있지만, 동네 병원은 가까울수록 좋다.
    final regional = matchedCategories.any(_regionalCategories.contains);
    score -= regional ? min(km * 0.2, 30.0) : km * 2;

    results.add(Recommendation(
      hospital: h,
      score: score,
      distanceKm: km,
      reasons: reasons,
      missing: missing,
    ));
  }

  results.sort((a, b) => b.score.compareTo(a.score));
  return results.take(limit).toList();
}

/// '외과'를 찾을 때 이 이름들 속의 '외과'는 빼고 본다.
const _longerDepartmentNames = ['정형외과', '성형외과', '신경외과', '흉부외과', '구강악안면외과'];

/// 병원 이름에 진료과목을 내걸었는지. 의료법상 의원 이름에 진료과목을 넣으려면
/// 그 과 전문의여야 하므로 전문의가 진료한다는 신호로 쓴다.
/// 치과의원은 모두 이름에 '치과'가 들어가므로 신호가 되지 않는다.
bool advertisesSpecialty(String hospitalName, String department) {
  if (department == '치과') return false;
  var name = hospitalName;
  for (final longer in _longerDepartmentNames) {
    if (longer != department && longer.contains(department)) {
      name = name.replaceAll(longer, '');
    }
  }
  return name.contains(department);
}

/// 두 좌표 사이 직선거리 (하버사인 공식).
double distanceKm(double lat1, double lng1, double lat2, double lng2) {
  const earthRadiusKm = 6371.0;
  double rad(double d) => d * pi / 180;
  final dLat = rad(lat2 - lat1);
  final dLng = rad(lng2 - lng1);
  final a = sin(dLat / 2) * sin(dLat / 2) +
      cos(rad(lat1)) * cos(rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
  return earthRadiusKm * 2 * atan2(sqrt(a), sqrt(1 - a));
}
