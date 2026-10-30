import 'dart:async';

import 'package:flutter/material.dart';

import '../data/regions.dart';
import '../models/hospital.dart';
import '../models/korean.dart';
import '../services/recommender.dart';
import '../ui/format.dart';
import '../ui/icons.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';
import 'care_card_screen.dart';
import 'data_notice.dart';
import 'help.dart';
import 'hospital_actions.dart';
import 'report_screen.dart';

/// 병원 정보 (메디움 디자인): 사진 자리, 이름, 정보 줄, 2열 버튼, 추천 이유, 진료과목,
/// 그리고 지정 현황·편의시설·진료 시간·데이터 안내·정보 오류 신고.
class HospitalDetailScreen extends StatefulWidget {
  const HospitalDetailScreen({super.key, required this.hospital, this.recommendation});

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

  /// 사진 자리 칩에 쓸 진료과: 추천 이유의 '진료과: …' 첫 과(가장 잘 맞는 과), 없으면 병원의 첫 과.
  String? _bannerDepartment(Hospital h, Recommendation? rec) {
    const prefix = '진료과: ';
    final reason = rec?.reasons.where((r) => r.startsWith(prefix)).firstOrNull;
    if (reason != null) return reason.substring(prefix.length).split(', ').first;
    for (final name in departmentNames.values) {
      if (h.departments.contains(name)) return name;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.hospital;
    final rec = widget.recommendation;
    final theme = Theme.of(context);
    final c = MediumColors.of(context);
    final small = TextStyle(fontSize: 13, color: c.textSecondary);
    final dept = _bannerDepartment(h, rec);
    final bannerText = [
      dept ?? (h.kind.isEmpty ? null : h.kind),
      if (rec != null) kmLabel(rec.distanceKm),
    ].whereType<String>().join(' · ');
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '병원 정보',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
            color: c.textSecondary,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        children: [
          // 사진 자리부터 버튼까지는 병원의 첫 정보라 한 덩어리로 둔다.
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 사진 자리 (디자인: 높이 120, 둥근 20, 왼쪽 아래 흰 칩).
              ToneBox(
                id: h.id,
                height: 120,
                radius: 20,
                alignment: Alignment.bottomLeft,
                padding: const EdgeInsets.all(14),
                child: bannerText.isEmpty
                    ? null
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.85),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          bannerText,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            // 칩 바탕이 늘 흰색이라 다크 모드에서도 밝은 화면의 짙은 초록을 쓴다.
                            color: Color(0xFF2A735F),
                          ),
                        ),
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(2, 20, 2, 0),
                child: Semantics(
                  header: true,
                  child: Text(
                    h.name,
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontSize: 25,
                      letterSpacing: -0.7,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (h.kind.isNotEmpty) InfoRow(icon: DesignIcons.kind, child: Text(h.kind)),
                    InfoRow(
                      icon: DesignIcons.pin,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(h.address, style: const TextStyle(height: 1.5)),
                          if (rec != null) ...[
                            const SizedBox(height: 2),
                            Text(kmLabel(rec.distanceKm), style: small),
                          ],
                        ],
                      ),
                    ),
                    InfoRow(
                      icon: DesignIcons.phone,
                      child: Text(h.phone.isEmpty ? '전화번호 정보가 없어요' : h.phone),
                    ),
                    if (h.doctors > 0)
                      InfoRow(
                        icon: DesignIcons.doctor,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('의사 ${h.doctors}명'),
                            if (h.specialists > 0) ...[
                              const SizedBox(height: 2),
                              Text('그중 전문의 ${h.specialists}명', style: small),
                            ],
                          ],
                        ),
                      ),
                    if (h.openedYear case final year?)
                      InfoRow(icon: DesignIcons.calendar, child: Text('$year년 개원')),
                    if (h.homepage.isNotEmpty) _HomepageRow(url: h.homepage),
                  ].expand((row) => [row, const SizedBox(height: 18)]).toList()..removeLast(),
                ),
              ),
              if (rec != null && rec.missing.isNotEmpty) ...[
                const SizedBox(height: 20),
                _MissingWarning(missing: rec.missing),
              ],
              const SizedBox(height: 24),
              _Actions(hospital: h),
            ],
          ),
          if (rec != null) ...[
            const SizedBox(height: 16),
            SectionBox(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SectionTitle('추천 이유'),
                  const SizedBox(height: 12),
                  for (final (i, reason) in rec.reasons.indexed) ...[
                    if (i > 0) const SizedBox(height: 10),
                    CheckLine(reason),
                  ],
                ],
              ),
            ),
          ],
          if (h.notes.isNotEmpty || h.categories.isNotEmpty) _DesignationSection(hospital: h),
          if (h.departments.isNotEmpty)
            _Section(
              title: '진료과목',
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // 심평원 진료과목 순서로 늘어놓는다.
                  for (final name in departmentNames.values)
                    if (h.departments.contains(name)) _DepartmentChip(name),
                ],
              ),
            ),
          _FacilitySection(hospital: h, wanted: rec?.wanted ?? const {}),
          const _Section(title: '진료 시간', child: Text('진료 시간과 쉬는 날은 병원에 전화로 확인하세요.')),
          FutureBuilder(
            future: _info,
            builder: (context, snapshot) => DataNotice(info: snapshot.data, emergency: true),
          ),
          if (_services.contactEmail.isNotEmpty)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                icon: const Icon(Icons.flag_outlined, size: 20),
                label: const Text('정보가 틀렸어요'),
                onPressed: () =>
                    Navigator.of(context)
                        .push(MaterialPageRoute(builder: (_) => ReportScreen(hospital: h))),
              ),
            ),
        ],
      ),
    );
  }
}

