import 'package:flutter/material.dart';

import '../models/care_card.dart';
import 'app_scope.dart';
import 'care_card_edit_screen.dart';
import 'hospital_actions.dart';

/// 나의 진료 카드 탭. 카드가 없으면 무엇인지 알려 주고, 있으면 보여 주기·자주 쓰는 문장·고치기를 둔다.
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

final _tall = ButtonStyle(minimumSize: WidgetStateProperty.all(const Size.fromHeight(56)));

class _NoCard extends StatelessWidget {
  const _NoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Icon(Icons.badge_outlined, size: 72, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text('병원 접수처나 진료실에서 의료진에게 보여 주는 카드예요.', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text('내 장애, 소통 방법, 필요한 도움, 주의할 점을 큰 글씨로 보여 줄 수 있어요. '
            '모든 칸은 비워 둬도 돼요.'),
        const SizedBox(height: 8),
        Text('카드 내용은 이 휴대폰의 보안 저장소에만 암호화해서 두고, 앱 밖으로 보내지 않아요.',
            style: theme.textTheme.bodySmall),
        const SizedBox(height: 24),
        FilledButton.icon(
          style: _tall,
          icon: const Icon(Icons.add),
          label: const Text('진료 카드 만들기'),
          onPressed: () => _push(context, const CareCardEditScreen()),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: _tall,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('자주 쓰는 문장'),
          onPressed: () => _push(context, const PhrasesScreen()),
        ),
      ],
    );
  }
}

class _CardHome extends StatelessWidget {
  const _CardHome({required this.card});

  final CareCard card;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final guardian = card.guardianName.trim().isEmpty ? '' : ' (${card.guardianName.trim()})';
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        FilledButton.icon(
          style: ButtonStyle(
            minimumSize: WidgetStateProperty.all(const Size.fromHeight(72)),
            textStyle: WidgetStateProperty.all(theme.textTheme.titleLarge),
          ),
          icon: const Icon(Icons.visibility_outlined, size: 28),
          label: const Text('병원에 보여 주기'),
          onPressed: () => _push(context, const ShowCardScreen()),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: _tall,
          icon: const Icon(Icons.chat_bubble_outline),
          label: const Text('자주 쓰는 문장'),
          onPressed: () => _push(context, const PhrasesScreen()),
        ),
        if (card.guardianPhone.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          OutlinedButton.icon(
            style: _tall,
            icon: const Icon(Icons.call),
            label: Text('보호자에게 전화$guardian'),
            onPressed: () => callPhone(context, card.guardianPhone.trim()),
          ),
        ],
        const SizedBox(height: 24),
        Semantics(header: true, child: Text('카드 내용', style: theme.textTheme.titleMedium)),
        const SizedBox(height: 8),
        Card.outlined(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final s in card.sentences)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text(s, style: theme.textTheme.bodyLarge),
                  ),
                for (final (title, text) in card.notes) ...[
                  const SizedBox(height: 8),
                  Text(title, style: theme.textTheme.labelLarge),
                  Text(text, style: theme.textTheme.bodyLarge),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: _tall,
          icon: const Icon(Icons.edit_outlined),
          label: const Text('카드 고치기'),
          onPressed: () => _push(context, const CareCardEditScreen()),
        ),
        const SizedBox(height: 8),
        Text('카드 내용은 이 휴대폰의 보안 저장소에만 암호화해서 둬요.', style: theme.textTheme.bodySmall),
      ],
    );
  }
}

/// 흰 바탕에 검은 글씨. 진료 카드를 보여 주는 화면은 앱 설정과 상관없이 대비를 가장 크게 한다.
ThemeData _paperTheme(BuildContext context) {
  final base = Theme.of(context);
  return base.copyWith(
    scaffoldBackgroundColor: Colors.white,
    colorScheme: base.colorScheme.copyWith(
      surface: Colors.white,
      onSurface: Colors.black,
      primary: Colors.black,
      onPrimary: Colors.white,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.white, foregroundColor: Colors.black),
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
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('자주 쓰는 문장')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('누르면 화면 가득 크게 보여 줘요.'),
          ),
          for (final phrase in commonPhrases)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(64),
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                ),
                onPressed: () => _push(context, PhraseScreen(phrase: phrase)),
                child: Text(phrase, style: theme.textTheme.titleLarge),
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
