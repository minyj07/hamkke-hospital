import 'package:flutter/material.dart';

import '../ui/icons.dart';
import '../ui/tokens.dart';

/// 처음 켰을 때 한 번 보여 주는 안내 (3장, 건너뛸 수 있음). 저절로 넘어가지 않는다.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onDone});

  final VoidCallback onDone;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    (
      null, // 메디움 로고
      '나에게 맞는 병원을 찾아요',
      '장애 유형과 필요한 진료를 고르거나 말로 설명하면, 정부 지정 기관과 가까운 병원을 추천 이유와 함께 보여 줘요.',
    ),
    (
      DesignIcons.card,
      '병원에서는 진료 카드를 보여 주세요',
      '내 장애와 소통 방법, 필요한 도움을 큰 글씨로 의료진에게 보여 줄 수 있어요.',
    ),
    (
      DesignIcons.user,
      '내 정보는 이 휴대폰에만 둬요',
      '장애 정보와 진료 카드는 앱 밖으로 보내지 않아요. 위치는 ‘현재 위치로 찾기’나 ‘현재 위치로 보기’를 누를 때만 써요.',
    ),
  ];

  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _next() => _controller.nextPage(
      duration: const Duration(milliseconds: 300), curve: Curves.easeOut);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = MediumColors.of(context);
    final last = _page == _pages.length - 1;
    // 1장은 메디움 로고, 나머지는 디자인 아이콘을 연한 초록 칸에 담는다.
    Widget picture(DesignIcons? icon) => icon == null
        ? const MediumLogo(height: 96)
        : Container(
            width: 112,
            height: 112,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: c.container, borderRadius: BorderRadius.circular(32)),
            child: DesignIcon(icon, size: 60, strokeWidth: 1.8, color: c.brandDeep),
          );
    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
                onPressed: widget.onDone,
                child: const Text('건너뛰기'),
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: [
                  for (final (icon, title, body) in _pages)
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        children: [
                          picture(icon),
                          const SizedBox(height: 28),
                          Semantics(
                            header: true,
                            child: Text(title,
                                style: theme.textTheme.headlineSmall,
                                textAlign: TextAlign.center),
                          ),
                          const SizedBox(height: 16),
                          Text(body,
                              style: theme.textTheme.bodyLarge?.copyWith(color: c.textSecondary),
                              textAlign: TextAlign.center),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            Text('${_page + 1} / ${_pages.length}',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: c.brandDeep)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                onPressed: last ? widget.onDone : _next,
                child: Text(last ? '시작하기' : '다음'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
