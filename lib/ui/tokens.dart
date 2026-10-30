import 'package:flutter/material.dart';

/// 앱 이름. 화면 글·메일 제목·잠금 안내에 쓴다 (안드로이드·iOS 의 앱 이름은 각 설정 파일에 따로 있다).
const appName = '메디움';

/// 메디움 디자인의 색. 디자인 원본은 'Claude Design' 의 Medium Home.dc.html 이다.
///
/// 디자인 색을 그대로 쓰되, 글씨·체크 표시처럼 읽거나 알아봐야 하는 곳은 기획서 9장의
/// 명도 대비(글자 4.5:1, 테두리·아이콘 3:1)를 넘게 조금 진하게 했다. 예를 들어 디자인의 버튼 색
/// #4bae93 에 흰 글씨는 2.7:1 이라 버튼은 [brand] #2d836d(4.6:1)를 쓰고, #4bae93 은 진행 막대·장식에
/// [brandBright] 로 쓴다. 다크 모드와 고대비 색은 디자인에 없어서 같은 원칙으로 만들었다.
@immutable
class MediumColors extends ThemeExtension<MediumColors> {
  const MediumColors({
    required this.brand,
    required this.onBrand,
    required this.brandBright,
    required this.brandDeep,
    required this.link,
    required this.background,
    required this.card,
    required this.container,
    required this.containerStrong,
    required this.text,
    required this.textSecondary,
    required this.textMuted,
    required this.iconMuted,
    required this.divider,
    required this.border,
    required this.fieldBorder,
    required this.heart,
    required this.warning,
    required this.warningContainer,
    required this.toast,
    required this.onToast,
    required this.shadow,
    required this.tones,
  });

  /// 채운 버튼·체크 표시·켜진 상태의 테두리. 디자인 #4bae93 을 대비에 맞게 진하게 한 색.
  final Color brand;

  /// [brand] 위의 글씨·아이콘.
  final Color onBrand;

  /// 디자인의 민트 #4bae93. 글씨 없는 장식(진행 막대 등)에만 쓴다.
  final Color brandBright;

  /// 짙은 초록 글씨 (디자인 #2f7d68). 연한 초록 바탕 위에서도 4.5:1 을 넘는다.
  final Color brandDeep;

  /// 글자 버튼·링크 (디자인 #3a9a80 을 진하게). 흰 바탕 위에서만 쓴다.
  final Color link;

  /// 화면 바탕.
  final Color background;

  /// 병원 카드처럼 아주 연한 초록 칸 (디자인 #f3faf7).
  final Color card;

  /// 바로가기 칸·섹션·고른 칩처럼 연한 초록 칸 (디자인 #e8f6f1).
  final Color container;

  /// 고른 진료과처럼 조금 더 진한 칸 (디자인 #d3efe5).
  final Color containerStrong;

  final Color text;
  final Color textSecondary;

  /// 흐린 글씨. 디자인 #8a938f 는 글씨로 쓰기엔 흐려서 4.5:1 로 맞췄다.
  final Color textMuted;

  /// 흐린 아이콘 (빈 하트 등). 3:1 을 넘는다.
  final Color iconMuted;

  final Color divider;

  /// 칩·테두리 버튼의 테두리 (글씨가 있어 알아볼 수 있으므로 디자인 색 그대로).
  final Color border;

  /// 입력 칸·체크 상자의 테두리. 테두리만으로 알아봐야 하므로 3:1 을 넘게 했다.
  final Color fieldBorder;

  /// 즐겨찾기 하트.
  final Color heart;

  /// '확인 필요' 같은 경고 글씨와 그 바탕.
  final Color warning;
  final Color warningContainer;

  /// 아래쪽에 잠깐 뜨는 알림 (디자인의 검은 토스트).
  final Color toast;
  final Color onToast;

  final Color shadow;

  /// 병원 사진 자리에 칠하는 연한 색들 (디자인의 tone).
  final List<Color> tones;

  /// 병원 [id] 마다 늘 같은 [tones] 색.
  Color toneFor(String id) => tones[id.hashCode.abs() % tones.length];

  static const light = MediumColors(
    brand: Color(0xFF2D836D),
    onBrand: Colors.white,
    brandBright: Color(0xFF4BAE93),
    brandDeep: Color(0xFF2A735F),
    link: Color(0xFF2D836D),
    background: Colors.white,
    card: Color(0xFFF3FAF7),
    container: Color(0xFFE8F6F1),
    containerStrong: Color(0xFFD3EFE5),
    text: Color(0xFF191D21),
    textSecondary: Color(0xFF5C6663),
    textMuted: Color(0xFF646E6B),
    iconMuted: Color(0xFF8A938F),
    divider: Color(0xFFEEF2F0),
    border: Color(0xFFD5DEDB),
    fieldBorder: Color(0xFF8A938F),
    heart: Color(0xFFE25D6A),
    warning: Color(0xFFA8321F),
    warningContainer: Color(0xFFFDEDE9),
    toast: Color(0xFF191D21),
    onToast: Colors.white,
    shadow: Color(0x1F191D21),
    tones: [Color(0xFFCDEEE3), Color(0xFFD9EFE8), Color(0xFFC3E6DA), Color(0xFFD5F1E7), Color(0xFFC9EADF)],
  );

