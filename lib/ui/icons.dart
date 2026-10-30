import 'package:flutter/widgets.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// 디자인(Medium Home.dc.html)에 그려진 선 아이콘. 24×24 칸에 선 굵기 2, 둥근 끝.
/// 디자인에 없는 아이콘은 머티리얼 아이콘을 쓴다.
enum DesignIcons {
  // 홈 바로가기
  find('<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2M11 8.5v5M8.5 11h5"/>'),
  card('<rect x="3" y="5" width="18" height="14" rx="2.5"/><circle cx="9" cy="11" r="2"/>'
      '<path d="M6 16c.6-1.5 1.7-2.2 3-2.2s2.4.7 3 2.2M14.5 10h3.5M14.5 13.5h3.5"/>'),
  star('<path d="M12 3.5l2.6 5.3 5.9.9-4.3 4.1 1 5.8L12 16.9l-5.2 2.7 1-5.8-4.3-4.1 5.9-.9z"/>'),
  map('<path d="M9 4L3 6.5v13.5L9 17.5l6 2.5 6-2.5V4l-6 2.5z"/><path d="M9 4v13.5M15 6.5V20"/>'),
  // 하단 탭
  home('<path d="M4 10.5L12 4l8 6.5V20h-5v-6h-6v6H4z"/>'),
  heart('<path d="M12 20s-7.5-4.6-7.5-10A4.3 4.3 0 0 1 12 7.5 4.3 4.3 0 0 1 19.5 10c0 5.4-7.5 10-7.5 10z"/>'),
  user('<circle cx="12" cy="8.5" r="3.8"/><path d="M4.5 20c1.2-3.6 4-5.5 7.5-5.5s6.3 1.9 7.5 5.5"/>'),
  // 자주 찾는 진료과
  internal('<path d="M6 3v6a4 4 0 0 0 8 0V3"/><path d="M10 13v2a5 5 0 0 0 10 0v-2"/><circle cx="20" cy="11" r="2"/>'),
  orthopedic('<path d="M8 4a2 2 0 1 0-3 2.5L15.5 17A2 2 0 1 0 19 19.5a2 2 0 1 0-1.5-3.5L7 5.5A2 2 0 0 0 8 4z"/>'),
  neurology('<path d="M12 5a3.5 3.5 0 0 0-6.5 1.5A3.5 3.5 0 0 0 4 12a3.5 3.5 0 0 0 2 5.5A3.5 3.5 0 0 0 12 19z'
      'M12 5a3.5 3.5 0 0 1 6.5 1.5A3.5 3.5 0 0 1 20 12a3.5 3.5 0 0 1-2 5.5A3.5 3.5 0 0 1 12 19z"/><path d="M12 5v14"/>'),
  surgery('<rect x="3" y="9" width="18" height="6" rx="3" transform="rotate(-45 12 12)"/>'
      '<path d="M10 10h.01M14 14h.01M12 12h.01"/>'),
  // 검색창·제목
  searchPin('<path d="M12 21s-7-6.2-7-11.5A7 7 0 0 1 19 9.5C19 14.8 12 21 12 21z"/><path d="M12 7v5M9.5 9.5h5"/>'),
  search('<circle cx="11" cy="11" r="6.5"/><path d="M20 20l-4.2-4.2"/>'),
  pin('<path d="M12 22s-7-6.5-7-12a7 7 0 0 1 14 0c0 5.5-7 12-7 12z"/><circle cx="12" cy="10" r="2.5"/>'),
  back('<path d="M19 12H5M11 6l-6 6 6 6"/>'),
  check('<path d="M5 12.5l4.5 4.5L19 7.5"/>'),
  close('<path d="M7 7l10 10M17 7L7 17"/>'),
  // 병원 정보
  kind('<rect x="4" y="4" width="16" height="16" rx="3"/><path d="M12 8v8M8 12h8"/>'),
  phone('<path d="M5 4h4l2 5-2.5 1.5a11 11 0 0 0 5 5L15 13l5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2z"/>'),
  doctor('<rect x="3" y="7" width="18" height="13" rx="2.5"/><path d="M9 7V5h6v2M12 11v5M9.5 13.5h5"/>'),
  calendar('<rect x="4" y="5" width="16" height="15" rx="2.5"/><path d="M4 10h16M9 3v4M15 3v4"/>'),
  route('<path d="M12 2.5l9.5 9.5-9.5 9.5L2.5 12z"/><path d="M9 14v-2.5h5.5M12.5 9l2.5 2.5-2.5 2.5"/>'),
  share('<circle cx="18" cy="5.5" r="2.5"/><circle cx="6" cy="12" r="2.5"/><circle cx="18" cy="18.5" r="2.5"/>'
      '<path d="M8.2 10.8l7.6-4M8.2 13.2l7.6 4"/>');

  const DesignIcons(this.body);

  /// 24×24 SVG 의 속 내용 (선 색은 currentColor).
  final String body;
}

/// 디자인 선 아이콘. 색과 크기를 정하지 않으면 [IconTheme] 을 따른다. 장식이라 화면낭독기는 읽지 않는다.
class DesignIcon extends StatelessWidget {
  const DesignIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.strokeWidth = 2,
    this.filled = false,
  });

  final DesignIcons icon;
  final double? size;
  final Color? color;
  final double strokeWidth;

  /// 속을 채운다 (예: 즐겨찾기한 하트).
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final theme = IconTheme.of(context);
    final size = this.size ?? theme.size ?? 24;
    final color = this.color ?? theme.color ?? const Color(0xFF191D21);
    final fill = filled ? 'currentColor' : 'none';
    return SvgPicture.string(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" fill="$fill" stroke="currentColor" '
      'stroke-width="$strokeWidth" stroke-linecap="round" stroke-linejoin="round">${icon.body}</svg>',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
      excludeFromSemantics: true,
    );
  }
}

/// 메디움 로고 (assets/brand/logo.svg). 장식이라 화면낭독기는 읽지 않는다 (옆의 글이 이름을 말한다).
class MediumLogo extends StatelessWidget {
  const MediumLogo({super.key, this.height = 34});

  /// 로고 높이. 너비는 logo.svg 의 viewBox 비율(127:104)을 따른다.
  final double height;

  static const aspectRatio = 127 / 104;

  @override
  Widget build(BuildContext context) => SvgPicture.asset(
        'assets/brand/logo.svg',
        height: height,
        width: height * aspectRatio,
        excludeFromSemantics: true,
      );
}