/// 홈페이지 줄. 디자인의 정보 줄과 같은 모양이고 누르면 브라우저로 연다.
class _HomepageRow extends StatelessWidget {
  const _HomepageRow({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Semantics(
      link: true,
      label: '홈페이지, $url',
      onTap: () => openExternal(context, Uri.parse(url)),
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => openExternal(context, Uri.parse(url)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 48),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: c.container,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.language, size: 20, color: c.brandDeep),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('홈페이지', style: TextStyle(fontSize: 15, color: c.text)),
                      const SizedBox(height: 2),
                      Text(
                        url,
                        style: TextStyle(
                          fontSize: 13,
                          color: c.link,
                          decoration: TextDecoration.underline,
                          decorationColor: c.link,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 진료과목 칩 (디자인: 높이 38, 둥근 12, 테두리).
class _DepartmentChip extends StatelessWidget {
  const _DepartmentChip(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Container(
      constraints: const BoxConstraints(minHeight: 38),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.border, width: 1.5),
      ),
      child: Text(
        name,
        style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: c.text),
      ),
    );
  }
}

/// 전화·길찾기·즐겨찾기·공유·지도·진료 카드 (디자인: 2열, 높이 52 알약). 글자가 크면 한 줄에 하나씩 놓는다.
class _Actions extends StatelessWidget {
  const _Actions({required this.hospital});

  final Hospital hospital;

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final c = MediumColors.of(context);
    final h = hospital;
    const height = Size.fromHeight(52);
    final outlined = OutlinedButton.styleFrom(minimumSize: height);
    Widget icon(DesignIcons i) => DesignIcon(i, size: 18, strokeWidth: 2.3);
    return ListenableBuilder(
      listenable: Listenable.merge([services.favorites, services.careCard]),
      builder: (context, _) {
        final favorite = services.favorites.contains(h.id);
        final buttons = <Widget>[
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: height,
              textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            icon: icon(DesignIcons.phone),
            label: const Text('전화하기'),
            onPressed: h.phone.isEmpty ? null : () => callPhone(context, h.phone),
          ),
          OutlinedButton.icon(
            style: outlined,
            icon: icon(DesignIcons.route),
            label: const Text('길찾기'),
            onPressed: () => openDirections(context, h),
          ),
          OutlinedButton.icon(
            // 즐겨찾기에 있으면 연한 초록 바탕에 초록 테두리 (디자인).
            style: OutlinedButton.styleFrom(
              minimumSize: height,
              backgroundColor: favorite ? c.container : c.background,
              side: BorderSide(color: favorite ? c.brand : c.border, width: 1.5),
            ),
            icon: DesignIcon(
              DesignIcons.heart,
              size: 18,
              filled: favorite,
              color: favorite ? c.heart : c.brandDeep,
            ),
            label: Text(favorite ? '즐겨찾기에서 빼기' : '즐겨찾기에 넣기'),
            onPressed: () => services.favorites.toggle(h),
          ),
          Builder(
            builder: (buttonContext) => OutlinedButton.icon(
              style: outlined,
              icon: icon(DesignIcons.share),
              label: const Text('공유하기'),
              onPressed: () => shareHospital(buttonContext, h),
            ),
          ),
          OutlinedButton.icon(
            style: outlined,
            icon: icon(DesignIcons.map),
            label: const Text('지도에서 보기'),
            onPressed: () => openOnMap(context, h),
          ),
          if (services.careCard.card != null)
            FilledButton.tonalIcon(
              style: FilledButton.styleFrom(
                minimumSize: height,
                textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              icon: icon(DesignIcons.card),
              label: const Text('진료 카드 보여 주기'),
              onPressed: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => const ShowCardScreen())),
            ),
        ];
        return LayoutBuilder(
          builder: (context, constraints) {
            final scale = MediaQuery.textScalerOf(context).scale(1);
            final perRow = constraints.maxWidth / scale >= 300 ? 2 : 1;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < buttons.length; i += perRow)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        for (var j = i; j < i + perRow; j++) ...[
                          if (j > i) const SizedBox(width: 10),
                          Expanded(
                            child: j < buttons.length ? buttons[j] : const SizedBox.shrink(),
                          ),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        );
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
    final c = MediumColors.of(context);
    final names = missing.map((f) => f.label).join(', ');
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: c.warningContainer, borderRadius: BorderRadius.circular(16)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.warning_amber_rounded, color: c.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '확인 필요: 필요하신 ${subjectParticle(names)} 없다고 확인됐어요. 방문 전에 전화로 확인하세요.',
              style: TextStyle(
                fontSize: 14.5,
                height: 1.5,
                color: c.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DesignationSection extends StatelessWidget {
  const _DesignationSection({required this.hospital});

  final Hospital hospital;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return _Section(
      title: '지정 현황',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final note in hospital.notes)
            _Line(
              icon: Icon(Icons.verified, size: 20, color: c.brand),
              text: note,
            ),
          for (final cat in InstitutionCategory.values)
            if (hospital.categories.contains(cat))
              TextButton.icon(
                style: TextButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  foregroundColor: c.link,
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                ),
                icon: const Icon(Icons.help_outline, size: 20),
                label: Text(categoryQuestion(cat)),
                onPressed: () => showCategoryHelp(context, cat),
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
    final c = MediumColors.of(context);
    if (!hospital.hasFacilityInfo) {
      final names = [
        for (final f in Facility.values)
          if (wanted.contains(f)) f.label,
      ].join(', ');
      return _Section(
        title: '편의시설',
        child: _Line(
          icon: Icon(Icons.help_outline, size: 20, color: c.textSecondary),
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
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  border: Border(bottom: BorderSide(color: c.divider)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    switch (hospital.facilityStatus(f)) {
                      FacilityStatus.present => Icon(Icons.check_circle, size: 22, color: c.brand),
                      FacilityStatus.absent => Icon(Icons.cancel, size: 22, color: c.warning),
                      FacilityStatus.unknown => Icon(
                        Icons.help_outline,
                        size: 22,
                        color: c.textSecondary,
                      ),
                    },
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        wanted.contains(f) ? '${f.label} (필요)' : f.label,
                        style: TextStyle(fontSize: 15, color: c.text),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      hospital.facilityStatus(f).label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: switch (hospital.facilityStatus(f)) {
                          FacilityStatus.present => c.brandDeep,
                          FacilityStatus.absent => c.warning,
                          FacilityStatus.unknown => c.textSecondary,
                        },
                      ),
                    ),
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
  const _Line({required this.icon, required this.text});

  final Widget icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(padding: const EdgeInsets.only(top: 1), child: icon),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.5))),
        ],
      ),
    );
  }
}

/// 섹션 제목(디자인: 17/800)과 내용.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [SectionTitle(title), const SizedBox(height: 12), child],
      ),
    );
  }
}
