import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/app_settings.dart';
import 'package:hamkke_hospital/data/care_card_store.dart';
import 'package:hamkke_hospital/data/data_store.dart';
import 'package:hamkke_hospital/data/hospital_repository.dart';
import 'package:hamkke_hospital/data/last_search_store.dart';
import 'package:hamkke_hospital/data/regions.dart';
import 'package:hamkke_hospital/data/saved_hospitals.dart';
import 'package:hamkke_hospital/main.dart';
import 'package:hamkke_hospital/models/care_card.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/search_conditions.dart';
import 'package:hamkke_hospital/screens/app_scope.dart';
import 'package:hamkke_hospital/services/app_lock.dart';
import 'package:hamkke_hospital/services/hospital_search.dart';
import 'package:hamkke_hospital/services/location.dart';
import 'package:hamkke_hospital/services/score_weights.dart';

// 화면 테스트가 함께 쓰는 가짜 저장소·기기 기능과 앱 만들기.

const defaultHospitals = [
  Hospital(
    id: 'h1',
    name: '강남재활의학과의원',
    region: '110000',
    kind: '의원',
    district: '강남구',
    address: '서울특별시 강남구 테헤란로 1',
    phone: '02-000-0000',
    lat: 37.5175,
    lng: 127.0470,
    doctors: 5,
    specialists: 3,
    openedYear: 2015,
    homepage: 'http://gangnam.example',
    departments: {'재활의학과'},
  ),
  Hospital(
    id: 'h2',
    name: '강남안과의원',
    region: '110000',
    address: '서울특별시 강남구 테헤란로 2',
    lat: 37.5175,
    lng: 127.0470,
    departments: {'안과'},
  ),
  Hospital(
    id: 'h3',
    name: '강남피부과의원',
    region: '110000',
    kind: '의원',
    district: '강남구',
    address: '서울특별시 강남구 테헤란로 3',
    lat: 37.5175,
    lng: 127.0470,
    departments: {'피부과'},
  ),
];

/// 경기도의 이비인후과. 서울에서 결과가 없을 때 이웃 시·도까지 넓히면 나온다.
const gyeonggiEnt = Hospital(
  id: 'g1',
  name: '성남이비인후과의원',
  region: '310000',
  kind: '의원',
  district: '성남시',
  address: '경기도 성남시 분당구 1',
  lat: 37.38,
  lng: 127.12,
  departments: {'이비인후과'},
);

class FakeRepository implements HospitalRepository {
  FakeRepository({
    this.updateResult = UpdateResult.upToDate,
    this.hospitals = defaultHospitals,
    this.neighbors = const [gyeonggiEnt],
  });

  static const gangnam = Area('강남구', 37.5172, 127.0473);

  /// update() 가 돌려줄 결과. updated 면 기준일이 2026-10-26 으로 바뀐다.
  final UpdateResult updateResult;

  /// 서울(110000)의 병원.
  final List<Hospital> hospitals;

  /// 경기(310000)의 병원.
  final List<Hospital> neighbors;
  var _generatedAt = '2026-10-07';

  @override
  Future<List<Region>> loadRegions() async => const [
        Region(
          code: '110000',
          name: '서울특별시',
          lat: 37.5665,
          lng: 126.978,
          districts: [gangnam],
        ),
        Region(code: '310000', name: '경기도', lat: 37.4, lng: 127.0),
      ];

  @override
  Future<List<Hospital>> loadHospitals(String regionCode) async =>
      regionCode == '310000' ? neighbors : hospitals;

  @override
  Future<DataInfo> loadInfo() async =>
      DataInfo(generatedAt: _generatedAt, sources: const ['테스트 자료']);

  @override
  Future<List<SearchEntry>> loadSearchIndex() async => [
        for (final h in [...hospitals, ...neighbors])
          SearchEntry(
              id: h.id, name: h.name, region: h.region, district: h.district, kind: h.kind),
      ];

  @override
  Future<ScoreWeights> loadWeights() async => ScoreWeights.standard;

  @override
  Future<Hospital?> findHospital(String region, String id) async =>
      (await loadHospitals(region)).where((h) => h.id == id).firstOrNull;

  @override
  Future<UpdateResult> update() async {
    if (updateResult == UpdateResult.updated) _generatedAt = '2026-10-26';
    return updateResult;
  }
}

