import 'package:flutter/material.dart';

import '../models/care_card.dart';
import '../models/disability.dart';
import '../ui/icons.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';
import 'care_card_edit_screen.dart';
import 'care_card_screen.dart';
import 'settings_screen.dart';

/// 마이페이지 탭 (메디움 디자인): 나의 진료 카드 요약과 설정.
class MyPageScreen extends StatelessWidget {
  const MyPageScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final saved = AppScope.of(context).careCard;
    void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListenableBuilder(
          listenable: saved,
          builder: (context, _) => ListView(
            padding: const EdgeInsets.fromLTRB(22, 34, 22, 24),
            children: [
              const PageHeading('마이페이지'),
              const SizedBox(height: 20),
              _CardSummary(
                card: saved.card,
                onShow: () => push(const ShowCardScreen()),
                onOpen: () => push(const CareCardScreen()),
                onCreate: () => push(const CareCardEditScreen()),
              ),
              const SizedBox(height: 20),
              _MenuRow(
                icon: Icons.chat_bubble_outline,
                label: '자주 쓰는 문장',
                onTap: () => push(const PhrasesScreen()),
              ),
              _MenuRow(
                icon: Icons.settings_outlined,
                label: '설정',
                detail: '글자 크기, 고대비, 앱 잠금, 내 정보 지우기',
                onTap: () => push(const SettingsScreen()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 진료 카드 요약 (디자인: 초록 카드 속 이름·꼬리표·흰 버튼).
class _CardSummary extends StatelessWidget {
  const _CardSummary({
    required this.card,
    required this.onShow,
    required this.onOpen,
    required this.onCreate,
  });

  final CareCard? card;
  final VoidCallback onShow;
  final VoidCallback onOpen;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    final card = this.card;
    final name = card?.name.trim() ?? '';
    final tags = card == null
        ? const <String>[]
        : [
            disabilityLabel(card.types, card.otherDisability),
            for (final h in HelpNeed.values)
              if (card.help.contains(h)) h.label,
          ].where((t) => t.isNotEmpty).take(6).toList();
    // 디자인: 초록 카드 위의 흰 버튼에 짙은 초록 글씨. 다크 모드도 흰 버튼으로 두어 카드 안에서 눈에 띄게 한다.
    final white = FilledButton.styleFrom(
      backgroundColor: Colors.white,
      foregroundColor: MediumColors.light.brandDeep,
      minimumSize: const Size.fromHeight(48),
      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
    );
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: c.brand, borderRadius: BorderRadius.circular(20)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('나의 진료 카드', style: TextStyle(fontSize: 13, color: c.onBrand)),
          ),
          const SizedBox(height: 6),
          Text(
            card == null
                ? '아직 만들지 않았어요'
                : (name.isEmpty ? '이름을 적지 않았어요' : '$name 님'),
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: c.onBrand),
          ),
          if (card == null) ...[
            const SizedBox(height: 6),
            Text(
              '병원 접수처나 진료실에서 내 장애와 필요한 도움을 큰 글씨로 보여 줘요.',
              style: TextStyle(fontSize: 13.5, height: 1.45, color: c.onBrand),
            ),
          ],
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final t in tags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(t, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: c.onBrand)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 18),
          if (card == null)
            FilledButton(style: white, onPressed: onCreate, child: const Text('진료 카드 만들기'))
          else ...[
            FilledButton.icon(
              style: white,
              icon: const Icon(Icons.visibility_outlined, size: 20),
              onPressed: onShow,
              label: const Text('병원에 보여 주기'),
            ),
            const SizedBox(height: 4),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: c.onBrand, minimumSize: const Size.fromHeight(48)),
              onPressed: onOpen,
              child: const Text('카드 보기·고치기'),
            ),
          ],
        ],
      ),
    );
  }
}

/// 마이페이지의 메뉴 한 줄.
class _MenuRow extends StatelessWidget {
  const _MenuRow({required this.icon, required this.label, required this.onTap, this.detail});

  final IconData icon;
  final String label;
  final String? detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Semantics(
      button: true,
      label: [label, ?detail].join(', '),
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: c.divider))),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: c.container, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: c.brandDeep),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: c.text)),
                    if (detail != null)
                      Text(detail!, style: TextStyle(fontSize: 13, color: c.textSecondary)),
                  ],
                ),
              ),
              DesignIcon(DesignIcons.back, size: 18, color: c.iconMuted).flipped(),
            ],
          ),
        ),
      ),
    );
  }
}

extension on Widget {
  /// 왼쪽 화살표를 오른쪽으로 돌린다.
  Widget flipped() => Transform.flip(flipX: true, child: this);
}
