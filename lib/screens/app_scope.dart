import 'package:flutter/widgets.dart';

import '../ai/intent_model.dart';
import '../data/app_settings.dart';
import '../data/care_card_store.dart';
import '../data/hospital_repository.dart';
import '../data/last_search_store.dart';
import '../data/saved_hospitals.dart';
import '../services/app_lock.dart';
import '../services/location.dart';

Future<void> _keepScreenOnNoop(bool on) async {}

/// 휴대폰 홈 화면의 앱 바로가기 (아이콘을 길게 누르면 나온다). [name] 이 바로가기 종류 이름이다.
enum AppShortcut {
  find('병원 찾기', 'ic_shortcut_find'),
  card('진료 카드 보여 주기', 'ic_shortcut_card'),
  favorites('즐겨찾기', 'ic_shortcut_star');

  const AppShortcut(this.label, this.icon);

  final String label;

  /// 안드로이드 drawable 이름 (android/app/src/main/res/drawable).
  final String icon;
}

/// 화면들이 함께 쓰는 데이터와 기기 기능. 앱에 하나만 두고 [AppScope] 로 내려 준다.
class AppServices {
  AppServices({
    required this.repository,
    required this.locationService,
    required this.lastSearch,
    required this.favorites,
    required this.recent,
    required this.careCard,
    required this.settings,
    required this.appLock,
    this.mapEnabled = false,
    this.appVersion = '',
    this.contactEmail = '',
    this.keepScreenOn = _keepScreenOnNoop,
    IntentService? intent,
  }) : intent = intent ?? IntentService();

  final HospitalRepository repository;
  final LocationService locationService;
  final LastSearch lastSearch;
  final Favorites favorites;
  final RecentHospitals recent;
  final SavedCareCard careCard;
  final AppSettings settings;
  final AppLock appLock;

  /// 지도 키가 있어 추천 결과를 지도로 볼 수 있는지.
  final bool mapEnabled;

  /// 정보 오류 신고와 설정 화면에 보여 줄 앱 버전 (예: 1.0.0 (1)).
  final String appVersion;

  /// 신고·문의를 받는 메일 주소. 비어 있으면 신고·문의 버튼을 숨긴다.
  final String contactEmail;

  /// 진료 카드를 보여 주는 동안 화면이 꺼지지 않게 한다.
  final Future<void> Function(bool on) keepScreenOn;

  /// 휴대폰 안에서 도는 상황 이해 AI ('AI로 말해서 찾기').
  final IntentService intent;

  /// '내 정보 전부 지우기'를 할 때마다 1씩 오른다. 화면에 남은 장애 정보도 비우게 한다.
  final personalDataCleared = ValueNotifier(0);

  /// 휴대폰 홈 화면에서 앱 아이콘을 길게 눌러 고른 바로가기 ([AppShortcut]). 탭 화면이 받아서 연 뒤 비운다.
  /// 앱이 꺼져 있을 때 누르면 탭 화면이 생기기 전에 들어오므로, 값으로 들고 있다가 탭 화면이 생길 때 연다.
  final shortcut = ValueNotifier<AppShortcut?>(null);

  /// 진료 카드, 지난번 검색 조건, 즐겨찾기, 최근 본 병원을 지운다. 화면 설정은 남긴다.
  Future<void> clearPersonalData() async {
    await Future.wait([careCard.clear(), lastSearch.clear(), favorites.clear(), recent.clear()]);
    personalDataCleared.value++;
  }
}

class AppScope extends InheritedWidget {
  const AppScope({super.key, required this.services, required super.child});

  final AppServices services;

  /// 서비스는 앱이 도는 동안 바뀌지 않으므로 의존 관계를 만들지 않는다 (initState 에서도 쓸 수 있다).
  static AppServices of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.services;

  @override
  bool updateShouldNotify(AppScope oldWidget) => !identical(services, oldWidget.services);
}
