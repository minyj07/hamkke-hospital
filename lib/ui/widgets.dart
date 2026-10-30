import 'package:flutter/material.dart';

import 'icons.dart';
import 'tokens.dart';

// 메디움 디자인(Medium Home.dc.html)의 공통 부품. 화면마다 같은 모양을 쓰도록 여기에 모은다.
// 크기는 디자인의 px 를 논리 픽셀로 그대로 옮겼고, 글자는 휴대폰 글자 크기에 따라 커진다.

/// 로고와 앱 이름 (디자인: 로고 40×34, '메디움' 21/800 짙은 초록).
class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const MediumLogo(height: 34),
        const SizedBox(width: 6),
        Text(
          appName,
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
            color: c.brandDeep,
          ),
        ),
      ],
    );
  }
}

/// 탭 화면의 큰 제목과 한 줄 설명 (디자인: 24/800, 설명 14 회색).
class PageHeading extends StatelessWidget {
  const PageHeading(this.title, {super.key, this.subtitle, this.trailing});

  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text(title, style: theme.textTheme.headlineSmall)),
              if (subtitle != null) ...[
                const SizedBox(height: 6),
                Text(subtitle!, style: theme.textTheme.bodyMedium?.copyWith(
                  fontSize: 14,
                  color: MediumColors.of(context).textSecondary,
                )),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 섹션 제목 (디자인: 17/800). [icon] 이 있으면 앞에 둔다 (예: '내 주변 병원'의 핀).
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.text, {super.key, this.icon, this.trailing});

  final String text;
  final DesignIcons? icon;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Row(
      children: [
        if (icon != null) ...[
          DesignIcon(icon!, size: 22, strokeWidth: 2.2, color: c.brandDeep),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text, style: Theme.of(context).textTheme.titleMedium),
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// 작은 꼬리표 (디자인: 둥근 6, 짙은 초록 글씨). [onCard] 면 흰 바탕, 아니면 연한 초록 바탕.
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.onCard = false, this.warning = false});

  final String label;

  /// 연한 초록 카드 위에 놓이는지 (디자인의 결과 카드는 흰 꼬리표).
  final bool onCard;

  /// 경고 꼬리표 (예: 없다고 확인된 편의시설).
  final bool warning;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final bg = warning ? c.warningContainer : (onCard ? c.background : c.container);
    final fg = warning ? c.warning : c.brandDeep;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: -0.2, color: fg),
      ),
    );
  }
}

/// 병원 사진 자리에 칠하는 연한 칸 (디자인의 tone).
class ToneBox extends StatelessWidget {
  const ToneBox({
    super.key,
    required this.id,
    this.width,
    this.height,
    this.radius = 10,
    this.alignment = Alignment.topRight,
    this.padding = EdgeInsets.zero,
    this.child,
  });

  /// 병원 id. 같은 병원은 늘 같은 색이다.
  final String id;
  final double? width;
  final double? height;
  final double radius;
  final AlignmentGeometry alignment;
  final EdgeInsetsGeometry padding;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        alignment: alignment,
        padding: padding,
        decoration: BoxDecoration(
          color: MediumColors.of(context).toneFor(id),
          borderRadius: BorderRadius.circular(radius),
        ),
        child: child,
      );
}

/// 즐겨찾기 하트. 넣었으면 빨간 하트, 아니면 빈 하트. 누르는 곳은 48×48 이다.
/// 화면낭독기는 '[name] 즐겨찾기에 넣기/빼기'로 읽는다.
class HeartButton extends StatelessWidget {
  const HeartButton({
    super.key,
    required this.name,
    required this.favorite,
    required this.onPressed,
    this.size = 22,
    this.circle = false,
  });

  final String name;
  final bool favorite;
  final VoidCallback? onPressed;
  final double size;

