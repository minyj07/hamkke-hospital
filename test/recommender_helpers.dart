import 'package:hamkke_hospital/data/regions.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/user_profile.dart';
import 'package:hamkke_hospital/services/recommender.dart';

// 추천기 테스트(recommender_test, recommender_scenarios_test)가 함께 쓰는 도우미.

const seoul = Region(code: '110000', name: '서울특별시', lat: 37.5665, lng: 126.978);

/// 서울 중심에서 동쪽으로 약 [km] 떨어진 병원. 이름은 [id] 와 같으므로
/// 이름에 핵심 진료과(예: 재활의학과)를 넣으면 전문의 신호(advertisesSpecialty)가 된다.
Hospital hospital(
  String id, {
  double km = 0,
  Set<String> departments = const {},
  Set<InstitutionCategory> categories = const {},
  Set<Facility> facilities = const {},
  Set<Facility> absent = const {},
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
      absentFacilities: absent,
    );

/// 서울을 기준으로 하는 사용자 조건. 정도는 심한 장애, 나이는 성인이 기본이다.
UserProfile profile(
  Set<DisabilityType> types,
  CareNeed need, {
  Severity severity = Severity.severe,
  AgeGroup age = AgeGroup.adult,
  Set<Facility>? chosenFacilities,
  String otherDisability = '',
  String otherNeed = '',
  Area? location,
}) =>
    UserProfile(
      types: types,
      otherDisability: otherDisability,
      severity: severity,
      need: need,
      otherNeed: otherNeed,
      age: age,
      chosenFacilities: chosenFacilities,
      region: seoul,
      location: location,
    );

List<String> ids(List<Recommendation> results) =>
    [for (final r in results) r.hospital.id];
