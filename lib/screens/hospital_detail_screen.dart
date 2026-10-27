import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hospital.dart';
import '../services/recommender.dart';

class HospitalDetailScreen extends StatelessWidget {
  const HospitalDetailScreen({super.key, required this.rec});

  final Recommendation rec;

  Future<void> _open(BuildContext context, Uri uri) async {
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('앱을 열 수 없어요.')),
      );
    }
  }

  /// 네이버 지도 앱으로 병원 위치를 연다. 앱이 없으면 네이버 지도 웹에서 이름으로 찾는다.
  /// URL Scheme 은 appname(앱 패키지 이름)이 필수다.
  Future<void> _openNaverMap(BuildContext context, Hospital h) async {
    final app = Uri.parse(
      'nmap://place?lat=${h.lat}&lng=${h.lng}'
      '&name=${Uri.encodeComponent(h.name)}&appname=kr.hamkkehospital.app',
    );
    try {
      if (await launchUrl(app, mode: LaunchMode.externalApplication)) return;
    } on PlatformException {
      // 네이버 지도 앱이 설치되어 있지 않다.
    }
    if (!context.mounted) return;
    final query = [h.district, h.name].where((s) => s.isNotEmpty).join(' ');
    await _open(context, Uri.https('map.naver.com', '/p/search/$query'));
  }

  @override
  Widget build(BuildContext context) {
    final h = rec.hospital;
    return Scaffold(
      appBar: AppBar(title: Text(h.name)),
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
            subtitle: Text('약 ${rec.distanceKm.toStringAsFixed(1)}km'),
          ),
          ListTile(
            leading: const Icon(Icons.phone),
            title: Text(h.phone.isEmpty ? '전화번호 정보가 없어요' : h.phone),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
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
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  icon: const Icon(Icons.map),
                  label: const Text('네이버 지도'),
                  onPressed: () => _openNaverMap(context, h),
                ),
              ),
            ],
          ),
          _Section(title: '추천 이유', items: rec.reasons),
          _Section(title: '지정 현황', items: h.notes),
          _Section(title: '진료과목', items: h.departments.toList()),
          _Section(
            title: '편의시설',
            items: [
              for (final f in Facility.values)
                if (h.facilities.contains(f)) f.label,
            ],
          ),
          if (rec.missing.isNotEmpty)
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
