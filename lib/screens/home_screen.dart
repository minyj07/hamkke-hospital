import 'dart:async';

import 'package:flutter/material.dart';

import '../data/regions.dart';
import '../models/hospital.dart';
import '../models/search_conditions.dart';
import '../services/hospital_search.dart';
import '../services/location.dart';
import '../services/recommender.dart' show distanceKm;
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';
import 'app_shell.dart';
import 'care_card_screen.dart';
import 'data_notice.dart';
import 'hospital_actions.dart';
import 'hospital_detail_screen.dart';
import 'results_launcher.dart';

/// 홈 (메디움 디자인): 로고, 큰 제목, 병원 검색, AI로 말해서 찾기, 바로가기 4개, 내 주변 병원, 자주 찾는 진료과.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

/// 자주 찾는 진료과 (디자인). 이름은 심평원 진료과목 이름과 같다.
const _commonDepartments = [
  ('내과', DesignIcons.internal),
  ('정형외과', DesignIcons.orthopedic),
  ('신경과', DesignIcons.neurology),
  ('외과', DesignIcons.surgery),
];

class _HomeScreenState extends State<HomeScreen> with ResultsLauncher {
  late final AppServices _services = AppScope.of(context);

  // 병원 검색
  final _query = TextEditingController();
  final _queryFocus = FocusNode();
  Future<_SearchData>? _searchData;
  bool _opening = false;

  // 내 주변 병원
  String? _dept;
  _Nearby? _nearby;
  bool _nearbyLoading = false;
  String? _nearbyError;

  @override
  void initState() {
    super.initState();
    // 지난번 조건에 지역이 있으면 위치를 묻지 않고 그 지역 주변 병원을 보여 준다.
    _services.lastSearch.load().then((_) {
      if (mounted) unawaited(_loadNearbyFromLastSearch());
    });
  }

