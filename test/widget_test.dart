import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hamkke_hospital/data/data_store.dart';
import 'package:hamkke_hospital/data/hospital_repository.dart';
import 'package:hamkke_hospital/data/last_search_store.dart';
import 'package:hamkke_hospital/data/regions.dart';
import 'package:hamkke_hospital/main.dart';
import 'package:hamkke_hospital/models/disability.dart';
import 'package:hamkke_hospital/models/hospital.dart';
import 'package:hamkke_hospital/models/search_conditions.dart';
import 'package:hamkke_hospital/services/location.dart';

class FakeRepository implements HospitalRepository {
  FakeRepository({this.updateResult = UpdateResult.upToDate});

  static const gangnam = Area('강남구', 37.5172, 127.0473);

  /// update() 가 돌려줄 결과. updated 면 기준일이 2026-10-26 으로 바뀐다.
  final UpdateResult updateResult;
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
      ];

  @override
  Future<List<Hospital>> loadHospitals(String regionCode) async => const [
        Hospital(
          id: 'h1',
          name: '강남재활의학과의원',
          kind: '의원',
          district: '강남구',
          address: '서울특별시 강남구 테헤란로 1',
          phone: '02-000-0000',
          lat: 37.5175,
          lng: 127.0470,
          departments: {'재활의학과'},
        ),
        Hospital(
          id: 'h2',
          name: '강남안과의원',
          address: '서울특별시 강남구 테헤란로 2',
          lat: 37.5175,
          lng: 127.0470,
          departments: {'안과'},
        ),
        Hospital(
          id: 'h3',
          name: '강남피부과의원',
          address: '서울특별시 강남구 테헤란로 3',
          lat: 37.5175,
          lng: 127.0470,
          departments: {'피부과'},
        ),
      ];

  @override
  Future<DataInfo> loadInfo() async =>
      DataInfo(generatedAt: _generatedAt, sources: const ['테스트 자료']);

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

const gangnamRehab = SearchConditions(
  types: {DisabilityType.physical},
  severity: Severity.severe,
  need: CareNeed.rehab,
  regionCode: '110000',
  regionName: '서울특별시',
  districtName: '강남구',
);

Widget app({
  LocationResult here = const LocationResult(37.5172, 127.0473),
  HospitalRepository? repository,
  LocationService? locationService,
  LastSearchStore? searchStore,
}) =>
    HamkkeApp(
      repository: repository ?? FakeRepository(),
      locationService: locationService ?? FakeLocationService(here),
      searchStore: searchStore ?? FakeSearchStore(),
    );

