import 'dart:async';

import 'package:flutter/material.dart';

import '../data/regions.dart';
import '../models/hospital.dart';
import '../models/korean.dart';
import '../services/recommender.dart';
import 'app_scope.dart';
import 'care_card_screen.dart';
import 'data_notice.dart';
import 'help.dart';
import 'hospital_actions.dart';
import 'report_screen.dart';

class HospitalDetailScreen extends StatefulWidget {
  const HospitalDetailScreen({
    super.key,
    required this.hospital,
    this.recommendation,
  });

  final Hospital hospital;

  /// 추천 결과에서 열었을 때의 거리와 추천 이유. 검색·즐겨찾기에서 열면 없다.
  final Recommendation? recommendation;

  @override
  State<HospitalDetailScreen> createState() => _HospitalDetailScreenState();
}

class _HospitalDetailScreenState extends State<HospitalDetailScreen> {
  late final AppServices _services = AppScope.of(context);
  late final Future<DataInfo> _info = _services.repository.loadInfo();

  @override
  void initState() {
    super.initState();
    unawaited(_services.recent.add(widget.hospital));
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hospital;
    final rec = widget.recommendation;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(h.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(h.name, style: theme.textTheme.headlineSmall),
          if (h.kind.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.local_hospital),
              title: Text(h.kind),
            ),
          ListTile(
            leading: const Icon(Icons.place),
            title: Text(h.address),
            subtitle: rec == null ? null : Text('약 ${rec.distanceKm.toStringAsFixed(1)}km'),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(h.phone.isEmpty ? '전화번호 정보가 없어요' : h.phone),
          ),
          if (h.doctors > 0)
            ListTile(
              leading: const Icon(Icons.medical_services),
              title: Text('의사 ${h.doctors}명'),
              subtitle: h.specialists > 0 ? Text('그중 전문의 ${h.specialists}명') : null,
            ),
          if (h.openedYear case final year?)
            ListTile(
              leading: const Icon(Icons.event),
              title: Text('$year년 개원'),
            ),
          if (h.homepage.isNotEmpty)
            ListTile(
              leading: const Icon(Icons.public),
              title: const Text('홈페이지'),
              subtitle: Text(h.homepage),
              onTap: () => openExternal(context, Uri.parse(h.homepage)),
            ),
          if (rec != null && rec.missing.isNotEmpty) _MissingWarning(missing: rec.missing),
          const SizedBox(height: 8),
          _Actions(hospital: h),
          if (rec != null)
            _Section(
              title: '추천 이유',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final reason in rec.reasons)
                    _Line(icon: Icons.check_circle, color: theme.colorScheme.primary, text: reason),
                ],
              ),
            ),
          if (h.notes.isNotEmpty || h.categories.isNotEmpty) _DesignationSection(hospital: h),
          if (h.departments.isNotEmpty)
            _Section(
              title: '진료과목',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final d in h.departments) Chip(label: Text(d))],
              ),
            ),
          _FacilitySection(hospital: h, wanted: rec?.wanted ?? const {}),
          const _Section(
            title: '진료 시간',
            child: Text('진료 시간과 쉬는 날은 병원에 전화로 확인하세요.'),
          ),
          FutureBuilder(
            future: _info,
            builder: (context, snapshot) => DataNotice(info: snapshot.data, emergency: true),
          ),
          if (_services.contactEmail.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.flag_outlined),
                label: const Text('정보가 틀렸어요'),
                onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ReportScreen(hospital: h),
                )),
              ),
            ),
        ],
      ),
    );
  }
}

/// 전화·길찾기·즐겨찾기·공유·지도·진료 카드. 글자가 크면 한 줄에 하나씩 놓는다.
class _Actions extends StatelessWidget {
  const _Actions({required this.hospital});

