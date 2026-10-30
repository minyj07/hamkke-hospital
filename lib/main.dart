import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_naver_map/flutter_naver_map.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:quick_actions/quick_actions.dart';
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
import 'ui/theme.dart';
import 'ui/tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _registerFontLicense();
  final repository = LocalHospitalRepository(DataStore(
    baseUrl: dataBaseUrl.isEmpty ? null : Uri.parse(dataBaseUrl),
  ));
  // 글자 크기·잠금·첫 실행 안내는 첫 화면부터 필요하므로 먼저 읽는다.
  final settings = AppSettings(FileSettingsStore());
  final (_, mapEnabled, appVersion) =
      await (settings.load(), _initMap(), _appVersion()).wait;
  final services = AppServices(
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
  );
  runApp(HamkkeApp(services: services));
  _keepUpdated(repository);
  unawaited(_setUpShortcuts(services));
}

/// 휴대폰 홈 화면에서 앱 아이콘을 길게 누르면 나오는 바로가기(병원 찾기, 진료 카드 보여 주기, 즐겨찾기)를
/// 등록한다. 누르면 [AppServices.shortcut] 에 넣고, 탭 화면이 그 화면을 연다.
Future<void> _setUpShortcuts(AppServices services) async {
  try {
    final actions = QuickActions();
    await actions.initialize((type) {
      services.shortcut.value = AppShortcut.values.asNameMap()[type];
    });
    await actions.setShortcutItems([
      for (final s in AppShortcut.values)
        ShortcutItem(type: s.name, localizedTitle: s.label, icon: s.icon),
    ]);
  } catch (e) {
    debugPrint('홈 화면 바로가기를 만들지 못했어요: $e');
  }
}

/// 앱에 넣은 Pretendard 글꼴(SIL OFL)의 라이선스를 설정의 '오픈소스 라이선스'에 보여 준다.
void _registerFontLicense() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(
      const ['Pretendard'],
      await rootBundle.loadString('assets/fonts/OFL.txt'),
    );
  });
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

  @override
  Widget build(BuildContext context) {
    final settings = services.settings;
    // 색·글꼴은 lib/ui/theme.dart (메디움 디자인). 고대비 모드면 글씨와 초록을 더 진하게 한다.
    ThemeData theme(Brightness b, {bool? highContrast}) =>
        mediumTheme(b, highContrast: highContrast ?? settings.highContrast);
    return AppScope(
      services: services,
      child: ListenableBuilder(
        listenable: settings,
        builder: (context, _) => MaterialApp(
          title: appName,
          debugShowCheckedModeBanner: false,
          // 앱은 한국어만 쓴다. 뒤로 가기 버튼의 '뒤로'처럼 Material 이 넣는 라벨도
          // 휴대폰 언어와 상관없이 한국어로 보이고 읽힌다.
          locale: const Locale('ko'),
          supportedLocales: const [Locale('ko'), Locale('en')],
          localizationsDelegates: GlobalMaterialLocalizations.delegates,
          // 휴대폰이 다크 모드면 어두운 색을 쓴다 (디자인은 밝은 화면만 있어 같은 원칙으로 맞췄다).
          theme: theme(Brightness.light),
          darkTheme: theme(Brightness.dark),
          // 휴대폰에서 대비 높이기를 켜도 고대비로 보여 준다.
          highContrastTheme: theme(Brightness.light, highContrast: true),
          highContrastDarkTheme: theme(Brightness.dark, highContrast: true),
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