/// 처음 몇 번은 읽기에 실패하는 저장소.
class FlakyRepository extends FakeRepository {
  FlakyRepository({this.regionFailures = 0, this.hospitalFailures = 0});

  int regionFailures;
  int hospitalFailures;

  @override
  Future<List<Region>> loadRegions() async {
    if (regionFailures > 0) {
      regionFailures--;
      throw StateError('지역 읽기 실패');
    }
    return super.loadRegions();
  }

  @override
  Future<List<Hospital>> loadHospitals(String regionCode) async {
    if (hospitalFailures > 0) {
      hospitalFailures--;
      throw StateError('병원 읽기 실패');
    }
    return super.loadHospitals(regionCode);
  }
}

class FakeLocationService implements LocationService {
  FakeLocationService(this.result);

  final LocationResult result;
  int calls = 0;

  @override
  Future<LocationResult> current() async {
    calls++;
    return result;
  }
}

class FakeSearchStore implements LastSearchStore {
  FakeSearchStore([this.saved]);

  SearchConditions? saved;

  @override
  Future<SearchConditions?> load() async => saved;

  @override
  Future<void> save(SearchConditions conditions) async => saved = conditions;

  @override
  Future<void> clear() async => saved = null;
}

class FakeSavedHospitalsStore implements SavedHospitalsStore {
  List<SavedHospital> saved = [];

  @override
  Future<List<SavedHospital>> load() async => saved;

  @override
  Future<void> save(List<SavedHospital> hospitals) async => saved = hospitals;
}

/// 처음 실행 안내는 본 것으로 시작한다.
class FakeSettingsStore implements SettingsStore {
  FakeSettingsStore([Map<String, dynamic>? saved])
      : saved = saved ?? {'onboardingDone': true};

  Map<String, dynamic> saved;

  @override
  Future<Map<String, dynamic>> load() async => {...saved};

  @override
  Future<void> save(Map<String, dynamic> settings) async => saved = settings;
}

class FakeCareCardStore implements CareCardStore {
  FakeCareCardStore([this.saved]);

  CareCard? saved;

  @override
  Future<CareCard?> load() async => saved;

  @override
  Future<void> save(CareCard card) async => saved = card;

  @override
  Future<void> clear() async => saved = null;
}

class FakeAppLock implements AppLock {
  FakeAppLock({this.available = true, this.succeeds = true});

  bool available;
  bool succeeds;
  int unlocks = 0;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> unlock() async {
    unlocks++;
    return succeeds;
  }
}

const gangnamRehab = SearchConditions(
  types: {DisabilityType.physical},
  severity: Severity.severe,
  need: CareNeed.rehab,
  age: AgeGroup.adult,
  regionCode: '110000',
  regionName: '서울특별시',
  districtName: '강남구',
);

/// 가짜 저장소로 앱의 서비스를 만든다. 설정은 읽어 둔다.
Future<AppServices> makeServices({
  LocationResult here = const LocationResult(37.5172, 127.0473),
  HospitalRepository? repository,
  LocationService? locationService,
  LastSearchStore? searchStore,
  SavedHospitalsStore? favoritesStore,
  SavedHospitalsStore? recentStore,
  CareCardStore? careCardStore,
  SettingsStore? settingsStore,
  AppLock? appLock,
  String contactEmail = 'help@example.com',
  List<bool>? screenOn,
}) async {
  final settings = AppSettings(settingsStore ?? FakeSettingsStore());
  await settings.load();
  return AppServices(
    repository: repository ?? FakeRepository(),
    locationService: locationService ?? FakeLocationService(here),
    lastSearch: LastSearch(searchStore ?? FakeSearchStore()),
    favorites: Favorites(favoritesStore ?? FakeSavedHospitalsStore()),
    recent: RecentHospitals(recentStore ?? FakeSavedHospitalsStore()),
    careCard: SavedCareCard(careCardStore ?? FakeCareCardStore()),
    settings: settings,
    appLock: appLock ?? FakeAppLock(),
    appVersion: '1.0.0 (1)',
    contactEmail: contactEmail,
    keepScreenOn: (on) async => screenOn?.add(on),
  );
}

