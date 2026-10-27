import 'disability.dart';
import 'hospital.dart';
import '../data/regions.dart';

class UserProfile {
  const UserProfile({
    required this.types,
    required this.severity,
    required this.need,
    required this.region,
    this.age = AgeGroup.adult,
    this.chosenFacilities,
    this.district,
    this.location,
    this.nearbyRegions = const [],
    this.otherDisability = '',
    this.otherNeed = '',
  });

  /// 중복장애가 있을 수 있으므로 여러 개를 고를 수 있다.
  final Set<DisabilityType> types;

  /// '기타' 장애를 고르고 직접 입력한 내용.
  final String otherDisability;
  final Severity severity;
  final CareNeed need;

  /// '기타' 진료를 고르고 직접 입력한 내용.
  final String otherNeed;

  /// 진료받을 사람의 나이대.
  final AgeGroup age;

  /// 사용자가 직접 고른 편의시설. null 이면 장애 유형·정도·진료로 정한다.
  final Set<Facility>? chosenFacilities;

  /// 병원 데이터를 불러올 시·도. 현재 위치로 찾으면 가장 가까운 시·도다.
  final Region region;

  /// 고르지 않으면 시·도 전체를 기준으로 한다.
  final Area? district;

  /// 현재 위치. 있으면 거리의 기준점이 된다.
  final Area? location;

  /// 함께 찾을 이웃 시·도. 현재 위치가 시·도 경계 근처이거나, 결과가 없어서 넓혀 찾을 때 들어간다.
  final List<Region> nearbyRegions;

  /// 거리 계산의 기준점.
  Area get origin => location ?? district ?? region;

  /// 화면에 보여줄 장소 이름 (예: 서울특별시 강남구).
  String get placeLabel =>
      location != null ? '현재 위치' : [region.name, ?district?.name].join(' ');

  String get typesLabel => disabilityLabel(types, otherDisability);

  String get needLabel => careNeedLabel(need, otherNeed);

  /// [regions] 시·도도 함께 찾는 조건. 기준점(거리를 재는 곳)은 그대로다.
  UserProfile withNearby(List<Region> regions) => UserProfile(
        types: types,
        otherDisability: otherDisability,
        severity: severity,
        need: need,
        otherNeed: otherNeed,
        age: age,
        chosenFacilities: chosenFacilities,
        region: region,
        district: district,
        location: location,
        nearbyRegions: [...nearbyRegions, ...regions],
      );
}
