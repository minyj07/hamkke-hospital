// 메디움 로고(assets/brand/logo.svg)로 앱 아이콘·스플래시 원본 PNG 를 그린다. 앱과 같은 렌더러(flutter_svg)를 쓴다.
//
// 평소 테스트에서는 건너뛴다. 로고를 바꿨을 때만 이렇게 돌린 뒤 런처 아이콘을 다시 만든다:
//   RENDER_ICONS=1 flutter test test/tools/render_brand_icons_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

const _aspect = 127 / 104; // 로고 너비:높이 (logo.svg 의 viewBox)

void main() {
  final enabled = Platform.environment.containsKey('RENDER_ICONS');

  testWidgets('메디움 로고로 아이콘·스플래시 PNG 를 그린다', skip: !enabled, (tester) async {
    final svg = File('assets/brand/logo.svg').readAsStringSync();
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget logo(double width, {Color? silhouette}) => SvgPicture.string(
          svg,
          width: width,
          height: width / _aspect,
          colorFilter: silhouette == null ? null : ColorFilter.mode(silhouette, BlendMode.srcIn),
        );

    // iOS·예전 안드로이드 아이콘: 흰 바탕(불투명), 로고는 너비 70%.
    await _render(tester, 1024, Colors.white, logo(1024 * 0.70), 'assets/icon/icon.png');
    // 적응형 아이콘 앞면: 투명 바탕. flutter_launcher_icons 가 16% 안쪽으로 넣고 런처가 동그랗게 자르므로
    // 로고 대각선이 안전 영역(앞면 너비의 90%) 안에 들게 너비 58% 로 한다.
    await _render(tester, 1024, null, logo(1024 * 0.58), 'assets/icon/icon_foreground.png');
    // 안드로이드 13 테마 아이콘: 같은 모양의 흰 실루엣.
    await _render(tester, 1024, null, logo(1024 * 0.58, silhouette: Colors.white), 'assets/icon/icon_monochrome.png');
    // 안드로이드 11 이하 스플래시 가운데 로고 (xxxhdpi 384px = 96dp).
    await _render(tester, 384, null, logo(384), 'android/app/src/main/res/drawable-xxxhdpi/splash_logo.png',
        height: (384 / _aspect).roundToDouble());
  });
}

Future<void> _render(
  WidgetTester tester,
  double width,
  Color? background,
  Widget child,
  String path, {
  double? height,
}) async {
  final key = GlobalKey();
  await tester.pumpWidget(Directionality(
    textDirection: TextDirection.ltr,
    child: Align(
      alignment: Alignment.topLeft,
      child: RepaintBoundary(
        key: key,
        child: Container(
          width: width,
          height: height ?? width,
          color: background,
          alignment: Alignment.center,
          child: child,
        ),
      ),
    ),
  ));
  // SVG 는 따로 읽어서 그리므로 끝날 때까지 기다린다.
  for (var i = 0; i < 5; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List();
  });
  File(path)
    ..parent.createSync(recursive: true)
    ..writeAsBytesSync(bytes!);
}
