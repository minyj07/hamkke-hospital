import 'dart:async';

import 'package:flutter/material.dart';

import 'data/data_store.dart';
import 'data/hospital_repository.dart';
import 'data/last_search_store.dart';
import 'screens/profile_screen.dart';
import 'services/location.dart';

/// 최신 병원 데이터를 올려 둔 주소. .github/workflows/update-data.yml 이 GitHub Pages 에 배포한다.
/// 빌드할 때 --dart-define=DATA_BASE_URL=... 로 바꿀 수 있고, 빈 값을 주면 앱에 든 데이터만 쓴다.
const dataBaseUrl = String.fromEnvironment(
  'DATA_BASE_URL',
  defaultValue: 'https://minyj07.github.io/hamkke-hospital/v1/',
);

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LocalHospitalRepository(DataStore(
    baseUrl: dataBaseUrl.isEmpty ? null : Uri.parse(dataBaseUrl),
  ));
  runApp(HamkkeApp(
    repository: repository,
    locationService: DeviceLocationService(),
    searchStore: FileLastSearchStore(),
  ));
  _keepUpdated(repository);
}

/// 새 병원 정보는 앱을 켤 때, 그리고 오래 켜 둔 앱으로 다시 돌아올 때 확인한다.
void _keepUpdated(HospitalRepository repository) {
  var checkedAt = DateTime.now();
  unawaited(repository.update());
  AppLifecycleListener(onResume: () {
    if (DateTime.now().difference(checkedAt) < const Duration(hours: 12)) return;
    checkedAt = DateTime.now();
    unawaited(repository.update());
  });
}

class HamkkeApp extends StatelessWidget {
  const HamkkeApp({
    super.key,
    required this.repository,
    required this.locationService,
    required this.searchStore,
  });

  final HospitalRepository repository;
  final LocationService locationService;
  final LastSearchStore searchStore;

  @override
  Widget build(BuildContext context) {
    // 넓은 터치 영역·높은 대비를 기본으로 하고, 글자 크기는 휴대폰 설정을 따른다.
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF1B6E5A),
      contrastLevel: 0.5,
    );
    return MaterialApp(
      title: '함께병원',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: scheme,
        visualDensity: VisualDensity.comfortable,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF1B6E5A),
          brightness: Brightness.dark,
          contrastLevel: 0.5,
        ),
      ),
      home: ProfileScreen(
        repository: repository,
        locationService: locationService,
        searchStore: searchStore,
      ),
    );
  }
}
