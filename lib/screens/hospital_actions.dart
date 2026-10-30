import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/hospital.dart';
import '../ui/tokens.dart';

// 병원 정보·즐겨찾기 화면이 함께 쓰는 전화·지도·길찾기·공유.

/// 네이버 지도 웹에서 병원을 찾는 주소. 앱이 없을 때와 공유할 때 쓴다.
Uri naverMapSearch(Hospital h) => Uri.https(
    'map.naver.com', '/p/search/${[h.district, h.name].where((s) => s.isNotEmpty).join(' ')}');

/// 가족 등에게 보낼 병원 정보.
String shareText(Hospital h) => [
      '[$appName] ${h.name}',
      [h.kind, h.district].where((s) => s.isNotEmpty).join(' · '),
      '주소: ${h.address}',
      if (h.phone.isNotEmpty) '전화: ${h.phone}',
      '지도: ${naverMapSearch(h)}',
    ].where((line) => line.isNotEmpty).join('\n');

/// [uri] 를 다른 앱(전화, 브라우저 등)으로 연다. 열 앱이 없으면 알려 준다.
Future<void> openExternal(BuildContext context, Uri uri) async {
  var opened = false;
  try {
    opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    // 아래에서 알린다.
  }
  if (!opened && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('앱을 열 수 없어요.')),
    );
  }
}

Future<void> callPhone(BuildContext context, String phone) =>
    openExternal(context, Uri(scheme: 'tel', path: phone));

/// [app] 주소로 네이버 지도 앱을 열고, 앱이 없으면 [web] 을 연다.
/// 네이버 지도 URL Scheme 은 appname(앱 패키지 이름)이 필수다.
Future<void> _openMapApp(BuildContext context, String app, Uri web) async {
  try {
    final uri = Uri.parse('$app&appname=kr.hamkkehospital.app');
    if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
  } on PlatformException {
    // 네이버 지도 앱이 설치되어 있지 않다.
  }
  if (context.mounted) await openExternal(context, web);
}

/// 병원 위치를 네이버 지도에서 보여준다.
Future<void> openOnMap(BuildContext context, Hospital h) => _openMapApp(
      context,
      'nmap://place?lat=${h.lat}&lng=${h.lng}&name=${Uri.encodeComponent(h.name)}',
      naverMapSearch(h),
    );

/// 네이버 지도에서 [query] 를 찾는다 (홈의 '지도에서 찾기'). 위치는 지도 앱이 스스로 쓰고 이 앱은 받지 않는다.
Future<void> openMapSearch(BuildContext context, String query) => _openMapApp(
      context,
      'nmap://search?query=${Uri.encodeComponent(query)}',
      Uri.https('map.naver.com', '/p/search/$query'),
    );

/// 지금 있는 곳에서 병원까지 대중교통 길찾기. 네이버 지도 앱이 없으면 카카오맵 웹 길찾기를 연다
/// (네이버 지도 웹은 좌표로 길찾기를 여는 주소가 없다).
Future<void> openDirections(BuildContext context, Hospital h) => _openMapApp(
      context,
      'nmap://route/public?dlat=${h.lat}&dlng=${h.lng}&dname=${Uri.encodeComponent(h.name)}',
      Uri.parse('https://map.kakao.com/link/to/${Uri.encodeComponent(h.name)},${h.lat},${h.lng}'),
    );

/// [buttonContext] 는 누른 버튼. 아이패드는 공유 창을 띄울 위치가 있어야 한다.
Future<void> shareHospital(BuildContext buttonContext, Hospital h) async {
  final box = buttonContext.findRenderObject() as RenderBox?;
  await SharePlus.instance.share(ShareParams(
    text: shareText(h),
    subject: h.name,
    sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
  ));
}
