import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/favorites.dart';
import '../models/hospital.dart';
import '../services/recommender.dart';

/// 네이버 지도 웹에서 병원을 찾는 주소. 앱이 없을 때와 공유할 때 쓴다.
Uri naverMapSearch(Hospital h) => Uri.https(
    'map.naver.com', '/p/search/${[h.district, h.name].where((s) => s.isNotEmpty).join(' ')}');

/// 가족 등에게 보낼 병원 정보.
String shareText(Hospital h) => [
      '[함께병원] ${h.name}',
      [h.kind, h.district].where((s) => s.isNotEmpty).join(' · '),
      '주소: ${h.address}',
      if (h.phone.isNotEmpty) '전화: ${h.phone}',
      '지도: ${naverMapSearch(h)}',
    ].where((line) => line.isNotEmpty).join('\n');

class HospitalDetailScreen extends StatelessWidget {
  const HospitalDetailScreen({
    super.key,
    required this.hospital,
    required this.favorites,
    this.recommendation,
  });

  final Hospital hospital;
  final Favorites favorites;

  /// 추천 결과에서 열었을 때의 거리와 추천 이유. 검색·즐겨찾기에서 열면 없다.
  final Recommendation? recommendation;

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앱을 열 수 없어요.')),
      );
    }
  }

  /// [app] 주소로 네이버 지도 앱을 열고, 앱이 없으면 [web] 을 연다.
  /// 네이버 지도 URL Scheme 은 appname(앱 패키지 이름)이 필수다.
  Future<void> _openMapApp(BuildContext context, String app, Uri web) async {
    try {
      final uri = Uri.parse('$app&appname=kr.hamkkehospital.app');
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } on PlatformException {
      // 네이버 지도 앱이 설치되어 있지 않다.
    }
    if (context.mounted) await _open(context, web);
  }

  /// 병원 위치를 네이버 지도에서 보여준다.
  void _openMap(BuildContext context, Hospital h) => _openMapApp(
        context,
        'nmap://place?lat=${h.lat}&lng=${h.lng}&name=${Uri.encodeComponent(h.name)}',
        naverMapSearch(h),
      );

  /// 지금 있는 곳에서 병원까지 대중교통 길찾기. 네이버 지도 앱이 없으면 카카오맵 웹 길찾기를 연다
  /// (네이버 지도 웹은 좌표로 길찾기를 여는 주소가 없다).
  void _openDirections(BuildContext context, Hospital h) => _openMapApp(
        context,
        'nmap://route/public?dlat=${h.lat}&dlng=${h.lng}&dname=${Uri.encodeComponent(h.name)}',
        Uri.parse('https://map.kakao.com/link/to/${Uri.encodeComponent(h.name)},${h.lat},${h.lng}'),
      );

  Future<void> _share(BuildContext buttonContext, Hospital h) async {
    // 아이패드는 공유 창을 띄울 위치가 있어야 한다.
    final box = buttonContext.findRenderObject() as RenderBox?;
    await SharePlus.instance.share(ShareParams(
      text: shareText(h),
      subject: h.name,
      sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final h = hospital;
    final rec = recommendation;
    final wide = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)));
    return Scaffold(
      appBar: AppBar(
        title: Text(h.name),
        actions: [
          ListenableBuilder(
            listenable: favorites,
            builder: (context, _) {
              final on = favorites.contains(h.id);
              return IconButton(
                icon: Icon(on ? Icons.star : Icons.star_border),
                tooltip: on ? '즐겨찾기에서 빼기' : '즐겨찾기에 넣기',
                onPressed: () => favorites.toggle(h),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
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
              onTap: () => _open(context, Uri.parse(h.homepage)),
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: wide,
                  icon: const Icon(Icons.call),
                  label: const Text('전화하기'),
                  onPressed: h.phone.isEmpty
                      ? null
                      : () => _open(context, Uri(scheme: 'tel', path: h.phone)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  style: wide,
                  icon: const Icon(Icons.map),
                  label: const Text('네이버 지도'),
                  onPressed: () => _openMap(context, h),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: wide,
                  icon: const Icon(Icons.directions),
                  label: const Text('길찾기'),
                  onPressed: () => _openDirections(context, h),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Builder(
                  builder: (buttonContext) => OutlinedButton.icon(
                    style: wide,
                    icon: const Icon(Icons.share),
                    label: const Text('공유하기'),
                    onPressed: () => _share(buttonContext, h),
                  ),
                ),
              ),
            ],
          ),
          if (rec != null) _Section(title: '추천 이유', items: rec.reasons),
          _Section(title: '지정 현황', items: h.notes),
          _Section(title: '진료과목', items: h.departments.toList()),
          _Section(
            title: '편의시설',
            items: [
              for (final f in Facility.values)
                if (h.facilities.contains(f)) f.label,
            ],
          ),
          if (rec != null && rec.missing.isNotEmpty)
            _Section(
              title: '방문 전 확인하세요',
              items: [for (final f in rec.missing) '${f.label} 정보가 없어요'],
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [for (final i in items) Chip(label: Text(i))],
          ),
        ],
      ),
    );
  }
}
