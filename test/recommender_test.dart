import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/regions.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/user_profile.dart';
import 'package:hamkke_hospital/services/recommender.dart';

const seoul = Region(code: '110000', name: '서울특별시', lat: 37.5665, lng: 126.978);

/// 서울 중심에서 동쪽으로 약 [km] 떨어진 병원.
Hospital hospital(
  String id, {
  double km = 0,
  Set<String> departments = const {},
  Set<InstitutionCategory> categories = const {},
  Set<Facility> facilities = const {},
}) =>
    Hospital(
      id: id,
      name: id,
      address: '',
      lat: seoul.lat,
      lng: seoul.lng + km / 88.2,
      departments: departments,
      categories: categories,
      facilities: facilities,
    );

UserProfile profile(
  Set<DisabilityType> types,
  CareNeed need, {
  Severity severity = Severity.severe,
}) =>
    UserProfile(types: types, severity: severity, need: need, region: seoul);

List<String> ids(List<Recommendation> results) =>
    [for (final r in results) r.hospital.id];

void main() {
  group('buildRequirement', () {
    test('지체장애(심한) 재활 → 재활병원 + 휠체어·리프트', () {
      final req = buildRequirement(profile({DisabilityType.physical}, CareNeed.rehab));
      expect(req.categories, {
        InstitutionCategory.rehabHospital,
        InstitutionCategory.rehabDesignated,
      });
      expect(req.departments, contains('재활의학과'));
      expect(req.facilities, containsAll([Facility.wheelchair, Facility.lift]));
    });

    test('기타에 아이·소아를 쓰면 어린이 재활 기관도 찾는다', () {
      final child = buildRequirement(UserProfile(
        types: {DisabilityType.brainLesion, DisabilityType.other},
        otherDisability: '아이 뇌성마비',
        severity: Severity.severe,
        need: CareNeed.rehab,
        region: seoul,
      ));
      expect(child.categories, contains(InstitutionCategory.childRehab));
      final adult = buildRequirement(profile({DisabilityType.brainLesion}, CareNeed.rehab));
      expect(adult.categories, isNot(contains(InstitutionCategory.childRehab)));
    });

    test('지체장애(심하지 않은)는 리프트를 요구하지 않는다', () {
      final req = buildRequirement(profile(
        {DisabilityType.physical},
        CareNeed.rehab,
        severity: Severity.mild,
      ));
      expect(req.facilities, isNot(contains(Facility.lift)));
    });

    test('자폐성장애 치과 → 구강진료센터·치과 주치의 + 진정치료', () {
      final req = buildRequirement(profile(
        {DisabilityType.autism},
        CareNeed.dental,
        severity: Severity.mild,
      ));
      expect(req.categories, {
        InstitutionCategory.dentalCenter,
        InstitutionCategory.dentalPrimaryCare,
      });
      expect(req.facilities, containsAll([Facility.sedation, Facility.quietRoom]));
    });

    test('만성질환 관리는 의과 주치의만 찾고 치과 주치의는 찾지 않는다', () {
      final req = buildRequirement(profile({DisabilityType.physical}, CareNeed.chronic));
      expect(req.categories, {InstitutionCategory.primaryCare});
    });

    test('청각장애 일반진료 → 수어 통역, 이비인후과', () {
      final req = buildRequirement(profile({DisabilityType.hearing}, CareNeed.general));
      expect(req.facilities, contains(Facility.signLanguage));
      expect(req.departments, contains('이비인후과'));
    });

    test('신장장애 만성질환 → 내과(심평원에는 신장내과가 따로 없다) + 인공신장실', () {
      final req = buildRequirement(profile({DisabilityType.kidney}, CareNeed.chronic));
      expect(req.facilities, contains(Facility.dialysis));
      expect(req.departments, contains('내과'));
      expect(req.departments.every(departmentNames.containsValue), isTrue);
    });

    test('모든 유형·진료 조합의 진료과가 실제 데이터의 진료과 이름에 있다', () {
      for (final t in DisabilityType.values) {
        for (final n in CareNeed.values) {
          final req = buildRequirement(profile({t}, n));
          expect(req.departments.every(departmentNames.containsValue), isTrue,
              reason: '${t.label} / ${n.label}: ${req.departments}');
        }
      }
    });
  });

  group('recommend', () {
    test('관련 없는 병원은 빼고, 지정 기관을 일반 병원보다 위에 둔다', () {
      final results = recommend(profile({DisabilityType.physical}, CareNeed.rehab), [
        hospital('안과', departments: {'안과'}),
        hospital('재활의학과의원', departments: {'재활의학과'}),
        hospital(
          '재활병원',
          departments: {'재활의학과'},
          categories: {InstitutionCategory.rehabHospital},
          facilities: {Facility.wheelchair, Facility.parking, Facility.toilet, Facility.lift},
        ),
      ]);
      expect(ids(results), ['재활병원', '재활의학과의원']);
      expect(results.first.missing, isEmpty);
      expect(results.last.missing, contains(Facility.wheelchair));
    });

    test('같은 조건이면 가까운 병원이 먼저 나온다', () {
      final results = recommend(profile({DisabilityType.visual}, CareNeed.general), [
        hospital('먼 안과', km: 300, departments: {'안과'}),
        hospital('가까운 안과', km: 1, departments: {'안과'}),
      ]);
      expect(ids(results), ['가까운 안과', '먼 안과']);
      expect(results.last.distanceKm, closeTo(300, 5));
    });

    test('장애 유형에 맞는 과가 있는 가까운 의원을 멀리 있는 내과 전문의보다 먼저 둔다', () {
      final results = recommend(profile({DisabilityType.visual}, CareNeed.general), [
        hospital('장사랑연합내과의원', km: 7.6, departments: {'안과', '가정의학과', '내과'}),
        hospital('삼성바른의원', km: 0.7, departments: {'안과', '가정의학과', '내과'}),
        hospital('밝은안과의원', km: 2, departments: {'안과'}),
        hospital('동네가정의학과의원', km: 0.3, departments: {'가정의학과'}),
      ]);
      expect(ids(results), ['밝은안과의원', '삼성바른의원', '장사랑연합내과의원', '동네가정의학과의원']);
      expect(results.first.reasons, contains('안과 전문의 진료'));
      expect(results[2].reasons, isNot(contains('내과 전문의 진료')));
    });

    test('권역 재활병원은 멀어도 동네 의원보다 위에 둔다', () {
      final results = recommend(profile({DisabilityType.physical}, CareNeed.rehab), [
        hospital('동네 재활의학과', km: 1, departments: {'재활의학과'}),
        hospital(
          '권역 재활병원',
          km: 100,
          departments: {'재활의학과'},
          categories: {InstitutionCategory.rehabHospital},
        ),
      ]);
      expect(ids(results).first, '권역 재활병원');
    });

    test('건강주치의라도 너무 멀면 가까운 의원이 먼저 나온다', () {
      final results = recommend(profile({DisabilityType.physical}, CareNeed.chronic), [
        hospital('먼 주치의', km: 40, categories: {InstitutionCategory.primaryCare}),
        hospital('가까운 주치의', km: 3, categories: {InstitutionCategory.primaryCare}),
        hospital('가까운 내과', km: 1, departments: {'내과'}),
      ]);
      expect(ids(results), ['가까운 주치의', '가까운 내과', '먼 주치의']);
    });

    test('시·군·구를 고르면 그 중심에서 거리를 잰다', () {
      const east = Area('동쪽구', 37.5665, 127.2);
      final p = UserProfile(
        types: {DisabilityType.visual},
        severity: Severity.mild,
        need: CareNeed.general,
        region: seoul,
        district: east,
      );
      final results = recommend(p, [
        hospital('서울 중심 안과', departments: {'안과'}),
        hospital('동쪽 안과', km: 19.5, departments: {'안과'}),
      ]);
      expect(ids(results).first, '동쪽 안과');
    });
  });

  group('advertisesSpecialty', () {
    test('이름에 진료과를 내건 의원을 알아본다', () {
      expect(advertisesSpecialty('바른성모재활의학과의원', '재활의학과'), isTrue);
      expect(advertisesSpecialty('청담산부인과의원', '재활의학과'), isFalse);
      expect(advertisesSpecialty('서울외과의원', '외과'), isTrue);
    });

    test('정형외과·성형외과 속의 외과는 외과로 보지 않는다', () {
      expect(advertisesSpecialty('가톨릭정형외과의원', '외과'), isFalse);
      expect(advertisesSpecialty('가톨릭정형외과의원', '정형외과'), isTrue);
      expect(advertisesSpecialty('강남심장혈관흉부외과의원', '외과'), isFalse);
    });

    test('치과의원은 모두 치과라는 이름을 쓰므로 신호로 쓰지 않는다', () {
      expect(advertisesSpecialty('미소치과의원', '치과'), isFalse);
    });

    test('조금 멀어도 전문의 의원이 먼저 나온다', () {
      final results = recommend(profile({DisabilityType.physical}, CareNeed.rehab), [
        hospital('청담산부인과의원', km: 0.5, departments: {'재활의학과', '산부인과'}),
        hospital('바른성모재활의학과의원', km: 2, departments: {'재활의학과'}),
      ]);
      expect(ids(results).first, '바른성모재활의학과의원');
      expect(results.first.reasons, contains('재활의학과 전문의 진료'));
    });
  });

  test('Hospital.fromJson 은 빌드 스크립트의 압축 형식을 읽는다', () {
    final h = Hospital.fromJson({
      'id': 'abc',
      'n': '함께의원',
      'k': '의원',
      'a': '서울특별시 중구 세종대로 110',
      'p': '02-000-0000',
      'd': '중구',
      'y': 37.5665,
      'x': 126.978,
      'dp': ['01', '21', '99'],
      'c': ['primaryCare', 'rehabDesignated'],
      'nt': ['장애인 건강주치의 (주장애관리)'],
    });
    expect(h.departments, {'내과', '재활의학과'});
    expect(h.categories,
        {InstitutionCategory.primaryCare, InstitutionCategory.rehabDesignated});
    expect(h.notes, ['장애인 건강주치의 (주장애관리)']);
    expect(h.facilities, isEmpty);
  });

  test('Hospital.fromJson 은 새 데이터에 앱이 모르는 종류가 있어도 건너뛰고 읽는다', () {
    final h = Hospital.fromJson({
      'id': 'abc',
      'n': '함께의원',
      'a': '서울특별시 중구 세종대로 110',
      'y': 37.5665,
      'x': 126.978,
      'c': ['primaryCare', 'futureCategory'],
      'f': ['wheelchair', 'futureFacility'],
    });
    expect(h.categories, {InstitutionCategory.primaryCare});
    expect(h.facilities, {Facility.wheelchair});
  });
}