  @override
  void dispose() {
    _query.dispose();
    _queryFocus.dispose();
    super.dispose();
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  // ---- 병원 검색 ----

  /// 검색 색인은 처음 검색할 때 읽는다 (6만 곳이라 앱을 켤 때 읽지 않는다).
  Future<_SearchData> _loadSearch() async {
    final repository = _services.repository;
    final (entries, regions) = await (repository.loadSearchIndex(), repository.loadRegions()).wait;
    return _SearchData(entries, {for (final r in regions) r.code: r.name});
  }

  void _onQueryChanged(String _) {
    _searchData ??= _loadSearch();
    setState(() {});
  }

  void _clearQuery() {
    _query.clear();
    setState(() {});
  }

  /// 고른 병원의 자세한 정보는 그 시·도 파일에서 읽는다.
  Future<Hospital?> _find(String region, String id) async {
    try {
      return await _services.repository.findHospital(region, id);
    } catch (_) {
      return null;
    }
  }

  Future<void> _openEntry(SearchEntry e) async {
    if (_opening) return;
    setState(() => _opening = true);
    final hospital = await _find(e.region, e.id);
    if (!mounted) return;
    setState(() => _opening = false);
    if (hospital == null) {
      tell('병원 정보를 불러오지 못했어요. 다시 눌러 주세요.');
      return;
    }
    _push(HospitalDetailScreen(hospital: hospital));
  }

  Future<void> _toggleEntry(SearchEntry e) async {
    final hospital = await _find(e.region, e.id);
    if (!mounted) return;
    if (hospital == null) {
      tell('병원 정보를 불러오지 못했어요. 다시 눌러 주세요.');
      return;
    }
    await _services.favorites.toggle(hospital);
  }

  // ---- 내 주변 병원 ----

  Future<void> _loadNearbyFromLastSearch() async {
    final SearchConditions? last = _services.lastSearch.value;
    if (last == null || last.nearMe || _nearby != null) return;
    try {
      final regions = await _services.repository.loadRegions();
      final region = regions.where((r) => r.code == last.regionCode).firstOrNull;
      if (region == null) return;
      final district = region.districts.where((d) => d.name == last.districtName).firstOrNull;
      final origin = district ?? region;
      await _showNearby(
        label: [region.name, ?district?.name].join(' '),
        lat: origin.lat,
        lng: origin.lng,
        regions: [region],
      );
    } catch (_) {
      // 지난번 지역으로 못 보여 주면 현재 위치 버튼을 그대로 둔다.
    }
  }

  /// '현재 위치로 보기'. 누를 때만 위치를 묻고, 거리를 재는 데만 쓴 뒤 저장하지 않는다.
  Future<void> _loadNearbyHere() async {
    if (_nearbyLoading) return;
    setState(() {
      _nearbyLoading = true;
      _nearbyError = null;
    });
    try {
      final regions = await _services.repository.loadRegions();
      final here = await _services.locationService.current();
      if (!mounted) return;
      final near = here.error == null ? regionsNear(regions, here.lat, here.lng) : null;
      if (near == null) {
        setState(() {
          _nearbyLoading = false;
          _nearbyError = here.error ?? '현재 위치 근처의 병원 정보가 없어요.';
        });
        return;
      }
      await _showNearby(
        label: '현재 위치',
        lat: here.lat,
        lng: here.lng,
        regions: [near.region, ...near.nearby],
      );
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _nearbyLoading = false;
        _nearbyError = '병원 정보를 불러오지 못했어요.';
      });
    }
  }

  Future<void> _showNearby({
    required String label,
    required double lat,
    required double lng,
    required List<Region> regions,
  }) async {
    if (!mounted) return;
    setState(() => _nearbyLoading = true);
    final List<List<Hospital>> lists;
    try {
      lists = await Future.wait([for (final r in regions) _services.repository.loadHospitals(r.code)]);
    } catch (_) {
      // 불러오는 표시를 끄고, 부른 쪽이 알릴지 정한다.
      if (mounted) setState(() => _nearbyLoading = false);
      rethrow;
    }
    final ranked = [
      for (final list in lists)
        for (final h in list) (h, distanceKm(lat, lng, h.lat, h.lng)),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    if (!mounted) return;
    setState(() {
      _nearbyLoading = false;
      _nearbyError = null;
      // 진료과로 거를 때를 생각해 가까운 곳을 넉넉히 둔다.
      _nearby = _Nearby(label, ranked.take(300).toList());
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = MediumColors.of(context);
    final shell = AppShell.of(context);
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: Listenable.merge([_services.lastSearch, _services.favorites]),
          builder: (context, _) {
            final last = _services.lastSearch.value;
            return ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(22, 28, 22, 0),
                  child: Align(alignment: Alignment.centerLeft, child: BrandHeader()),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 30, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Semantics(
                        header: true,
                        child: Text('나에게 맞는\n병원을 찾아보세요', style: theme.textTheme.headlineMedium),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '필요한 진료에 맞는 병원을 쉽게 찾아요',
                        style: theme.textTheme.bodyMedium?.copyWith(color: c.textSecondary, letterSpacing: -0.3),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (last != null)
                        _LastSearchLink(
                          summary: last.summary,
                          locating: locating,
                          onPressed: () => showResults(last),
                        )
                      else
                        const SizedBox(height: 8),
                      const SizedBox(height: 4),
                      _SearchBar(
                        controller: _query,
                        focusNode: _queryFocus,
                        onChanged: _onQueryChanged,
                        onClear: _clearQuery,
                      ),
                    ],
                  ),
                ),
                if (_query.text.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                    child: _SearchResults(
                      query: _query.text.trim(),
                      data: _searchData!,
                      opening: _opening,
                      isFavorite: _services.favorites.contains,
                      onOpen: _openEntry,
                      onToggle: _toggleEntry,
                      onRetry: () => setState(() => _searchData = _loadSearch()),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                  child: _AiCard(onPressed: () => shell.showTab(AppTab.ai)),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 22, 20, 0),
                  child: _QuickActions(actions: [
                    _QuickAction('병원 찾기', DesignIcons.find, () => shell.showTab(AppTab.find)),
                    _QuickAction('나의 진료 카드', DesignIcons.card, () => _push(const CareCardScreen())),
                    _QuickAction('즐겨찾기', DesignIcons.star, () => shell.showTab(AppTab.favorites)),
                    _QuickAction('지도에서 찾기', DesignIcons.map, () => openMapSearch(context, '병원')),
                  ]),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(13, 26, 13, 0),
                  child: _NearbySection(
                    nearby: _nearby,
                    dept: _dept,
                    loading: _nearbyLoading,
                    error: _nearbyError,
                    isFavorite: _services.favorites.contains,
                    onLocate: _loadNearbyHere,
                    onOpen: (h) => _push(HospitalDetailScreen(hospital: h)),
                    onToggle: _services.favorites.toggle,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SectionTitle('자주 찾는 진료과'),
                      const SizedBox(height: 14),
                      _ResponsiveGrid(
                        children: [
                          for (final (name, icon) in _commonDepartments)
                            _DeptButton(
                              name: name,
                              icon: icon,
                              selected: _dept == name,
                              onPressed: () => setState(() => _dept = _dept == name ? null : name),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: DataNotice(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// '지난번 조건으로 다시 찾기' (디자인: 오른쪽, 밑줄 글자 버튼). 화면낭독기는 지난번 조건도 읽는다.
class _LastSearchLink extends StatelessWidget {
  const _LastSearchLink({required this.summary, required this.locating, required this.onPressed});

  final String summary;
  final bool locating;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final style = TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: c.link,
      decoration: TextDecoration.underline,
      decorationColor: c.link,
    );
    return TextButton(
      style: TextButton.styleFrom(
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 4),
        foregroundColor: c.link,
      ),
      onPressed: locating ? null : onPressed,
      child: locating
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              const SizedBox.square(dimension: 14, child: CircularProgressIndicator(strokeWidth: 2)),
              const SizedBox(width: 8),
              Text('현재 위치를 확인하고 있어요', style: style.copyWith(decoration: TextDecoration.none)),
            ])
          : Text(
              '지난번 조건으로 다시 찾기',
              style: style,
              semanticsLabel: '지난번 조건으로 다시 찾기: $summary',
            ),
    );
  }
}

/// 병원 검색창 (디자인: 높이 56 알약, 그림자, 왼쪽 핀, 오른쪽 둥근 검색 버튼).
class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final hasQuery = controller.text.isNotEmpty;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.only(left: 18, right: 4),
      decoration: BoxDecoration(
        color: c.background,
        borderRadius: BorderRadius.circular(28),
        border: dark ? Border.all(color: c.border) : null,
        boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.12), blurRadius: 14, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          DesignIcon(DesignIcons.searchPin, size: 22, color: c.brand),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: onChanged,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => focusNode.unfocus(),
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.text),
              decoration: InputDecoration(
                // 라벨을 띄우지 않으면 안내 글처럼 보이고, 화면낭독기는 입력 칸 이름으로 읽는다.
                labelText: '병원 이름, 진료과, 지역으로 검색해보세요',
                floatingLabelBehavior: FloatingLabelBehavior.never,
                labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: c.textMuted),
                filled: false,
                isDense: true,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),
          if (hasQuery)
            IconButton(
              tooltip: '검색어 지우기',
              onPressed: onClear,
              style: IconButton.styleFrom(
                backgroundColor: c.divider,
                fixedSize: const Size(28, 28),
                minimumSize: const Size(28, 28),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.padded,
              ),
              icon: DesignIcon(DesignIcons.close, size: 14, strokeWidth: 2.4, color: c.textSecondary),
            ),
          IconButton(
            tooltip: '검색',
            onPressed: () => hasQuery ? focusNode.unfocus() : focusNode.requestFocus(),
            style: IconButton.styleFrom(
              backgroundColor: c.brand,
              fixedSize: const Size(44, 44),
              minimumSize: const Size(44, 44),
              padding: EdgeInsets.zero,
              tapTargetSize: MaterialTapTargetSize.padded,
            ),
            icon: DesignIcon(DesignIcons.search, size: 20, strokeWidth: 2.4, color: c.onBrand),
          ),
        ],
      ),
    );
  }
}