  /// 사진 자리 위에 흰 동그라미를 깔고 놓는다 (디자인: 26px 흰 원).
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final icon = DesignIcon(
      DesignIcons.heart,
      size: size,
      strokeWidth: 2,
      filled: favorite,
      color: favorite ? c.heart : c.iconMuted,
    );
    return IconButton(
      tooltip: favorite ? '$name 즐겨찾기에서 빼기' : '$name 즐겨찾기에 넣기',
      onPressed: onPressed,
      style: IconButton.styleFrom(minimumSize: const Size(48, 48), padding: EdgeInsets.zero),
      icon: circle
          ? Container(
              width: size + 10,
              height: size + 10,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.background.withValues(alpha: 0.9),
                shape: BoxShape.circle,
              ),
              child: icon,
            )
          : icon,
    );
  }
}

/// 병원 정보의 한 줄: 연한 초록 네모(36px) 속 아이콘과 글 (디자인의 병원 상세).
class InfoRow extends StatelessWidget {
  const InfoRow({super.key, required this.icon, required this.child});

  final DesignIcons icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.container, borderRadius: BorderRadius.circular(10)),
          child: DesignIcon(icon, size: 20, strokeWidth: 2.2, color: c.brandDeep),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 7),
            child: DefaultTextStyle.merge(style: const TextStyle(fontSize: 15), child: child),
          ),
        ),
      ],
    );
  }
}

/// 병원 목록 카드 (디자인: 연한 초록 #f3faf7, 둥근 18): 사진 자리·이름·설명·하트.
/// 누르면 [onTap]. 화면낭독기는 [semanticLabel] 이 있으면 그것을, 없으면 이름과 설명을 읽는다.
class HospitalTile extends StatelessWidget {
  const HospitalTile({
    super.key,
    required this.id,
    required this.name,
    required this.subtitle,
    this.onTap,
    this.trailing,
    this.showTone = false,
    this.semanticLabel,
    this.footer,
  });

  final String id;
  final String name;
  final String subtitle;
  final VoidCallback? onTap;

  /// 오른쪽 끝 (보통 [HeartButton]).
  final Widget? trailing;

  /// 왼쪽에 46px 사진 자리를 둘지 (디자인의 즐겨찾기 목록).
  final bool showTone;
  final String? semanticLabel;

  /// 아래쪽에 덧붙일 것 (예: 전화·길찾기 버튼).
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final theme = Theme.of(context);
    final info = Semantics(
      button: onTap != null,
      label: semanticLabel,
      // 라벨을 따로 줄 때는 속을 감추므로 누르기 동작도 여기에 둔다.
      onTap: semanticLabel != null ? onTap : null,
      excludeSemantics: semanticLabel != null,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 14, trailing == null ? 16 : 4, 14),
          child: Row(
            children: [
              if (showTone) ...[
                ToneBox(id: id, width: 46, height: 46, radius: 12),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: theme.textTheme.titleSmall),
                    const SizedBox(height: 3),
                    Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Material(
      color: c.card,
      borderRadius: BorderRadius.circular(18),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: info),
              if (trailing != null) Padding(padding: const EdgeInsets.only(right: 4), child: trailing),
            ],
          ),
          ?footer,
        ],
      ),
    );
  }
}

/// 고르는 방식.
enum OptionStyle {
  /// 여러 개 고르기: 둥근 네모(24px) 속 체크 (디자인의 병원 찾기).
  checkbox,

  /// 하나 고르기: 동그라미(24px) 속 체크 (디자인의 병원 찾기).
  single,

  /// 하나 고르기: 동그라미(22px) 속 점 (디자인의 진료 카드 만들기).
  radio,
}