/// 다른 앱(전화·지도·메일)을 여는 대신 연 주소를 모은다.
List<String> mockUrlLauncher(WidgetTester tester) {
  const channel = MethodChannel('plugins.flutter.io/url_launcher');
  final messenger = tester.binding.defaultBinaryMessenger;
  final opened = <String>[];
  messenger.setMockMethodCallHandler(channel, (call) async {
    if (call.method == 'launch') opened.add((call.arguments as Map)['url'] as String);
    return true;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
  return opened;
}

/// [services] 로 앱을 띄우고 첫 화면이 나올 때까지 기다린다.
Future<void> pumpApp(WidgetTester tester, AppServices services) async {
  await tester.pumpWidget(HamkkeApp(services: services));
  await tester.pumpAndSettle();
}

/// 하단 탭(홈·즐겨찾기·마이페이지)을 누른다. 탭 이름은 홈 바로가기·제목에도 있으므로 탭 막대 안에서 찾는다.
Future<void> tapTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// 보이는 목록을 굴려서 [text] 를 찾아 누른다. 아래에 없으면 위로도 찾는다
/// (홈처럼 다른 화면에 다녀와도 굴린 자리가 남는 목록이 있다).
Future<void> tapAndSettle(WidgetTester tester, String text) async {
  final scrollable = find.byType(Scrollable).first;
  try {
    await tester.scrollUntilVisible(find.text(text), 100, scrollable: scrollable);
  } on StateError {
    await tester.scrollUntilVisible(find.text(text), -100, scrollable: scrollable);
  }
  // 굴린 자리를 그린 뒤에 눌러야 하단 탭 막대 같은 다른 것을 누르지 않는다.
  await tester.pumpAndSettle();
  await tester.tap(find.text(text));
  await tester.pumpAndSettle();
}

/// 앱 바의 뒤로 가기를 누른다. 앱이 한국어라 툴팁이 '뒤로'이므로,
/// 영어 'Back' 툴팁을 찾는 tester.pageBack() 은 쓸 수 없다.
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byTooltip('뒤로'));
  await tester.pumpAndSettle();
}

Future<void> tapNext(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, '다음'));
  await tester.pumpAndSettle();
}

bool nextEnabled(WidgetTester tester) =>
    tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed != null;

/// 홈의 바로가기로 병원 찾기를 연다 (하단 탭에는 병원 찾기가 없다).
Future<void> openFind(WidgetTester tester) async {
  await tapTab(tester, '홈');
  await tapAndSettle(tester, '병원 찾기');
}

/// 홈의 바로가기로 나의 진료 카드 화면을 연다.
Future<void> openCard(WidgetTester tester) async {
  await tapTab(tester, '홈');
  await tapAndSettle(tester, '나의 진료 카드');
}

/// 마이페이지에서 설정을 연다.
Future<void> openSettings(WidgetTester tester) async {
  await tapTab(tester, '마이페이지');
  await tapAndSettle(tester, '설정');
}

/// 보이는 목록을 [finder] 가 보일 때까지 굴린다.
Future<void> scrollTo(WidgetTester tester, Finder finder) => tester.scrollUntilVisible(
    finder, 200, scrollable: find.byType(Scrollable).first);

/// 홈의 '지난번 조건으로 다시 찾기'.
Future<void> searchAgain(WidgetTester tester) => tapAndSettle(tester, '지난번 조건으로 다시 찾기');

/// 지체장애·재활 치료·성인으로 서울특별시 강남구를 찾는다.
Future<void> searchGangnam(WidgetTester tester) async {
  await chooseUntilRegion(tester);
  await tapAndSettle(tester, '서울특별시');
  await tapNext(tester);
  await tapAndSettle(tester, '강남구');
  await tester.tap(find.text('추천 병원 보기'));
  await tester.pumpAndSettle();
}

/// 병원 찾기에서 장애 유형부터 나이까지 고르고 편의시설 단계를 넘긴다.
Future<void> chooseUntilRegion(
  WidgetTester tester, {
  String type = '지체장애',
  String severity = '장애의 정도가 심한 장애인',
  String need = '재활 치료',
  String age = '성인',
}) async {
  await openFind(tester);
  await tapAndSettle(tester, type);
  await tapNext(tester);
  await tapAndSettle(tester, severity);
  await tapNext(tester);
  await tapAndSettle(tester, need);
  await tapNext(tester);
  await tapAndSettle(tester, age);
  await tapNext(tester);
  await tapNext(tester); // 편의시설은 미리 골라 둔 대로 둔다.
}
