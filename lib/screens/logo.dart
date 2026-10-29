import 'package:flutter/material.dart';

/// 함께병원 로고: 둥근 네모 바탕에 흰 십자, 가운데 하트. 앱 아이콘(assets/icon)과 같은 모양이다.
/// 색은 테마의 primary·onPrimary 를 따르므로 테마 색을 바꾸면 함께 바뀐다.
/// 장식이라 화면낭독기는 읽지 않는다 (옆의 글이 이름을 말한다).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 32, this.color, this.markColor});

  final double size;

  /// 바탕색. 없으면 테마의 primary.
  final Color? color;

  /// 십자색. 없으면 테마의 onPrimary.
  final Color? markColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ExcludeSemantics(
      child: CustomPaint(
        size: Size.square(size),
        painter: _LogoPainter(color ?? scheme.primary, markColor ?? scheme.onPrimary),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  const _LogoPainter(this.background, this.mark);

  final Color background;
  final Color mark;

  @override
  void paint(Canvas canvas, Size size) {
    final n = size.shortestSide;
    final center = Offset(n / 2, n / 2);
    final backgroundPaint = Paint()..color = background;
    final markPaint = Paint()..color = mark;

    // 바탕: 둥근 네모 (모서리 22%)
    canvas.drawRRect(
      RRect.fromRectAndRadius(Offset.zero & Size.square(n), Radius.circular(n * 0.22)),
      backgroundPaint,
    );

    // 십자: 둥근 막대 두 개. 아이콘과 같은 비율 (폭 64%, 굵기 22.5%)
    final span = n * 0.64;
    final arm = n * 0.225;
    final radius = Radius.circular(arm / 2);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: span, height: arm), radius),
      markPaint,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromCenter(center: center, width: arm, height: span), radius),
      markPaint,
    );

    // 하트: 십자 가운데를 바탕색으로 뚫은 모양 (폭 19.5%). 원 두 개와 아래쪽 삼각형.
    final w = n * 0.195;
    final r = w / 4;
    final heartCenter = center.translate(0, n * 0.005);
    final top = heartCenter.dy - w * 0.18;
    canvas.drawCircle(Offset(heartCenter.dx - r, top), r, backgroundPaint);
    canvas.drawCircle(Offset(heartCenter.dx + r, top), r, backgroundPaint);
    final y0 = top + r * 0.35;
    final xOff = 2 * r - r * 0.07;
    canvas.drawPath(
      Path()
        ..addPolygon([
          Offset(heartCenter.dx - xOff, y0),
          Offset(heartCenter.dx + xOff, y0),
          Offset(heartCenter.dx, heartCenter.dy + w * 0.5),
        ], true),
      backgroundPaint,
    );
  }

  @override
  bool shouldRepaint(_LogoPainter oldDelegate) =>
      oldDelegate.background != background || oldDelegate.mark != mark;
}
