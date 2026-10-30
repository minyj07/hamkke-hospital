import 'package:flutter/material.dart';

import 'icons.dart';
import 'tokens.dart';

/// 메디움 테마. 글꼴은 Pretendard, 크기·굵기·자간은 디자인(Medium Home.dc.html)을 따른다.
///
/// 글자 크기 대응: 모든 크기는 휴대폰·앱의 글자 크기 설정에 따라 커진다(고정 높이를 두지 않는다).
ThemeData mediumTheme(Brightness brightness, {bool highContrast = false}) {
  final c = switch ((brightness, highContrast)) {
    (Brightness.light, false) => MediumColors.light,
    (Brightness.dark, false) => MediumColors.dark,
    (Brightness.light, true) => MediumColors.highContrastLight,
    (Brightness.dark, true) => MediumColors.highContrastDark,
  };

  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.brand,
    onPrimary: c.onBrand,
    primaryContainer: c.container,
    onPrimaryContainer: c.brandDeep,
    secondary: c.brandDeep,
    onSecondary: c.background,
    secondaryContainer: c.container,
    onSecondaryContainer: c.brandDeep,
    tertiary: c.heart,
    onTertiary: c.background,
    error: c.warning,
    onError: c.background,
    errorContainer: c.warningContainer,
    onErrorContainer: c.warning,
    surface: c.background,
    onSurface: c.text,
    onSurfaceVariant: c.textSecondary,
    surfaceContainerLowest: c.background,
    surfaceContainerLow: c.card,
    surfaceContainer: c.card,
    surfaceContainerHigh: c.container,
    surfaceContainerHighest: c.containerStrong,
    outline: c.fieldBorder,
    outlineVariant: c.border,
    inverseSurface: c.toast,
    onInverseSurface: c.onToast,
    inversePrimary: c.brandBright,
    shadow: Colors.black,
    scrim: Colors.black,
    surfaceTint: Colors.transparent,
  );

  // 디자인의 글자: 큰 제목 27/800, 화면 제목 24/800, 앱 바 19/800, 섹션 17/800, 본문 15.
  TextStyle t(double size, FontWeight weight, {double spacing = 0, double? height, Color? color}) =>
      TextStyle(
        fontFamily: 'Pretendard',
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
        height: height,
        color: color ?? c.text,
      );
  final text = TextTheme(
    displaySmall: t(30, FontWeight.w800, spacing: -0.9, height: 1.3),
    headlineMedium: t(27, FontWeight.w800, spacing: -0.8, height: 1.3),
    headlineSmall: t(24, FontWeight.w800, spacing: -0.7, height: 1.35),
    titleLarge: t(19, FontWeight.w800, spacing: -0.5, height: 1.3),
    titleMedium: t(17, FontWeight.w800, spacing: -0.5, height: 1.35),
    titleSmall: t(15, FontWeight.w700, spacing: -0.3, height: 1.35),
    bodyLarge: t(16, FontWeight.w500, spacing: -0.3, height: 1.45),
    bodyMedium: t(15, FontWeight.w400, spacing: -0.2, height: 1.5),
    bodySmall: t(13, FontWeight.w400, spacing: -0.1, height: 1.45, color: c.textSecondary),
    labelLarge: t(15, FontWeight.w700, spacing: -0.2),
    labelMedium: t(12.5, FontWeight.w600, spacing: -0.4),
    labelSmall: t(12, FontWeight.w600, spacing: -0.2),
  );

  final stadium = const StadiumBorder();
  WidgetStateProperty<T> all<T>(T v) => WidgetStatePropertyAll<T>(v);
  final disabledBg = brightness == Brightness.light ? const Color(0xFFE6EBE9) : const Color(0xFF26302D);

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    fontFamily: 'Pretendard',
    textTheme: text,
    extensions: [c],
    scaffoldBackgroundColor: c.background,
    canvasColor: c.background,
    dividerColor: c.divider,
    // 기본 밀도. comfortable 은 이름과 달리 더 촘촘해서(-4dp) 버튼·칩의 터치 영역이 44dp 로 줄어든다.
    visualDensity: VisualDensity.standard,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    splashFactory: InkSparkle.splashFactory,
    iconTheme: IconThemeData(color: c.text, size: 24),
    appBarTheme: AppBarTheme(
      backgroundColor: c.background,
      foregroundColor: c.text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      toolbarHeight: 64,
      titleSpacing: 4,
      titleTextStyle: text.titleLarge,
      iconTheme: IconThemeData(color: c.text, size: 22),
      actionsIconTheme: IconThemeData(color: c.text, size: 22),
    ),
    // 앱 바의 뒤로 가기는 디자인의 화살표. 툴팁('뒤로')은 머티리얼 한국어 그대로다.
    actionIconTheme: ActionIconThemeData(
      backButtonIconBuilder: (context) => const DesignIcon(DesignIcons.back, size: 22, strokeWidth: 2.2),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? disabledBg : null),
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textMuted : null),
        minimumSize: all(const Size(64, 56)),
        padding: all(const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
        shape: all(stadium),
        textStyle: all(t(16, FontWeight.w700, spacing: -0.2)),
        iconSize: all(20),
        elevation: all(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textMuted : c.brandDeep),
        backgroundColor: all(c.background),
        side: all(BorderSide(color: c.border, width: 1.5)),
        minimumSize: all(const Size(64, 52)),
        padding: all(const EdgeInsets.symmetric(horizontal: 18, vertical: 12)),
        shape: all(stadium),
        textStyle: all(t(15, FontWeight.w700, spacing: -0.2)),
        iconSize: all(18),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled) ? c.textMuted : c.brandDeep),
        minimumSize: all(const Size(48, 48)),
        padding: all(const EdgeInsets.symmetric(horizontal: 12)),
        textStyle: all(t(15, FontWeight.w700, spacing: -0.2)),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: ButtonStyle(minimumSize: all(const Size(48, 48))),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: c.background,
      selectedColor: c.container,
      disabledColor: c.background,
      checkmarkColor: c.brandDeep,
      labelStyle: t(14, FontWeight.w600, spacing: -0.2),
      secondaryLabelStyle: t(14, FontWeight.w600, spacing: -0.2, color: c.brandDeep),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      side: WidgetStateBorderSide.resolveWith((s) => BorderSide(
            color: s.contains(WidgetState.selected) ? c.brand : c.border,
            width: 1.5,
          )),
      showCheckmark: true,
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : Colors.transparent),
      checkColor: all(c.onBrand),
      side: WidgetStateBorderSide.resolveWith((s) => BorderSide(
            color: s.contains(WidgetState.selected) ? c.brand : c.fieldBorder,
            width: 2,
          )),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.fieldBorder),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.onBrand : c.fieldBorder),
      trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.background),
      trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.brand : c.fieldBorder),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: c.brand,
      thumbColor: c.brand,
      inactiveTrackColor: c.container,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.brandBright,
      linearTrackColor: c.container,
      linearMinHeight: 5,
      circularTrackColor: c.container,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: c.background,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      labelStyle: t(15, FontWeight.w500, color: c.textMuted),
      floatingLabelStyle: t(14, FontWeight.w600, color: c.brandDeep),
      hintStyle: t(15, FontWeight.w500, color: c.textMuted),
      counterStyle: t(12, FontWeight.w400, color: c.textMuted),
      helperStyle: t(13, FontWeight.w400, color: c.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.fieldBorder, width: 1.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.fieldBorder, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: c.brand, width: 2),
      ),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.brand,
      selectionColor: c.containerStrong,
      selectionHandleColor: c.brand,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: c.brandDeep,
      titleTextStyle: t(16, FontWeight.w500, spacing: -0.3),
      subtitleTextStyle: t(13, FontWeight.w400, color: c.textSecondary),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      minVerticalPadding: 12,
    ),
    cardTheme: CardThemeData(
      color: c.card,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    dividerTheme: DividerThemeData(color: c.divider, thickness: 1, space: 1),
    dialogTheme: DialogThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      titleTextStyle: text.titleLarge,
      contentTextStyle: text.bodyMedium,
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: c.toast,
      contentTextStyle: t(14, FontWeight.w600, color: c.onToast),
      actionTextColor: c.brandBright,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
      elevation: 4,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: c.toast, borderRadius: BorderRadius.circular(8)),
      textStyle: t(13, FontWeight.w600, color: c.onToast),
    ),
    // 하단 탭: 고른 탭은 연한 초록 알약(64×32)에 짙은 초록 글씨, 나머지는 흐린 글씨.
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: c.background,
      surfaceTintColor: Colors.transparent,
      shadowColor: Colors.transparent,
      elevation: 0,
      height: 72,
      indicatorColor: c.container,
      indicatorShape: stadium,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      labelTextStyle: WidgetStateProperty.resolveWith((s) => s.contains(WidgetState.selected)
          ? t(12, FontWeight.w800, color: c.brandDeep)
          : t(12, FontWeight.w600, color: c.textMuted)),
      iconTheme: WidgetStateProperty.resolveWith((s) => IconThemeData(
            size: 22,
            color: s.contains(WidgetState.selected) ? c.brandDeep : c.textMuted,
          )),
    ),
  );
}
