// 메디움 앱 아이콘(assets/icon/app_icon.svg, 2026-10-30 사용자가 준 medium.svg)으로 앱 아이콘·스플래시 원본 PNG 를 그린다.
// 앱과 같은 렌더러(flutter_svg)를 쓴다. 앱 안의 로고(assets/brand/logo.svg)는 따로다.
//
// 평소 테스트에서는 건너뛴다. 아이콘을 바꿨을 때만 이렇게 돌린 뒤 런처 아이콘을 다시 만든다:
//   RENDER_ICONS=1 flutter test test/tools/render_brand_icons_test.dart
//   dart run flutter_launcher_icons
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// 아이콘(160×160)에서 여백을 뺀 그림 부분. 안드로이드 11 이하 스플래시 가운데에 쓴다.
const _splashViewBox = '36 36 98 80';
const _splashAspect = 98 / 80;

void main() {
  final enabled = Platform.environment.containsKey('RENDER_ICONS');

  testWidgets('메디움 아이콘으로 앱 아이콘·스플래시 PNG 를 그린다', skip: !enabled, (tester) async {
    final svg = File('assets/icon/app_icon.svg').readAsStringSync();
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Widget icon(double size, {Color? silhouette}) => SvgPicture.string(
          svg,
          width: size,
          height: size,
          colorFilter: silhouette == null ? null : ColorFilter.mode(silhouette, BlendMode.srcIn),
        );

    // iOS·예전 안드로이드 아이콘: 흰 바탕(불투명)에 아이콘 그림을 여백까지 그대로.
    await _render(tester, 1024, Colors.white, icon(1024), 'assets/icon/icon.png');
    // 적응형 아이콘 앞면: 투명 바탕. flutter_launcher_icons 가 16% 안쪽으로 넣고 런처가 동그랗게 자른다.
    // 그림 부분이 너비의 약 59% 라서 줄어든 뒤에도 안전 영역(지름 66dp/108dp) 안에 든다.
    await _render(tester, 1024, null, icon(1024), 'assets/icon/icon_foreground.png');
    // 안드로이드 13 테마 아이콘: 같은 모양의 흰 실루엣.
    await _render(tester, 1024, null, icon(1024, silhouette: Colors.white), 'assets/icon/icon_monochrome.png');
    // 안드로이드 11 이하 스플래시 가운데 그림 (xxxhdpi 384px = 96dp): 여백을 뺀 그림 부분.
    // 흰색으로 흐려지는 끝은 투명하게 한다: 밝은 바탕에서는 같고, 다크 모드 스플래시(#0F1513)에 흰 얼룩이 생기지 않는다.
    final splash = svg
        .replaceFirst('viewBox="0 0 160 160"', 'viewBox="$_splashViewBox"')
        .replaceAll('stop-color="#fff"/>', 'stop-color="#fff" stop-opacity="0"/>');
    await _render(
      tester,
      384,
      null,
      SvgPicture.string(splash, width: 384, height: 384 / _splashAspect),
      'android/app/src/main/res/drawable-xxxhdpi/splash_logo.png',
      height: (384 / _splashAspect).roundToDouble(),
    );
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
