import 'package:flutter/material.dart';

import '../models/care_card.dart';
import '../ui/icons.dart';
import '../ui/tokens.dart';
import '../ui/widgets.dart';
import 'app_scope.dart';
import 'care_card_edit_screen.dart';
import 'hospital_actions.dart';

/// 나의 진료 카드. 홈의 '나의 진료 카드'와 마이페이지에서 연다.
/// 카드가 없으면 무엇인지 알려 주고, 있으면 보여 주기·자주 쓰는 문장·보호자 전화·카드 내용·고치기를 둔다.
class CareCardScreen extends StatelessWidget {
  const CareCardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final saved = AppScope.of(context).careCard;
    return Scaffold(
      appBar: AppBar(title: const Text('나의 진료 카드')),
      body: ListenableBuilder(
        listenable: saved,
        builder: (context, _) => switch (saved.card) {
          null => const _NoCard(),
          final card => _CardHome(card: card),
        },
      ),
    );
  }
}

void _push(BuildContext context, Widget screen) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

/// 카드를 아직 만들지 않았을 때.
class _NoCard extends StatelessWidget {
  const _NoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = MediumColors.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
      children: [
        // 디자인의 카드 아이콘을 연한 초록 칸에 크게 둔다.
        Align(
          alignment: Alignment.centerLeft,
          child: Container(
            width: 88,
            height: 88,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.container, borderRadius: BorderRadius.circular(24)),
            child: DesignIcon(DesignIcons.card, size: 48, strokeWidth: 1.8, color: c.brandDeep),
          ),
        ),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text('병원 접수처나 진료실에서 의료진에게 보여 주는 카드예요.', style: theme.textTheme.titleMedium),
        ),
        const SizedBox(height: 8),
        Text(
          '내 장애, 소통 방법, 필요한 도움, 주의할 점을 큰 글씨로 보여 줄 수 있어요. '
          '모든 칸은 비워 둬도 돼요.',
          style: theme.textTheme.bodyMedium?.copyWith(color: c.textSecondary),
        ),
        const SizedBox(height: 8),
        Text('카드 내용은 이 휴대폰의 보안 저장소에만 암호화해서 두고, 앱 밖으로 보내지 않아요.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 28),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.add),
          label: const Text('진료 카드 만들기'),
          onPressed: () => _push(context, const CareCardEditScreen()),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
          label: const Text('자주 쓰는 문장'),
          onPressed: () => _push(context, const PhrasesScreen()),
        ),
      ],
    );
  }
}

/// 카드를 만들어 둔 때.
class _CardHome extends StatelessWidget {
  const _CardHome({required this.card});

