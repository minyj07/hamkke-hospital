import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../data/regions.dart';
import 'recommender.dart' show distanceKm;

/// 현재 위치를 얻은 결과. 실패하면 [error] 에 사용자에게 보여줄 문구가 있다.
class LocationResult {
  const LocationResult(this.lat, this.lng) : error = null;
  const LocationResult.error(String this.error)
      : lat = 0,
        lng = 0;

  final double lat;
  final double lng;
  final String? error;
}

abstract class LocationService {
  Future<LocationResult> current();
}

/// 휴대폰의 위치. 위치는 거리 계산에만 쓰고 기기 밖으로 보내지 않는다.
class DeviceLocationService implements LocationService {
  @override
  Future<LocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        return const LocationResult.error('휴대폰의 위치 기능이 꺼져 있어요. 켠 다음 다시 눌러 주세요.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied) {
        return const LocationResult.error('위치 권한을 허용해야 현재 위치로 찾을 수 있어요.');
      }
      if (permission == LocationPermission.deniedForever) {
        return const LocationResult.error(
            '설정 > 애플리케이션 > 함께병원 > 권한에서 위치를 허용해 주세요.');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 20),
        ),
      );
      return LocationResult(p.latitude, p.longitude);
    } catch (_) {
      return const LocationResult.error(
          '현재 위치를 알 수 없어요. 잠시 뒤 다시 하거나 지역을 직접 골라 주세요.');
    }
  }
}

/// 현재 위치에서 가장 가까운 시·도와, 경계 근처라 함께 찾을 이웃 시·도.
/// 가장 가까운 시·군·구 중심도 [maxKm] 보다 멀면(해외 등) null 이다.
({Region region, List<Region> nearby})? regionsNear(
  List<Region> regions,
  double lat,
  double lng, {
  double borderKm = 15,
  double maxKm = 100,
}) {
  double closest(Region r) {
    final areas = r.districts.isEmpty ? [r] : r.districts;
    return areas.map((a) => distanceKm(lat, lng, a.lat, a.lng)).reduce(min);
  }

  final ranked = [for (final r in regions) (r, closest(r))]
    ..sort((a, b) => a.$2.compareTo(b.$2));
  if (ranked.isEmpty || ranked.first.$2 > maxKm) return null;
  return (
    region: ranked.first.$1,
    nearby: [
      for (final (r, km) in ranked.skip(1))
        if (km <= borderKm) r,
    ],
  );
}