/// 고를 수 있는 한 줄. 화면낭독기에는 [OptionStyle.checkbox] 는 체크 상자로,
/// 나머지는 라디오 버튼으로 알린다. 줄 전체를 누를 수 있다.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.hint,
    this.style = OptionStyle.checkbox,
    this.divider = true,
    this.leadingIndicator = false,
  });

  final String label;

  /// 이름 아래에 작게 보여 줄 설명 (예: '예전 1~3급').
  final String? hint;
  final bool selected;
  final VoidCallback? onTap;
  final OptionStyle style;

  /// 아래에 구분선을 그을지 (디자인의 병원 찾기).
  final bool divider;

  /// 표시를 글 앞에 둘지 (디자인의 진료 카드 라디오). 아니면 오른쪽 끝에 둔다.
  final bool leadingIndicator;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final theme = Theme.of(context);
    final indicator = _OptionIndicator(style: style, selected: selected);
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: style == OptionStyle.radio ? 15 : 16.5,
            fontWeight: selected && style != OptionStyle.radio ? FontWeight.w700 : FontWeight.w500,
            letterSpacing: -0.3,
            color: c.text,
          ),
        ),
        if (hint != null && hint!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(hint!, style: theme.textTheme.bodySmall),
        ],
      ],
    );
    return MergeSemantics(
      child: Semantics(
        checked: selected,
        inMutuallyExclusiveGroup: style != OptionStyle.checkbox,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: BoxConstraints(minHeight: style == OptionStyle.radio ? 50 : 58),
            padding: EdgeInsets.symmetric(horizontal: leadingIndicator ? 8 : 4, vertical: 8),
            decoration: divider
                ? BoxDecoration(border: Border(bottom: BorderSide(color: c.divider)))
                : null,
            child: Row(
              children: leadingIndicator
                  ? [indicator, const SizedBox(width: 14), Expanded(child: text)]
                  : [Expanded(child: text), const SizedBox(width: 12), indicator],
            ),
          ),
        ),
      ),
    );
  }
}

class _OptionIndicator extends StatelessWidget {
  const _OptionIndicator({required this.style, required this.selected});

  final OptionStyle style;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    if (style == OptionStyle.radio) {
      return Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: selected ? c.brand : c.fieldBorder, width: 2),
        ),
        child: selected
            ? Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
              )
            : null,
      );
    }
    return AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: 24,
      height: 24,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? c.brand : c.background,
        borderRadius: BorderRadius.circular(style == OptionStyle.checkbox ? 7 : 12),
        border: Border.all(color: selected ? c.brand : c.fieldBorder, width: 2),
      ),
      child: selected
          ? DesignIcon(DesignIcons.check, size: 14, strokeWidth: 3.4, color: c.onBrand)
          : null,
    );
  }
}

/// 병원 찾기의 진행 막대 (디자인: 높이 5, 연한 초록 바탕에 민트).
class StepProgressBar extends StatelessWidget {
  const StepProgressBar({super.key, required this.value});

  /// 0~1.
  final double value;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return ExcludeSemantics(
      child: Container(
        height: 5,
        color: c.container,
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration: const Duration(milliseconds: 300),
          widthFactor: value.clamp(0, 1),
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: c.brandBright,
              borderRadius: const BorderRadius.horizontal(right: Radius.circular(3)),
            ),
          ),
        ),
      ),
    );
  }
}

/// 화면 아래에 붙는 큰 버튼 자리 (디자인: 위쪽이 흐려지는 흰 바탕 위의 버튼).
class BottomActionArea extends StatelessWidget {
  const BottomActionArea({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bg = MediumColors.of(context).background;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [bg.withValues(alpha: 0), bg],
          stops: const [0, 0.3],
        ),
      ),
      child: SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(20, 12, 20, 14),
        child: child,
      ),
    );
  }
}

/// 연한 초록 섹션 상자 (디자인의 '내 주변 병원', '추천 이유').
class SectionBox extends StatelessWidget {
  const SectionBox({super.key, required this.child, this.padding = const EdgeInsets.all(18)});

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Container(
        padding: padding,
        decoration: BoxDecoration(
          color: MediumColors.of(context).container,
          borderRadius: BorderRadius.circular(20),
        ),
        child: child,
      );
}

/// 체크 동그라미가 붙은 한 줄 (디자인의 '추천 이유').
class CheckLine extends StatelessWidget {
  const CheckLine(this.text, {super.key, this.small = false});

  final String text;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final dot = small ? 18.0 : 22.0;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: dot,
          height: dot,
          margin: const EdgeInsets.only(top: 1),
          alignment: Alignment.center,
          decoration: BoxDecoration(color: c.brand, shape: BoxShape.circle),
          child: DesignIcon(DesignIcons.check, size: dot * 0.55, strokeWidth: 3.6, color: c.onBrand),
        ),
        SizedBox(width: small ? 8 : 10),
        Expanded(
          child: Text(text, style: TextStyle(fontSize: small ? 13.5 : 14.5, height: 1.5, color: c.text)),
        ),
      ],
    );
  }
}
