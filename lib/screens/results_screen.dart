import 'package:flutter/material.dart';

import '../data/hospital_repository.dart';
import '../data/regions.dart';
import '../models/hospital.dart';
import '../models/user_profile.dart';
import '../services/recommender.dart';
import 'hospital_detail_screen.dart';
import 'retry_message.dart';

class ResultsScreen extends StatefulWidget {
  const ResultsScreen({
    super.key,
    required this.repository,
    required this.profile,
  });

  final HospitalRepository repository;
  final UserProfile profile;

  @override
  State<ResultsScreen> createState() => _ResultsScreenState();
}

class _ResultsScreenState extends State<ResultsScreen> {
  late Future<(List<Recommendation>, DataInfo)> _result = _load();

  Future<(List<Recommendation>, DataInfo)> _load() async {
    final p = widget.profile;
    final (lists, info) = await (
      Future.wait([
        for (final r in [p.region, ...p.nearbyRegions])
          widget.repository.loadHospitals(r.code),
      ]),
      widget.repository.loadInfo(),
    ).wait;
    return (recommend(p, [for (final l in lists) ...l]), info);
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
          final (results, info) = snapshot.data!;
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
                unknownFacilities: unknownFacilities,
                unmatchedTexts: buildRequirement(widget.profile).unmatchedTexts,
              ),
              const SizedBox(height: 8),
              for (final r in results) _ResultTile(rec: r),
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
    required this.unknownFacilities,
    required this.unmatchedTexts,
  });

  final UserProfile profile;
  final int count;
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
            '다른 지역이나 진료를 골라 보세요.',
          ] else ...[
            // 순서는 거리만이 아니라 recommend() 의 점수를 따른다.
            '조건에 잘 맞는 순서로 $count곳을 골랐어요.',
            '지정 기관인지, 필요한 진료과·편의시설이 있는지, 얼마나 가까운지를 함께 봤어요.',
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

class _ResultTile extends StatelessWidget {
  const _ResultTile({required this.rec});

  final Recommendation rec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = rec.hospital;
    return Card.outlined(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => HospitalDetailScreen(rec: rec),
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