class _SearchData {
  _SearchData(this.entries, this.regionNames);

  final List<SearchEntry> entries;
  final Map<String, String> regionNames;
}

/// 검색창 아래의 결과 (디자인: '검색 결과 N곳' 과 연한 초록 카드).
class _SearchResults extends StatelessWidget {
  const _SearchResults({
    required this.query,
    required this.data,
    required this.opening,
    required this.isFavorite,
    required this.onOpen,
    required this.onToggle,
    required this.onRetry,
  });

  /// 한 번에 보여 줄 수. 더 많으면 검색어를 좁히게 한다.
  static const shown = 30;

  final String query;
  final Future<_SearchData> data;
  final bool opening;
  final bool Function(String id) isFavorite;
  final ValueChanged<SearchEntry> onOpen;
  final ValueChanged<SearchEntry> onToggle;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final muted = TextStyle(fontSize: 14, color: c.textMuted);
    return FutureBuilder(
      future: data,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Row(children: [
            Expanded(child: Text('검색 정보를 불러오지 못했어요.', style: muted)),
            TextButton(onPressed: onRetry, child: const Text('다시 시도')),
          ]);
        }
        if (!snapshot.hasData) {
          return const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator()));
        }
        final data = snapshot.data!;
        final hits = searchHospitals(data.entries, query);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (opening) const LinearProgressIndicator(),
            Semantics(
              liveRegion: true,
              child: Text.rich(
                TextSpan(children: [
                  const TextSpan(text: '검색 결과 '),
                  TextSpan(
                    text: '${hits.length}',
                    style: TextStyle(fontWeight: FontWeight.w700, color: c.brandDeep),
                  ),
                  const TextSpan(text: '곳'),
                  if (hits.length > shown) TextSpan(text: ' · 가까운 지역 이름을 더 적으면 좁혀져요'),
                ]),
                style: TextStyle(fontSize: 14, color: c.textSecondary),
              ),
            ),
            const SizedBox(height: 10),
            if (hits.isEmpty)
              Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  '검색 결과가 없어요\n이름을 줄이거나 띄어 써 보세요',
                  textAlign: TextAlign.center,
                  style: muted,
                ),
              ),
            for (final e in hits.take(shown)) ...[
              HospitalTile(
                id: e.id,
                name: e.name,
                subtitle: [
                  e.kind,
                  '${data.regionNames[e.region] ?? ''} ${e.district}'.trim(),
                ].where((s) => s.isNotEmpty).join(' · '),
                onTap: () => onOpen(e),
                trailing: HeartButton(
                  name: e.name,
                  favorite: isFavorite(e.id),
                  onPressed: () => onToggle(e),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ],
        );
      },
    );
  }
}