  final CareCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = MediumColors.of(context);
    final guardian = card.guardianName.trim().isEmpty ? '' : ' (${card.guardianName.trim()})';
    const tall = Size.fromHeight(52);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        FilledButton.icon(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(72),
            textStyle: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.5),
          ),
          icon: const Icon(Icons.visibility_outlined, size: 28),
          label: const Text('병원에 보여 주기'),
          onPressed: () => _push(context, const ShowCardScreen()),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: tall),
          icon: const Icon(Icons.chat_bubble_outline, size: 20),
          label: const Text('자주 쓰는 문장'),
          onPressed: () => _push(context, const PhrasesScreen()),
        ),
        if (card.guardianPhone.trim().isNotEmpty) ...[
          const SizedBox(height: 10),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(minimumSize: tall),
            icon: const DesignIcon(DesignIcons.phone, size: 18, strokeWidth: 2.3),
            label: Text('보호자에게 전화$guardian'),
            onPressed: () => callPhone(context, card.guardianPhone.trim()),
          ),
        ],
        const SizedBox(height: 28),
        const SectionTitle('카드 내용'),
        const SizedBox(height: 12),
        // 디자인의 연한 초록 상자에 카드 문장을 담는다.
        SectionBox(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final s in card.sentences)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(s, style: theme.textTheme.bodyLarge),
                ),
              for (final (title, text) in card.notes) ...[
                const SizedBox(height: 10),
                Text(title, style: theme.textTheme.titleSmall?.copyWith(color: c.brandDeep)),
                const SizedBox(height: 2),
                Text(text, style: theme.textTheme.bodyLarge),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(minimumSize: tall),
          icon: const Icon(Icons.edit_outlined, size: 20),
          label: const Text('카드 고치기'),
          onPressed: () => _push(context, const CareCardEditScreen()),
        ),
        const SizedBox(height: 10),
        Text('카드 내용은 이 휴대폰의 보안 저장소에만 암호화해서 둬요.', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// 흰 바탕에 검은 글씨. 진료 카드를 보여 주는 화면은 앱 설정·다크 모드와 상관없이 대비를 가장 크게 한다.
ThemeData _paperTheme(BuildContext context) {
  final base = Theme.of(context);
  const black = Colors.black;
  return base.copyWith(
    brightness: Brightness.light,
    scaffoldBackgroundColor: Colors.white,
    colorScheme: base.colorScheme.copyWith(
      brightness: Brightness.light,
      surface: Colors.white,
      onSurface: black,
      onSurfaceVariant: black,
      primary: black,
      onPrimary: Colors.white,
    ),
    textTheme: base.textTheme.apply(bodyColor: black, displayColor: black),
    iconTheme: const IconThemeData(color: black, size: 24),
    appBarTheme: base.appBarTheme.copyWith(
      backgroundColor: Colors.white,
      foregroundColor: black,
      titleTextStyle: base.appBarTheme.titleTextStyle?.copyWith(color: black),
      iconTheme: const IconThemeData(color: black, size: 22),
      actionsIconTheme: const IconThemeData(color: black, size: 22),
    ),
  );
}

/// 보는 동안 화면이 꺼지지 않게 한다.
mixin _KeepScreenOn<T extends StatefulWidget> on State<T> {
  late final AppServices _services = AppScope.of(context);

  @override
  void initState() {
    super.initState();
    _services.keepScreenOn(true);
  }

  @override
  void dispose() {
    _services.keepScreenOn(false);
    super.dispose();
  }
}

/// '병원에 보여 주기'. 의료진이 읽기 좋은 문장을 큰 글씨로 보여 준다. 휴대폰을 가로로 돌려도 된다.
class ShowCardScreen extends StatefulWidget {
  const ShowCardScreen({super.key});

  @override
  State<ShowCardScreen> createState() => _ShowCardScreenState();
}

class _ShowCardScreenState extends State<ShowCardScreen> with _KeepScreenOn {
  @override
  Widget build(BuildContext context) {
    const sentence = TextStyle(fontSize: 30, height: 1.4, fontWeight: FontWeight.w600, color: Colors.black);
    const title = TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.black);
    const body = TextStyle(fontSize: 28, height: 1.4, color: Colors.black);
    return Theme(
      data: _paperTheme(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('병원에 보여 주기')),
        body: SafeArea(
          child: ListenableBuilder(
            listenable: _services.careCard,
            builder: (context, _) {
              final card = _services.careCard.card ?? const CareCard();
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  for (final s in card.sentences)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(s, style: sentence),
                    ),
                  if (card.notes.isNotEmpty) const Divider(thickness: 2, color: Colors.black),
                  for (final (heading, text) in card.notes)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: MergeSemantics(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(heading, style: title),
                            Text(text, style: body),
                          ],
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 자주 쓰는 문장. 누르면 화면 가득 크게 보여 준다.
class PhrasesScreen extends StatelessWidget {
  const PhrasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('자주 쓰는 문장')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Text('누르면 화면 가득 크게 보여 줘요.', style: TextStyle(fontSize: 14, color: c.textSecondary)),
          ),
          for (final phrase in commonPhrases)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  backgroundColor: c.container,
                  foregroundColor: c.text,
                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: -0.4),
                ),
                onPressed: () => _push(context, PhraseScreen(phrase: phrase)),
                child: Text(phrase),
              ),
            ),
        ],
      ),
    );
  }
}

/// 문장 하나를 화면 가득 보여 준다.
class PhraseScreen extends StatefulWidget {
  const PhraseScreen({super.key, required this.phrase});

  final String phrase;

  @override
  State<PhraseScreen> createState() => _PhraseScreenState();
}

class _PhraseScreenState extends State<PhraseScreen> with _KeepScreenOn {
  @override
  Widget build(BuildContext context) {
    return Theme(
      data: _paperTheme(context),
      child: Scaffold(
        appBar: AppBar(title: const Text('크게 보기')),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) => SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                child: Center(
                  child: Text(
                    widget.phrase,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 64,
                      height: 1.3,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
