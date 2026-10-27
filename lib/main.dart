import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import 'config.dart';
import 'data/app_settings.dart';
import 'data/care_card_store.dart';
import 'data/data_store.dart';
import 'data/hospital_repository.dart';
import 'data/last_search_store.dart';
import 'data/saved_hospitals.dart';
import 'screens/app_scope.dart';
import 'screens/app_shell.dart';
import 'screens/lock_gate.dart';
import 'screens/onboarding_screen.dart';
import 'services/app_lock.dart';
import 'services/location.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = LocalHospitalRepository(DataStore(
    baseUrl: dataBaseUrl.isEmpty ? null : Uri.parse(dataBaseUrl),
  ));
  // 글자 크기·잠금·첫 실행 안내는 첫 화면부터 필요하므로 먼저 읽는다.
  final settings = AppSettings(FileSettingsStore());
  final (_, mapEnabled, appVersion) =
      await (settings.load(), _initMap(), _appVersion()).wait;
  runApp(HamkkeApp(
    services: AppServices(
      repository: repository,
      locationService: DeviceLocationService(),
      lastSearch: LastSearch(FileLastSearchStore()),
      favorites: Favorites(FileSavedHospitalsStore(favoritesFileName)),
      recent: RecentHospitals(FileSavedHospitalsStore(recentFileName)),
      careCard: SavedCareCard(SecureCareCardStore()),
      settings: settings,
      appLock: DeviceAppLock(),
      mapEnabled: mapEnabled,
      appVersion: appVersion,
      contactEmail: contactEmail,
      keepScreenOn: _keepScreenOn,
    ),
  ));
  _keepUpdated(repository);
}

/// 지도 키가 있으면 네이버 지도를 쓸 준비를 한다. 쓸 수 있으면 true.
Future<bool> _initMap() async {
  if (naverMapClientId.isEmpty) return false;
  try {
    await FlutterNaverMap().init(
      clientId: naverMapClientId,
      onAuthFailed: (e) => debugPrint('네이버 지도 인증에 실패했어요: $e'),
    );
    return true;
  } catch (e) {
    debugPrint('네이버 지도를 쓸 수 없어요: $e');
    return false;
  }
}

Future<String> _appVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return '${info.version} (${info.buildNumber})';
  } catch (_) {
    return '';
  }
}

Future<void> _keepScreenOn(bool on) async {
  try {
    await WakelockPlus.toggle(enable: on);
  } catch (e) {
    debugPrint('화면 켜 두기를 바꾸지 못했어요: $e');
  }
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
  const HamkkeApp({super.key, required this.services});

  final AppServices services;

  static const _seed = Color(0xFF1B6E5A);

  /// 넓은 터치 영역을 기본으로 하고, 고대비 모드면 글자와 배경의 대비를 가장 크게 한다.
  static ThemeData _theme(Brightness brightness, {required bool highContrast}) => ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: _seed,
          brightness: brightness,
          contrastLevel: highContrast ? 1.0 : 0.5,
        ),
        // 기본 밀도를 쓴다. comfortable 은 이름과 달리 더 촘촘해서(-4dp) 버튼·칩의 터치 영역이 44dp 로 줄어든다.
        visualDensity: VisualDensity.standard,
        materialTapTargetSize: MaterialTapTargetSize.padded,
      );

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: '함께병원',
          debugShowCheckedModeBanner: false,
          // 앱은 한국어만 쓴다. 뒤로 가기 버튼의 '뒤로'처럼 Material 이 넣는 라벨도
          // 휴대폰 언어와 상관없이 한국어로 보이고 읽힌다.
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          theme: _theme(Brightness.light, highContrast: settings.highContrast),
          darkTheme: _theme(Brightness.dark, highContrast: settings.highContrast),
          // 휴대폰에서 대비 높이기를 켜도 고대비로 보여 준다.
          highContrastTheme: _theme(Brightness.light, highContrast: true),
          highContrastDarkTheme: _theme(Brightness.dark, highContrast: true),
          builder: (context, child) {
            // 앱 안에서 글자 크기를 정했으면 휴대폰 설정 대신 쓴다.
            final scale = settings.textScale;
            final content = scale == null
                ? child!
                : MediaQuery(
                    data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  );
            return LockGate(child: content);
          },
          home: const _Start(),
        ),
      ),
    );
  }
}

/// 처음이면 안내를, 아니면 탭 화면을 보여 준다.
class _Start extends StatelessWidget {
  const _Start();

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return ListenableBuilder(
      listenable: settings,
      builder: (context, _) => settings.onboardingDone
          ? const AppShell()
          : OnboardingScreen(onDone: settings.finishOnboarding),
    );
  }
}