  static const dark = MediumColors(
    brand: Color(0xFF5ECBAE),
    onBrand: Color(0xFF0A1F19),
    brandBright: Color(0xFF4BAE93),
    brandDeep: Color(0xFF7AD9BD),
    link: Color(0xFF7AD9BD),
    background: Color(0xFF0F1513),
    card: Color(0xFF18221F),
    container: Color(0xFF1E3530),
    containerStrong: Color(0xFF26473E),
    text: Color(0xFFE6ECEA),
    textSecondary: Color(0xFFA9B4B0),
    textMuted: Color(0xFF95A09C),
    iconMuted: Color(0xFF7E8985),
    divider: Color(0xFF222B28),
    border: Color(0xFF3A4542),
    fieldBorder: Color(0xFF7E8985),
    heart: Color(0xFFFF7B86),
    warning: Color(0xFFFFB4A5),
    warningContainer: Color(0xFF3B1F1A),
    toast: Color(0xFFE6ECEA),
    onToast: Color(0xFF0F1513),
    shadow: Color(0x66000000),
    tones: [Color(0xFF1F3A33), Color(0xFF223D36), Color(0xFF1C352E), Color(0xFF244139), Color(0xFF1E3831)],
  );

  /// 설정의 고대비 모드와 휴대폰의 '대비 높이기'. 글씨는 검게, 초록은 더 진하게 한다.
  static const highContrastLight = MediumColors(
    brand: Color(0xFF1E5C4C),
    onBrand: Colors.white,
    brandBright: Color(0xFF2D836D),
    brandDeep: Color(0xFF174A3D),
    link: Color(0xFF1E5C4C),
    background: Colors.white,
    card: Color(0xFFF3FAF7),
    container: Color(0xFFE8F6F1),
    containerStrong: Color(0xFFD3EFE5),
    text: Colors.black,
    textSecondary: Color(0xFF2B3330),
    textMuted: Color(0xFF3D4643),
    iconMuted: Color(0xFF4A5551),
    divider: Color(0xFFB9C4C0),
    border: Color(0xFF4A5551),
    fieldBorder: Color(0xFF4A5551),
    heart: Color(0xFFB3263A),
    warning: Color(0xFF7E1F10),
    warningContainer: Color(0xFFFDEDE9),
    toast: Colors.black,
    onToast: Colors.white,
    shadow: Color(0x33000000),
    tones: [Color(0xFFCDEEE3), Color(0xFFD9EFE8), Color(0xFFC3E6DA), Color(0xFFD5F1E7), Color(0xFFC9EADF)],
  );

  static const highContrastDark = MediumColors(
    brand: Color(0xFF8BE6CB),
    onBrand: Colors.black,
    brandBright: Color(0xFF8BE6CB),
    brandDeep: Color(0xFF9FF0D8),
    link: Color(0xFF9FF0D8),
    background: Colors.black,
    card: Color(0xFF121A17),
    container: Color(0xFF163029),
    containerStrong: Color(0xFF1F4238),
    text: Colors.white,
    textSecondary: Color(0xFFD6DEDB),
    textMuted: Color(0xFFC2CCC8),
    iconMuted: Color(0xFFA9B4B0),
    divider: Color(0xFF4A5551),
    border: Color(0xFFA9B4B0),
    fieldBorder: Color(0xFFA9B4B0),
    heart: Color(0xFFFF9AA3),
    warning: Color(0xFFFFC9BD),
    warningContainer: Color(0xFF3B1F1A),
    toast: Colors.white,
    onToast: Colors.black,
    shadow: Color(0x99000000),
    tones: [Color(0xFF1F3A33), Color(0xFF223D36), Color(0xFF1C352E), Color(0xFF244139), Color(0xFF1E3831)],
  );

  /// 테마에 들어 있는 색. 테마를 앱 밖에서 만든 테스트 등에서는 밝은 색을 쓴다.
  static MediumColors of(BuildContext context) =>
      Theme.of(context).extension<MediumColors>() ?? light;

  @override
  MediumColors copyWith() => this;

  @override
  MediumColors lerp(MediumColors? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MediumColors(
      brand: c(brand, other.brand),
      onBrand: c(onBrand, other.onBrand),
      brandBright: c(brandBright, other.brandBright),
      brandDeep: c(brandDeep, other.brandDeep),
      link: c(link, other.link),
      background: c(background, other.background),
      card: c(card, other.card),
      container: c(container, other.container),
      containerStrong: c(containerStrong, other.containerStrong),
      text: c(text, other.text),
      textSecondary: c(textSecondary, other.textSecondary),
      textMuted: c(textMuted, other.textMuted),
      iconMuted: c(iconMuted, other.iconMuted),
      divider: c(divider, other.divider),
      border: c(border, other.border),
      fieldBorder: c(fieldBorder, other.fieldBorder),
      heart: c(heart, other.heart),
      warning: c(warning, other.warning),
      warningContainer: c(warningContainer, other.warningContainer),
      toast: c(toast, other.toast),
      onToast: c(onToast, other.onToast),
      shadow: c(shadow, other.shadow),
      tones: [for (var i = 0; i < tones.length; i++) c(tones[i], other.tones[i % other.tones.length])],
    );
  }
}
