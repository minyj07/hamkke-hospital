import 'package:flutter/material.dart';

import '../data/regions.dart';
import '../models/disability.dart';
import '../models/hospital.dart';
import '../models/user_profile.dart';
import '../services/recommender.dart';
import '../ui/format.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';
import 'data_notice.dart';
import 'hospital_detail_screen.dart';
import 'results_map.dart';
import 'retry_message.dart';

/// 결과를 늘어놓는 순서.
enum ResultOrder {
  recommended('추천순'),
  nearest('가까운 순');

  const ResultOrder(this.label);
  final String label;
}

/// 결과 화면을 닫으며 병원 찾기에 부탁하는 것.
enum ResultsExit {
  /// 같은 조건에서 진료 목적만 다시 고른다.
  changeNeed,
}

typedef _Loaded = ({List<Recommendation> all, DataInfo info, List<Region> regions});

/// 찾기 결과 (메디움 디자인): '조건에 맞는 병원 N곳', 찾은 조건 칩, 연한 초록 결과 카드와 하트.
class ResultsScreen extends StatefulWidget {
  const ResultsScreen({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  /// 한 번에 보여줄 병원 수.
  static const _shown = 20;

  late final AppServices _services = AppScope.of(context);

  /// 이웃 시·도까지 넓히면 바뀐다.
  late UserProfile _profile = widget.profile;
  late Future<_Loaded> _result = _load();
  ResultOrder _order = ResultOrder.recommended;
  bool _designatedOnly = false;
  bool _facilityInfoOnly = false;
  int? _withinKm;
  bool _onMap = false;

  /// 조건에 맞는 병원 전부 (점수순). 정렬·거르기를 바꿔도 다시 계산하지 않는다.
  Future<_Loaded> _load() async {
    final p = _profile;
    final repository = _services.repository;
    final (lists, info, regions, weights) = await (
      Future.wait([
        for (final r in [p.region, ...p.nearbyRegions]) repository.loadHospitals(r.code),
      ]),
      repository.loadInfo(),
      repository.loadRegions(),
      repository.loadWeights(),
    ).wait;
    return (
      all: recommend(p, [for (final l in lists) ...l], limit: null, weights: weights),
      info: info,
      regions: regions,
    );
  }

  bool get _filtered => _designatedOnly || _facilityInfoOnly || _withinKm != null;

  /// 고른 순서·거르기로 고른 앞의 [_shown] 곳. '가까운 순'은 맞는 병원 전체에서 가까운 곳을 고른다.
  List<Recommendation> _pick(List<Recommendation> all) {
    final picked = [
      for (final r in all)
        if ((!_designatedOnly || r.designated) &&
            (!_facilityInfoOnly || r.hospital.hasFacilityInfo) &&
            (_withinKm == null || r.distanceKm <= _withinKm!))
          r,
    ];
    if (_order == ResultOrder.nearest) {
      picked.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return picked.take(_shown).toList();
  }

  /// 땅이 맞닿은 시·도 중 아직 찾지 않은 곳.
  List<Region> _neighbors(List<Region> regions) {
    final searched = {_profile.region.code, for (final r in _profile.nearbyRegions) r.code};
    final codes = neighborRegions[_profile.region.code] ?? const <String>[];
    return [
      for (final r in regions)
        if (codes.contains(r.code) && !searched.contains(r.code)) r,
    ];
  }

  void _open(Recommendation r) => Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => HospitalDetailScreen(hospital: r.hospital, recommendation: r),
      ));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('찾기 결과')),
      body: FutureBuilder(
        future: _result,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return RetryMessage(
              message: '병원 정보를 불러오지 못했어요.',
              // setState 안에서 Future 를 돌려주면 안 되므로 블록으로 쓴다.
              onRetry: () => setState(() {
                _result = _load();
              }),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final loaded = snapshot.data!;
          final results = _pick(loaded.all);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_services.mapEnabled)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, icon: Icon(Icons.list), label: Text('목록')),
                      ButtonSegment(value: true, icon: Icon(Icons.map_outlined), label: Text('지도')),
                    ],
                    selected: {_onMap},
                    onSelectionChanged: (s) => setState(() => _onMap = s.first),
                  ),
                ),
              Expanded(
                child: _onMap
                    ? ResultsMap(
                        key: ValueKey([for (final r in results) r.hospital.id].join(',')),
                        results: results,
                        origin: _profile.origin,
                        onOpen: _open,
                      )
                    : _list(loaded, results),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _list(_Loaded loaded, List<Recommendation> results) {
    final neighbors = _neighbors(loaded.regions);
    final favorites = _services.favorites;
    return ListenableBuilder(
      listenable: favorites,
      builder: (context, _) => ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
        children: [
          _Header(
            profile: _profile,
            count: results.length,
            order: _order,
            filters: [
              if (_designatedOnly) '정부 지정 기관만 보여줘요.',
              if (_facilityInfoOnly) '편의시설 정보가 있는 병원만 보여줘요.',
              if (_withinKm != null) '$_withinKm km 안의 병원만 보여줘요.',
            ],
            unknownFacilities: {for (final r in results) ...r.unknown},
            unmatchedTexts: buildRequirement(_profile).unmatchedTexts,
          ),
          // 맞는 병원이 하나도 없으면 순서·거르기를 바꿔도 소용없다.
          if (loaded.all.isNotEmpty)
            _Controls(
              order: _order,
              designatedOnly: _designatedOnly,
              facilityInfoOnly: _facilityInfoOnly,
              withinKm: _withinKm,
              onOrder: (order) => setState(() => _order = order),
              onDesignatedOnly: (on) => setState(() => _designatedOnly = on),
              onFacilityInfoOnly: (on) => setState(() => _facilityInfoOnly = on),
              onWithinKm: (km) => setState(() => _withinKm = km),
            ),
          const SizedBox(height: 20),
          if (results.isEmpty) ...[
            _WidenCard(
              filtered: _filtered,
              neighbors: neighbors,
              onClearFilters: () => setState(() {
                _designatedOnly = false;
                _facilityInfoOnly = false;
                _withinKm = null;
              }),
              onNeighbors: () => setState(() {
                _profile = _profile.withNearby(neighbors);
                _result = _load();
              }),
              onChangeNeed: () => Navigator.of(context).pop(ResultsExit.changeNeed),
            ),
            const SizedBox(height: 12),
          ],
          for (final (i, r) in results.indexed) ...[
            _ResultCard(
              rank: i + 1,
              rec: r,
              favorite: favorites.contains(r.hospital.id),
              onTap: () => _open(r),
              onToggle: () => favorites.toggle(r.hospital),
            ),
            const SizedBox(height: 12),
          ],
          DataNotice(info: loaded.info, emergency: true),
        ],
      ),
    );
  }
}