/// 'AI로 말해서 찾기' (메디움 초록 바탕의 넓은 카드). 누르면 상황을 글로 적는 AI 화면을 연다.
class _AiCard extends StatelessWidget {
  const _AiCard({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Semantics(
      button: true,
      label: 'AI로 말해서 찾기',
      hint: '상황을 말하듯 적으면 AI가 병원 찾기 조건을 골라 드려요',
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: c.brand,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: c.onBrand.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: DesignIcon(DesignIcons.talk, size: 24, color: c.onBrand),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI로 말해서 찾기',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: -0.4, color: c.onBrand),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '상황을 말하듯 적으면 AI가 조건을 골라 드려요',
                        style: TextStyle(fontSize: 13, height: 1.4, letterSpacing: -0.3, color: c.onBrand),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 6),
                DesignIcon(DesignIcons.chevron, size: 20, strokeWidth: 2.4, color: c.onBrand),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _QuickAction {
  const _QuickAction(this.label, this.icon, this.onPressed);

  final String label;
  final DesignIcons icon;
  final VoidCallback onPressed;
}

/// 바로가기 4개 (디자인: 연한 초록 칸 속 아이콘과 아래 이름).
class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.actions});

  final List<_QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return _ResponsiveGrid(
      children: [
        for (final a in actions)
          Semantics(
            button: true,
            label: a.label,
            onTap: a.onPressed,
            excludeSemantics: true,
            child: InkWell(
              onTap: a.onPressed,
              borderRadius: BorderRadius.circular(14),
              child: Column(
                children: [
                  AspectRatio(
                    aspectRatio: 196 / 154,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(color: c.container, borderRadius: BorderRadius.circular(14)),
                      child: DesignIcon(a.icon, size: 30, color: c.brandDeep),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    a.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: c.text),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// 한 줄에 4칸. 글자를 크게 하면 2칸으로 줄여서 글이 잘리지 않게 한다.
class _ResponsiveGrid extends StatelessWidget {
  const _ResponsiveGrid({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final columns = scale > 1.3 ? 2 : 4;
    const gap = 10.0;
    return LayoutBuilder(builder: (context, box) {
      final width = (box.maxWidth - gap * (columns - 1)) / columns;
      return Wrap(
        spacing: gap,
        runSpacing: 14,
        children: [for (final child in children) SizedBox(width: width, child: child)],
      );
    });
  }
}

/// 진료과 버튼 (디자인: 연한 초록 칸, 고르면 테두리). 누르면 '내 주변 병원'을 그 과로 거른다.
class _DeptButton extends StatelessWidget {
  const _DeptButton({required this.name, required this.icon, required this.selected, required this.onPressed});

  final String name;
  final DesignIcons icon;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      hint: selected ? '내 주변 병원을 $name만 보여 주는 중' : '내 주변 병원을 $name만 보기',
      onTap: onPressed,
      excludeSemantics: true,
      child: Material(
        color: selected ? c.containerStrong : c.container,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: selected ? c.brand : Colors.transparent, width: 2),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: LayoutBuilder(
            builder: (context, box) => ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxWidth * 166 / 190),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    DesignIcon(icon, size: 30, color: c.brandDeep),
                    const SizedBox(height: 6),
                    Text(
                      name,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: c.text),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Nearby {
  _Nearby(this.label, this.hospitals);

  /// 거리의 기준 (예: '현재 위치', '서울특별시 강남구').
  final String label;

  /// 가까운 순.
  final List<(Hospital, double)> hospitals;
}

/// '내 주변 병원' (디자인: 연한 초록 상자 속 가로로 넘기는 카드).
class _NearbySection extends StatelessWidget {
  const _NearbySection({
    required this.nearby,
    required this.dept,
    required this.loading,
    required this.error,
    required this.isFavorite,
    required this.onLocate,
    required this.onOpen,
    required this.onToggle,
  });

  /// 가로 목록에 보여 줄 수.
  static const shown = 10;

  final _Nearby? nearby;
  final String? dept;
  final bool loading;
  final String? error;
  final bool Function(String id) isFavorite;
  final VoidCallback onLocate;
  final ValueChanged<Hospital> onOpen;
  final ValueChanged<Hospital> onToggle;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final small = TextStyle(fontSize: 13, color: c.textSecondary, height: 1.45);
    final nearby = this.nearby;
    final list = nearby == null
        ? const <(Hospital, double)>[]
        : [
            for (final item in nearby.hospitals)
              if (dept == null || item.$1.departments.contains(dept)) item,
          ].take(shown).toList();

    Widget body;
    if (loading) {
      body = const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    } else if (nearby == null) {
      body = Padding(
        padding: const EdgeInsets.only(right: 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (error != null) ...[
              Semantics(liveRegion: true, child: Text(error!, style: small.copyWith(color: c.warning))),
              const SizedBox(height: 8),
            ],
            Text('지금 있는 곳에서 가까운 병원을 보여 드려요. 위치는 거리를 재는 데만 쓰고 저장하지 않아요.', style: small),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              icon: const Icon(Icons.my_location, size: 20),
              label: const Text('현재 위치로 보기'),
              onPressed: onLocate,
            ),
          ],
        ),
      );
    } else if (list.isEmpty) {
      body = Padding(
        padding: const EdgeInsets.symmetric(vertical: 30, horizontal: 10),
        child: Text('해당 진료과 병원이 근처에 없어요', style: small),
      );
    } else {
      body = SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.only(right: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final (i, (h, km)) in list.indexed) ...[
              if (i > 0) const SizedBox(width: 12),
              _NearbyCard(
                hospital: h,
                km: km,
                dept: dept,
                favorite: isFavorite(h.id),
                onOpen: () => onOpen(h),
                onToggle: () => onToggle(h),
              ),
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 18, 0, 18),
      decoration: BoxDecoration(color: c.container, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: SectionTitle('내 주변 병원', icon: DesignIcons.pin),
          ),
          if (nearby != null && !loading)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 14),
              child: Text(
                [
                  '${nearby.label} 기준',
                  ?dept,
                  '가까운 순',
                ].join(' · '),
                style: small,
              ),
            ),
          const SizedBox(height: 14),
          body,
        ],
      ),
    );
  }
}

/// 내 주변 병원 카드 (디자인: 너비 150, 흰 바탕, 위에 사진 자리와 하트).
class _NearbyCard extends StatelessWidget {
  const _NearbyCard({
    required this.hospital,
    required this.km,
    required this.dept,
    required this.favorite,
    required this.onOpen,
    required this.onToggle,
  });

  final Hospital hospital;
  final double km;
  final String? dept;
  final bool favorite;
  final VoidCallback onOpen;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final h = hospital;
    // 글자를 키우면 카드도 넓힌다.
    final width = MediaQuery.textScalerOf(context).scale(150).clamp(150.0, 280.0);
    final kind = dept ?? (h.kind.isNotEmpty ? h.kind : (h.departments.firstOrNull ?? ''));
    final info = [kmLabel(km), if (kind.isNotEmpty) kind].join(' · ');
    final tags = hospitalTags(h);
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          Semantics(
            button: true,
            label: [h.name, info, ...tags].join(', '),
            onTap: onOpen,
            excludeSemantics: true,
            child: Material(
              color: c.background,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onOpen,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ToneBox(id: h.id, height: 62),
                      const SizedBox(height: 6),
                      Text(
                        h.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, letterSpacing: -0.4, color: c.text),
                      ),
                      const SizedBox(height: 6),
                      Text(info, style: TextStyle(fontSize: 12, color: c.textSecondary)),
                      if (tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(spacing: 4, runSpacing: 4, children: [for (final t in tags) TagChip(t)]),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: HeartButton(name: h.name, favorite: favorite, onPressed: onToggle, size: 15, circle: true),
          ),
        ],
      ),
    );
  }
}