  final Hospital hospital;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final h = hospital;
    final wide = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)));
    return ListenableBuilder(
      listenable: Listenable.merge([services.favorites, services.careCard]),
      builder: (context, _) {
        final favorite = services.favorites.contains(h.id);
        final buttons = <Widget>[
          FilledButton.icon(
            style: wide,
            icon: const Icon(Icons.call),
            label: const Text('전화하기'),
            onPressed: h.phone.isEmpty ? null : () => callPhone(context, h.phone),
          ),
          OutlinedButton.icon(
            style: wide,
            icon: const Icon(Icons.directions),
            label: const Text('길찾기'),
            onPressed: () => openDirections(context, h),
          ),
          OutlinedButton.icon(
            style: wide,
            icon: Icon(favorite ? Icons.star : Icons.star_border),
            label: Text(favorite ? '즐겨찾기에서 빼기' : '즐겨찾기에 넣기'),
            onPressed: () => services.favorites.toggle(h),
          ),
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              style: wide,
              icon: const Icon(Icons.share),
              label: const Text('공유하기'),
              onPressed: () => shareHospital(buttonContext, h),
            ),
          ),
          OutlinedButton.icon(
            style: wide,
            icon: const Icon(Icons.map_outlined),
            label: const Text('지도에서 보기'),
            onPressed: () => openOnMap(context, h),
          ),
          if (services.careCard.card != null)
            FilledButton.tonalIcon(
              style: wide,
              icon: const Icon(Icons.badge),
              label: const Text('진료 카드 보여 주기'),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const ShowCardScreen(),
              )),
            ),
        ];
        return LayoutBuilder(builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final perRow = constraints.maxWidth / scale >= 300 ? 2 : 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < buttons.length; i += perRow)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var j = i; j < i + perRow; j++) ...[
                        if (j > i) const SizedBox(width: 12),
                        Expanded(
                          child: j < buttons.length ? buttons[j] : const SizedBox.shrink(),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          );
        });
      },
    );
  }
}

/// 필요한데 없다고 확인된 편의시설. 눈에 잘 띄게 위쪽에 둔다.
class _MissingWarning extends StatelessWidget {
  const _MissingWarning({required this.missing});

  final List<Facility> missing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final names = missing.map((f) => f.label).join(', ');
    return Card.filled(
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber, color: theme.colorScheme.onErrorContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '확인 필요: 필요하신 ${subjectParticle(names)} 없다고 확인됐어요. 방문 전에 전화로 확인하세요.',
                style: TextStyle(color: theme.colorScheme.onErrorContainer),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DesignationSection extends StatelessWidget {
  const _DesignationSection({required this.hospital});

  final Hospital hospital;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _Section(
      title: '지정 현황',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in hospital.notes)
            _Line(icon: Icons.verified, color: theme.colorScheme.primary, text: note),
          for (final c in InstitutionCategory.values)
            if (hospital.categories.contains(c))
              TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.help_outline),
                label: Text(categoryQuestion(c)),
                onPressed: () => showCategoryHelp(context, c),
              ),
        ],
      ),
    );
  }
}

/// 편의시설을 있음·없음·정보 없음으로 나눠 보여 준다. 정보 없음을 없음으로 보여 주지 않는다.
class _FacilitySection extends StatelessWidget {
  const _FacilitySection({required this.hospital, required this.wanted});

  final Hospital hospital;

  /// 사용자 조건에 필요한 시설. '필요'라고 덧붙인다.
  final Set<Facility> wanted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!hospital.hasFacilityInfo) {
      final names = [
        for (final f in Facility.values)
          if (wanted.contains(f)) f.label,
      ].join(', ');
      return _Section(
        title: '편의시설',
        child: _Line(
          icon: Icons.help_outline,
          color: theme.colorScheme.onSurfaceVariant,
          text: names.isEmpty
              ? '편의시설 정보가 아직 없어요. 방문 전에 전화로 확인하세요.'
              : '필요하신 $names 정보가 아직 없어요. 방문 전에 전화로 확인하세요.',
        ),
      );
    }
    return _Section(
      title: '편의시설',
      child: Column(
        children: [
          for (final f in Facility.values)
            MergeSemantics(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    switch (hospital.facilityStatus(f)) {
                      FacilityStatus.present =>
                        Icon(Icons.check_circle, color: theme.colorScheme.primary),
                      FacilityStatus.absent => Icon(Icons.cancel, color: theme.colorScheme.error),
                      FacilityStatus.unknown =>
                        Icon(Icons.help_outline, color: theme.colorScheme.onSurfaceVariant),
                    },
                    const SizedBox(width: 12),
                    Expanded(child: Text(wanted.contains(f) ? '${f.label} (필요)' : f.label)),
                    const SizedBox(width: 12),
                    Text(hospital.facilityStatus(f).label, style: theme.textTheme.labelLarge),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.color, required this.text});

  final IconData icon;
  final Color color;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}