/// 결과 머리 (디자인: '조건에 맞는 병원 N곳' 24/800, 찾은 조건 칩). 그 아래에 순서·거리의 기준을 작게 알린다.
class _Header extends StatelessWidget {
  const _Header({
    required this.profile,
    required this.count,
    required this.order,
    required this.filters,
    required this.unknownFacilities,
    required this.unmatchedTexts,
  });

  final UserProfile profile;
  final int count;
  final ResultOrder order;
  final List<String> filters;
  final Set<Facility> unknownFacilities;
  final List<String> unmatchedTexts;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = MediumColors.of(context);
    final place = profile.placeLabel;
    final from = profile.location != null ? '현재 위치' : '$place 중심';
    final facilities = [
      for (final f in Facility.values)
        if (unknownFacilities.contains(f)) f.label,
    ].join(', ');
    final conditions = [
      profile.typesLabel,
      if (profile.age == AgeGroup.child) profile.age.label,
      profile.needLabel,
      place,
    ];
    final notes = [
      if (profile.location == null && profile.nearbyRegions.isNotEmpty)
        '이웃 ${profile.nearbyRegions.map((r) => r.name).join(', ')}까지 찾았어요.',
      if (count > 0) ...[
        if (order == ResultOrder.recommended) ...[
          // 순서는 거리만이 아니라 recommend() 의 점수를 따른다.
          '조건에 잘 맞는 순서로 $count곳을 골랐어요.',
          '지정 기관인지, 필요한 진료과·편의시설이 있는지, 얼마나 가까운지를 함께 봤어요.',
        ] else
          '조건에 맞는 병원 중 가까운 $count곳이에요.',
        ...filters,
        '거리는 $from에서 잰 직선거리예요.',
      ],
      for (final text in unmatchedTexts)
        '\n‘$text’에 맞는 진료과는 찾지 못해서, 고르신 다른 조건으로 찾았어요.',
      if (facilities.isNotEmpty)
        '\n$facilities 정보가 없는 병원이 있어요. 정보가 없다고 순서를 낮추지는 않았으니 '
            '방문 전에 전화로 확인하세요.',
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 거르기를 바꾸면 곳 수가 바뀌므로 화면낭독기가 다시 읽어 준다.
        Semantics(
          header: true,
          liveRegion: true,
          // 맞는 병원이 없을 때는 '0곳'이라고 하지 않고, 아래에서 조건을 넓히게 한다.
          child: count == 0
              ? Text('조건에 맞는 병원을 찾지 못했어요', style: theme.textTheme.headlineSmall)
              : Text.rich(
                  TextSpan(children: [
                    const TextSpan(text: '조건에 맞는 병원 '),
                    TextSpan(text: '$count', style: TextStyle(color: c.brandDeep)),
                    const TextSpan(text: '곳'),
                  ]),
                  style: theme.textTheme.headlineSmall,
                ),
        ),
        const SizedBox(height: 14),
        Semantics(
          label: '찾은 조건: ${conditions.join(', ')}',
          excludeSemantics: true,
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final text in conditions) _ConditionChip(text)],
          ),
        ),
        if (notes.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            notes.join('\n'),
            style: TextStyle(fontSize: 13, height: 1.5, color: c.textSecondary),
          ),
        ],
      ],
    );
  }
}

