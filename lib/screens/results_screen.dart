import 'package:flutter/material.dart';

import '../data/favorites.dart';
import '../data/hospital_repository.dart';
import '../data/regions.dart';
import '../models/hospital.dart';
import '../models/user_profile.dart';
import '../services/recommender.dart';
import 'hospital_detail_screen.dart';
import 'retry_message.dart';

/// 결과를 늘어놓는 순서.
enum ResultOrder {
  recommended('추천순'),
  nearest('가까운 순');

  const ResultOrder(this.label);
  final String label;
}

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.repository,
    required this.favorites,
    required this.profile,
  });

  final HospitalRepository repository;
  final Favorites favorites;
  final UserProfile profile;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  /// 한 번에 보여줄 병원 수.
  static const _shown = 20;

  late Future<(List<Recommendation>, DataInfo)> _result = _load();
  ResultOrder _order = ResultOrder.recommended;
  bool _designatedOnly = false;

  /// 조건에 맞는 병원 전부 (점수순). 정렬·거르기를 바꿔도 다시 계산하지 않는다.
  Future<(List<Recommendation>, DataInfo)> _load() async {
    final p = widget.profile;
    final (lists, info) = await (
      Future.wait([
        for (final r in [p.region, ...p.nearbyRegions])
          widget.repository.loadHospitals(r.code),
      ]),
      widget.repository.loadInfo(),
    ).wait;
    return (recommend(p, [for (final l in lists) ...l], limit: null), info);
  }

  /// 고른 순서·조건으로 거른 뒤 앞의 [_shown] 곳. '가까운 순'은 맞는 병원 전체에서 가까운 곳을 고른다.
  List<Recommendation> _pick(List<Recommendation> all) {
    final picked = [for (final r in all) if (!_designatedOnly || r.designated) r];
    if (_order == ResultOrder.nearest) {
      picked.sort((a, b) => a.distanceKm.compareTo(b.distanceKm));
    }
    return picked.take(_shown).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('추천 병원')),
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
          final (all, info) = snapshot.data!;
          final results = _pick(all);
          // 편의시설 정보가 없는 병원은 카드마다 반복하지 않고 요약에서 한 번만 안내한다.
          final unknownFacilities = {
            for (final r in results)
              if (r.hospital.facilities.isEmpty) ...r.missing,
          };
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _SummaryCard(
                profile: widget.profile,
                count: results.length,
                order: _order,
                designatedOnly: _designatedOnly,
                unknownFacilities: unknownFacilities,
                unmatchedTexts: buildRequirement(widget.profile).unmatchedTexts,
              ),
              // 맞는 병원이 하나도 없으면 순서·거르기를 바꿔도 소용없다.
              if (all.isNotEmpty)
                _OrderBar(
                  order: _order,
                  designatedOnly: _designatedOnly,
                  onOrder: (order) => setState(() => _order = order),
                  onDesignatedOnly: (on) => setState(() => _designatedOnly = on),
                ),
              const SizedBox(height: 8),
              for (final r in results) _ResultTile(rec: r, favorites: widget.favorites),
              _Disclaimer(info: info),
            ],
          );
        },
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.profile,
    required this.count,
    required this.order,
    required this.designatedOnly,
    required this.unknownFacilities,
    required this.unmatchedTexts,
  });

  final UserProfile profile;
  final int count;
  final ResultOrder order;
  final bool designatedOnly;
  final Set<Facility> unknownFacilities;
  final List<String> unmatchedTexts;

  @override
  Widget build(BuildContext context) {
    final place = profile.placeLabel;
    final from = profile.location != null ? '현재 위치' : '$place 중심';
    final facilities = unknownFacilities.map((f) => f.label).join(', ');
    return Card.filled(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text([
          '${profile.typesLabel} · ${profile.needLabel} · $place',
          if (count == 0) ...[
            '조건에 맞는 병원을 찾지 못했어요.',
            designatedOnly ? '‘지정 기관만’을 끄면 더 찾을 수 있어요.' : '다른 지역이나 진료를 골라 보세요.',
          ] else ...[
            if (order == ResultOrder.recommended) ...[
              // 순서는 거리만이 아니라 recommend() 의 점수를 따른다.
              '조건에 잘 맞는 순서로 $count곳을 골랐어요.',
              '지정 기관인지, 필요한 진료과·편의시설이 있는지, 얼마나 가까운지를 함께 봤어요.',
            ] else
              '조건에 맞는 병원 중 가까운 $count곳이에요.',
            if (designatedOnly) '정부 지정 기관만 보여줘요.',
            '거리는 $from에서 잰 직선거리예요.',
          ],
          for (final text in unmatchedTexts)
            '\n‘$text’에 맞는 진료과는 찾지 못해서, 고르신 다른 조건으로 찾았어요.',
          if (unknownFacilities.isNotEmpty)
            '\n$facilities 정보는 아직 없어요. 방문 전에 전화로 확인하세요.',
        ].join('\n')),
      ),
    );
  }
}

/// 정렬(추천순·가까운 순)과 지정 기관만 보기.
class _OrderBar extends StatelessWidget {
  const _OrderBar({
    required this.order,
    required this.designatedOnly,
    required this.onOrder,
    required this.onDesignatedOnly,
  });

  final ResultOrder order;
  final bool designatedOnly;
  final ValueChanged<ResultOrder> onOrder;
  final ValueChanged<bool> onDesignatedOnly;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final o in ResultOrder.values)
            ChoiceChip(
              label: Text(o.label),
              selected: order == o,
              onSelected: (_) => onOrder(o),
            ),
          FilterChip(
            label: const Text('지정 기관만'),
            selected: designatedOnly,
            onSelected: onDesignatedOnly,
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.rec, required this.favorites});

  final Recommendation rec;
  final Favorites favorites;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = rec.hospital;
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalDetailScreen(
            hospital: h,
            recommendation: rec,
            favorites: favorites,
          ),
        )),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(h.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              Text([
                if (h.kind.isNotEmpty) h.kind,
                if (h.district.isNotEmpty) h.district,
                '약 ${rec.distanceKm.toStringAsFixed(1)}km',
              ].join(' · ')),
              const SizedBox(height: 8),
              for (final reason in rec.reasons)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.check_circle, size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 6),
                    Expanded(child: Text(reason)),
                  ],
                ),
              if (rec.missing.isNotEmpty && h.facilities.isNotEmpty)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, size: 20, color: theme.colorScheme.error),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        '확인 필요: ${rec.missing.map((f) => f.label).join(', ')}',
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Disclaimer extends StatelessWidget {
  const _Disclaimer({required this.info});

  final DataInfo info;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        '이 정보는 참고용이에요. 방문 전에 병원에 전화해서 진료 가능 여부와 '
        '편의시설을 꼭 확인하세요. 응급 상황이면 119에 전화하세요.\n\n'
        '자료: ${info.sources.join(', ')} (${info.generatedAt} 기준)',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