void main() {
  Future<void> tapAndSettle(WidgetTester tester, String text) async {
    await tester.scrollUntilVisible(find.text(text), 100,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  Future<void> tapNext(WidgetTester tester) async {
    await tester.tap(find.text('다음'));
    await tester.pumpAndSettle();
  }

  bool nextEnabled(WidgetTester tester) =>
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, '다음')).onPressed !=
      null;

  testWidgets('첫 화면은 장애 유형을 묻고, 고르기 전엔 다음 버튼이 꺼져 있다', (tester) async {
    await tester.pumpWidget(app());

    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);
    expect(nextEnabled(tester), isFalse);

    await tapAndSettle(tester, '지체장애');
    await tapNext(tester);

    expect(find.text('장애의 정도를 알려주세요'), findsOneWidget);
  });

  testWidgets('조건을 끝까지 고르면 추천 병원과 상세 정보가 나온다', (tester) async {
    await tester.pumpWidget(app());

    await tapAndSettle(tester, '지체장애');
    await tapNext(tester);
    await tapAndSettle(tester, '장애의 정도가 심한 장애인');
    await tapNext(tester);
    await tapAndSettle(tester, '재활 치료');
    await tapNext(tester);
    await tapAndSettle(tester, '서울특별시');
    await tapNext(tester);
    expect(find.text('서울특별시 전체'), findsOneWidget);
    await tapAndSettle(tester, '강남구');
    await tester.tap(find.text('병원 찾기'));
    await tester.pumpAndSettle();

    expect(find.text('추천 병원'), findsOneWidget);
    expect(find.text('강남재활의학과의원'), findsOneWidget);
    expect(find.text('강남안과의원'), findsNothing);
    // 거리순이 아니라 추천 점수순이다.
    expect(find.textContaining('조건에 잘 맞는 순서로 1곳을 골랐어요'), findsOneWidget);
    expect(find.textContaining('가까운 순으로'), findsNothing);
    expect(find.textContaining('서울특별시 강남구 중심에서'), findsOneWidget);
    expect(find.textContaining('자료: 테스트 자료 (2026-10-07 기준)'), findsOneWidget);
    // 편의시설 정보가 없으면 카드마다 반복하지 않고 요약에서 한 번만 알려준다.
    expect(find.textContaining('휠체어 접근, '), findsOneWidget);
    expect(find.textContaining('정보는 아직 없어요'), findsOneWidget);
    expect(find.textContaining('확인 필요'), findsNothing);

    await tester.tap(find.text('강남재활의학과의원'));
    await tester.pumpAndSettle();

    expect(find.text('서울특별시 강남구 테헤란로 1'), findsOneWidget);
    expect(find.text('전화하기'), findsOneWidget);
    expect(find.text('네이버 지도'), findsOneWidget);
  });

  testWidgets('기타를 고르면 직접 입력해야 다음으로 넘어가고, 입력한 내용으로 찾는다', (tester) async {
    await tester.pumpWidget(app());

    await tapAndSettle(tester, '기타');
    expect(nextEnabled(tester), isFalse);
    await tester.enterText(find.byType(TextField), '척수손상');
    await tester.pump();
    expect(nextEnabled(tester), isTrue);
    await tapNext(tester);

    await tapAndSettle(tester, '장애의 정도가 심하지 않은 장애인');
    await tapNext(tester);

    await tapAndSettle(tester, '기타');
    expect(nextEnabled(tester), isFalse);
    await tester.enterText(find.byType(TextField), '피부 질환');
    await tester.pump();
    await tapNext(tester);

    await tapAndSettle(tester, '현재 위치로 찾기');

    expect(find.text('추천 병원'), findsOneWidget);
    expect(find.textContaining('기타(척수손상) · 기타(피부 질환) · 현재 위치'), findsOneWidget);
    expect(find.text('강남피부과의원'), findsOneWidget);
    expect(find.text('강남재활의학과의원'), findsNothing);
  });

  testWidgets('현재 위치로 찾으면 시·도를 고르지 않아도 가까운 병원이 나온다', (tester) async {
    await tester.pumpWidget(app());

    await tapAndSettle(tester, '시각장애');
    await tapNext(tester);
    await tapAndSettle(tester, '장애의 정도가 심한 장애인');
    await tapNext(tester);
    await tapAndSettle(tester, '일반 진료');
    await tapNext(tester);
    await tapAndSettle(tester, '현재 위치로 찾기');

    expect(find.text('강남안과의원'), findsOneWidget);
    expect(find.textContaining('거리는 현재 위치에서 잰 직선거리예요'), findsOneWidget);
  });

  testWidgets('위치를 못 얻으면 이유를 알려주고 지역 선택 화면에 남는다', (tester) async {
    await tester.pumpWidget(
        app(here: const LocationResult.error('위치 권한을 허용해야 현재 위치로 찾을 수 있어요.')));

    await tapAndSettle(tester, '시각장애');
    await tapNext(tester);
    await tapAndSettle(tester, '장애의 정도가 심한 장애인');
    await tapNext(tester);
    await tapAndSettle(tester, '일반 진료');
    await tapNext(tester);
    await tapAndSettle(tester, '현재 위치로 찾기');

    expect(find.text('위치 권한을 허용해야 현재 위치로 찾을 수 있어요.'), findsOneWidget);
    expect(find.text('어디에서 찾을까요?'), findsOneWidget);
  });

  testWidgets('병원 정보 기준일을 보여주고, 새 정보를 바로 받을 수 있다', (tester) async {
    await tester.pumpWidget(
        app(repository: FakeRepository(updateResult: UpdateResult.updated)));

    await tester.tap(find.byTooltip('병원 정보 업데이트'));
    await tester.pumpAndSettle();
    expect(find.text('2026-10-07 기준 정보예요.'), findsOneWidget);

    await tester.tap(find.text('지금 확인하기'));
    await tester.pumpAndSettle();
    expect(find.text('새 병원 정보를 받았어요.'), findsOneWidget);
    expect(find.text('2026-10-26 기준 정보예요.'), findsOneWidget);

    await tester.tap(find.text('닫기'));
    await tester.pumpAndSettle();
    expect(find.text('병원 정보'), findsNothing);
  });

  testWidgets('새 정보를 확인하지 못하면 이유를 알려준다', (tester) async {
    await tester.pumpWidget(
        app(repository: FakeRepository(updateResult: UpdateResult.failed)));

    await tester.tap(find.byTooltip('병원 정보 업데이트'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('지금 확인하기'));
    await tester.pumpAndSettle();

    expect(find.textContaining('인터넷 연결을 확인'), findsOneWidget);
    expect(find.text('2026-10-07 기준 정보예요.'), findsOneWidget);
  });

  testWidgets('찾은 조건을 저장해 두고, 앱을 다시 켜면 첫 화면에서 바로 다시 찾는다', (tester) async {
    final store = FakeSearchStore();
    await tester.pumpWidget(app(searchStore: store));
    expect(find.text('지난번 조건'), findsNothing);

    await tapAndSettle(tester, '지체장애');
    await tapNext(tester);
    await tapAndSettle(tester, '장애의 정도가 심한 장애인');
    await tapNext(tester);
    await tapAndSettle(tester, '재활 치료');
    await tapNext(tester);
    await tapAndSettle(tester, '서울특별시');
    await tapNext(tester);
    await tapAndSettle(tester, '강남구');
    await tester.tap(find.text('병원 찾기'));
    await tester.pumpAndSettle();
    expect(store.saved?.summary, '지체장애 · 재활 치료 · 서울특별시 강남구');

    // 앱을 껐다 켠다.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(app(searchStore: store));
    await tester.pumpAndSettle();
    expect(find.text('지난번 조건'), findsOneWidget);
    expect(find.text('지체장애 · 재활 치료 · 서울특별시 강남구'), findsOneWidget);
    expect(find.text('이 휴대폰에 저장하고, 앱 밖으로 보내지 않아요.'), findsOneWidget);

    await tester.tap(find.text('이 조건으로 다시 찾기'));
    await tester.pumpAndSettle();
    expect(find.text('추천 병원'), findsOneWidget);
    expect(find.text('강남재활의학과의원'), findsOneWidget);
    expect(find.textContaining('서울특별시 강남구 중심에서'), findsOneWidget);
  });

  testWidgets('현재 위치로 찾은 조건은 위치를 저장하지 않고, 다시 찾을 때 새로 얻는다', (tester) async {
    final location = FakeLocationService(const LocationResult(37.5172, 127.0473));
    final store = FakeSearchStore(const SearchConditions(
      types: {DisabilityType.visual},
      severity: Severity.severe,
      need: CareNeed.general,
    ));
    await tester.pumpWidget(app(locationService: location, searchStore: store));
    await tester.pumpAndSettle();
    expect(find.text('시각장애 · 일반 진료 · 현재 위치'), findsOneWidget);

    await tester.tap(find.text('이 조건으로 다시 찾기'));
    await tester.pumpAndSettle();

    expect(location.calls, 1);
    expect(find.text('강남안과의원'), findsOneWidget);
    expect(find.textContaining('거리는 현재 위치에서 잰 직선거리예요'), findsOneWidget);
    expect(store.saved!.toJson().containsKey('region'), isFalse);
  });

  testWidgets('지난번 조건을 지우고, 잘못 눌렀으면 되돌린다', (tester) async {
    final store = FakeSearchStore(gangnamRehab);
    await tester.pumpWidget(app(searchStore: store));
    await tester.pumpAndSettle();

    await tester.tap(find.text('조건 지우기'));
    await tester.pumpAndSettle();
    expect(find.text('지난번 조건'), findsNothing);
    expect(store.saved, isNull);
    expect(find.text('지난번 조건을 지웠어요.'), findsOneWidget);

    await tester.tap(find.text('되돌리기'));
    await tester.pumpAndSettle();
    expect(find.text('지난번 조건'), findsOneWidget);
    expect(store.saved?.summary, gangnamRehab.summary);
  });

  testWidgets('저장한 지역이 새 데이터에서 없어졌으면 지역을 다시 고르게 한다', (tester) async {
    await tester.pumpWidget(app(
      searchStore: FakeSearchStore(const SearchConditions(
        types: {DisabilityType.physical},
        severity: Severity.severe,
        need: CareNeed.rehab,
        regionCode: '999999',
        regionName: '없어진도',
      )),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('이 조건으로 다시 찾기'));
    await tester.pumpAndSettle();

    expect(find.text('지역 정보가 바뀌었어요. 지역을 다시 골라 주세요.'), findsOneWidget);
    expect(find.text('어떤 장애가 있으신가요?'), findsOneWidget);
  });

  testWidgets('병원 정보를 못 불러오면 다시 시도할 수 있다', (tester) async {
    await tester.pumpWidget(app(
      repository: FlakyRepository(hospitalFailures: 1),
      searchStore: FakeSearchStore(gangnamRehab),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 조건으로 다시 찾기'));
    await tester.pumpAndSettle();
    expect(find.text('병원 정보를 불러오지 못했어요.'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('병원 정보를 불러오지 못했어요.'), findsNothing);
    expect(find.text('강남재활의학과의원'), findsOneWidget);
  });

  testWidgets('지역 목록을 못 불러오면 지역 고르기에서 다시 시도할 수 있다', (tester) async {
    await tester.pumpWidget(app(repository: FlakyRepository(regionFailures: 1)));
    await tapAndSettle(tester, '시각장애');
    await tapNext(tester);
    await tapAndSettle(tester, '장애의 정도가 심한 장애인');
    await tapNext(tester);
    await tapAndSettle(tester, '일반 진료');
    await tapNext(tester);
    expect(find.text('지역 정보를 불러오지 못했어요.'), findsOneWidget);

    await tester.tap(find.text('다시 시도'));
    await tester.pumpAndSettle();
    expect(find.text('서울특별시'), findsOneWidget);
  });

  testWidgets('지난번 조건으로 찾다가 지역을 못 불러오면, 다시 누를 때 다시 읽는다', (tester) async {
    await tester.pumpWidget(app(
      repository: FlakyRepository(regionFailures: 1),
      searchStore: FakeSearchStore(gangnamRehab),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 조건으로 다시 찾기'));
    await tester.pumpAndSettle();
    expect(find.text('지역 정보를 불러오지 못했어요. 다시 눌러 주세요.'), findsOneWidget);

    await tester.tap(find.text('이 조건으로 다시 찾기'));
    await tester.pumpAndSettle();
    expect(find.text('강남재활의학과의원'), findsOneWidget);
  });

  testWidgets('맞는 병원이 없으면 0곳이라고 하지 않고 다른 조건을 고르게 안내한다', (tester) async {
    await tester.pumpWidget(app(
      searchStore: FakeSearchStore(const SearchConditions(
        types: {DisabilityType.hearing},
        severity: Severity.mild,
        need: CareNeed.general,
        regionCode: '110000',
        regionName: '서울특별시',
        districtName: '강남구',
      )),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('이 조건으로 다시 찾기'));
    await tester.pumpAndSettle();

    expect(find.text('추천 병원'), findsOneWidget);
    expect(find.textContaining('조건에 맞는 병원을 찾지 못했어요'), findsOneWidget);
    expect(find.textContaining('다른 지역이나 진료를 골라 보세요'), findsOneWidget);
    expect(find.textContaining('0곳'), findsNothing);
    expect(find.textContaining('직선거리'), findsNothing);
  });
}