/// 찾은 조건 하나 (디자인: 12/600, 연한 초록 바탕, 둥근 8).
class _ConditionChip extends StatelessWidget {
  const _ConditionChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: c.container, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.brandDeep),
      ),
    );
  }
}

/// 순서(추천순·가까운 순)와 거르기(지정 기관만, 편의시설 정보 있는 곳만, 거리).
class _Controls extends StatelessWidget {
  const _Controls({
    required this.order,
    required this.designatedOnly,
    required this.facilityInfoOnly,
    required this.withinKm,
    required this.onOrder,
    required this.onDesignatedOnly,
    required this.onFacilityInfoOnly,
    required this.onWithinKm,
  });

  static const _distances = [5, 10, 20];

  final ResultOrder order;
  final bool designatedOnly;
  final bool facilityInfoOnly;
  final int? withinKm;
  final ValueChanged<ResultOrder> onOrder;
  final ValueChanged<bool> onDesignatedOnly;
  final ValueChanged<bool> onFacilityInfoOnly;
  final ValueChanged<int?> onWithinKm;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    Widget group(String title, List<Widget> chips) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 목록 항목 안의 느슨한 글은 항목 노드 하나로 합쳐져서, 화면낭독기가 '순서 거르기 거리'를
              // 먼저 읽고 칩들을 뒤에 읽는다. 제목마다 노드를 따로 두어 제목 → 그 칩들 순서로 읽게 한다.
              Semantics(
                container: true,
                header: true,
                child: Text(
                  title,
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: c.textSecondary),
                ),
              ),
              const SizedBox(height: 6),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        group('순서', [
          for (final o in ResultOrder.values)
            ChoiceChip(
              label: Text(o.label),
              selected: order == o,
              onSelected: (_) => onOrder(o),
            ),
        ]),
        group('거르기', [
          FilterChip(
            label: const Text('지정 기관만'),
            selected: designatedOnly,
            onSelected: onDesignatedOnly,
          ),
          FilterChip(
            label: const Text('편의시설 정보 있는 곳만'),
            selected: facilityInfoOnly,
            onSelected: onFacilityInfoOnly,
          ),
        ]),
        group('거리', [
          for (final km in _distances)
            ChoiceChip(
              label: Text('$km km 안'),
              selected: withinKm == km,
              // 고른 거리를 다시 누르면 거리 제한을 끈다.
              onSelected: (on) => onWithinKm(on ? km : null),
            ),
        ]),
      ],
    );
  }
}

/// 결과가 없을 때 조건을 넓히는 방법 (디자인 톤의 연한 초록 상자).
class _WidenCard extends StatelessWidget {
  const _WidenCard({
    required this.filtered,
    required this.neighbors,
    required this.onClearFilters,
    required this.onNeighbors,
    required this.onChangeNeed,
  });

  final bool filtered;
  final List<Region> neighbors;
  final VoidCallback onClearFilters;
  final VoidCallback onNeighbors;
  final VoidCallback onChangeNeed;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final tall = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(52)));
    return SectionBox(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionTitle('조건을 넓혀 볼까요?'),
          const SizedBox(height: 12),
          if (filtered) ...[
            FilledButton(
              style: tall,
              onPressed: onClearFilters,
              child: const Text('거르기 모두 끄기'),
            ),
            const SizedBox(height: 8),
          ],
          if (neighbors.isNotEmpty) ...[
            Text(
              '${neighbors.map((r) => r.name).join(', ')}까지 찾아요.',
              style: TextStyle(fontSize: 14, color: c.textSecondary),
            ),
            const SizedBox(height: 6),
            if (filtered)
              OutlinedButton(style: tall, onPressed: onNeighbors, child: const Text('이웃 시·도까지 찾기'))
            else
              FilledButton(style: tall, onPressed: onNeighbors, child: const Text('이웃 시·도까지 찾기')),
            const SizedBox(height: 8),
          ],
          OutlinedButton(
            style: tall,
            onPressed: onChangeNeed,
            child: const Text('진료 목적 바꾸기'),
          ),
        ],
      ),
    );
  }
}

/// 결과 카드 (디자인: 연한 초록, 둥근 20, 이름 16/800, 회색 설명, 오른쪽 하트, 흰 꼬리표).
/// 화면낭독기는 카드를 한 번에 '번호. 이름, 거리, 지정 기관, 추천 이유, 경고' 순으로 읽고, 하트는 따로 읽는다.
class _ResultCard extends StatelessWidget {
  const _ResultCard({
    required this.rank,
    required this.rec,
    required this.favorite,
    required this.onTap,
    required this.onToggle,
  });

  final int rank;
  final Recommendation rec;
  final bool favorite;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final h = rec.hospital;
    final distance = kmLabel(rec.distanceKm);
    // 추천 이유는 세 개까지만 보여 주고, 나머지는 병원 정보에서 본다.
    final reasons = rec.reasons.take(3).toList();
    final warning = rec.missing.isEmpty
        ? null
        : '없다고 확인됨: ${rec.missing.map((f) => f.label).join(', ')}';
    final label = [
      '$rank. ${h.name}',
      distance,
      if (rec.designated) '정부 지정 기관',
      ...reasons,
      if (warning != null) '확인 필요, $warning',
    ].join(', ');
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Semantics(
            button: true,
            label: label,
            onTap: onTap,
            excludeSemantics: true,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 오른쪽 위의 하트 자리를 비워 둔다.
                    Padding(
                      padding: const EdgeInsets.only(right: 44),
                      child: Text(
                        '$rank. ${h.name}',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                          height: 1.35,
                          color: c.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        if (h.kind.isNotEmpty) h.kind,
                        if (h.district.isNotEmpty) h.district,
                        distance,
                      ].join(' · '),
                      style: TextStyle(fontSize: 13, height: 1.45, color: c.textSecondary),
                    ),
                    if (rec.designated) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.verified, size: 18, color: c.brandDeep),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              '정부 지정 기관',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.brandDeep,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (reasons.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 5,
                        runSpacing: 5,
                        children: [for (final r in reasons) TagChip(r, onCard: true)],
                      ),
                    ],
                    if (warning != null) ...[
                      const SizedBox(height: 8),
                      // 경고는 색만이 아니라 아이콘과 글로 알린다.
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                        decoration: BoxDecoration(
                          color: c.warningContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: c.warning),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                '확인 필요 · $warning',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: c.warning,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 4,
            right: 4,
            child: HeartButton(name: h.name, favorite: favorite, onPressed: onToggle),
          ),
        ],
      ),
    );
  }
}
