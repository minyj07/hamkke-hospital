import 'dart:async';

import 'package:flutter/material.dart';

import '../models/search_conditions.dart';
import 'app_scope.dart';
import 'app_shell.dart';
import 'results_launcher.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

/// 첫 화면. 병원 찾기·진료 카드·즐겨찾기로 가는 큰 버튼과, 지난번 조건으로 다시 찾기.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with ResultsLauncher {
  Future<void> _clearLast(SearchConditions cleared) async {
    final lastSearch = AppScope.of(context).lastSearch;
    final messenger = ScaffoldMessenger.of(context);
    await lastSearch.clear();
    messenger.showSnackBar(SnackBar(
      content: const Text('지난번 조건을 지웠어요.'),
      action: SnackBarAction(
        label: '되돌리기',
        onPressed: () {
          // 그사이 새로 찾았으면 그 조건을 둔다.
          if (lastSearch.value == null) unawaited(lastSearch.save(cleared));
        },
      ),
    ));
  }

  void _push(Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

  @override
  Widget build(BuildContext context) {
    final services = AppScope.of(context);
    final shell = AppShell.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('함께병원'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: '설정',
            onPressed: () => _push(const SettingsScreen()),
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: services.lastSearch,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Semantics(
              header: true,
              child: Text('무엇을 도와드릴까요?',
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            const SizedBox(height: 16),
            _BigButton(
              icon: Icons.local_hospital_outlined,
              title: '병원 찾기',
              subtitle: '장애와 필요한 진료에 맞는 병원을 찾아요',
              onPressed: () => shell.showTab(AppTab.find),
            ),
            _BigButton(
              icon: Icons.badge_outlined,
              title: '나의 진료 카드',
              subtitle: '병원에서 내 장애와 필요한 도움을 보여 줘요',
              onPressed: () => shell.showTab(AppTab.card),
            ),
            _BigButton(
              icon: Icons.star_outline,
              title: '즐겨찾기',
              subtitle: '자주 가는 병원과 최근 본 병원',
              onPressed: () => shell.showTab(AppTab.favorites),
            ),
            if (services.lastSearch.value case final last?)
              _LastSearchCard(
                conditions: last,
                locating: locating,
                onSearch: () => showResults(last),
                onClear: () => _clearLast(last),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: const Icon(Icons.search),
              label: const Text('병원 이름으로 찾기'),
              onPressed: () => _push(const SearchScreen()),
            ),
          ],
        ),
      ),
    );
  }
}

class _BigButton extends StatelessWidget {
  const _BigButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: FilledButton.tonal(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(88),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          alignment: Alignment.centerLeft,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        onPressed: onPressed,
        child: Row(
          children: [
            Icon(icon, size: 36),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleLarge),
                  Text(subtitle, style: theme.textTheme.bodyMedium),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 지난번 조건. 바로 다시 찾거나 지울 수 있다.
class _LastSearchCard extends StatelessWidget {
  const _LastSearchCard({
    required this.conditions,
    required this.locating,
    required this.onSearch,
    required this.onClear,
  });

  final SearchConditions conditions;
  final bool locating;
  final VoidCallback onSearch;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card.outlined(
      margin: const EdgeInsets.only(top: 8, bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              header: true,
              child: Text('지난번 조건', style: theme.textTheme.titleMedium),
            ),
            const SizedBox(height: 4),
            Text(conditions.summary),
            Text('이 휴대폰에 저장하고, 앱 밖으로 보내지 않아요.', style: theme.textTheme.bodySmall),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
              icon: locating
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.search),
              label: Text(locating ? '현재 위치를 확인하고 있어요' : '지난번 조건으로 다시 찾기'),
              onPressed: locating ? null : onSearch,
            ),
            TextButton(
              style: TextButton.styleFrom(minimumSize: const Size.fromHeight(48)),
              onPressed: locating ? null : onClear,
              child: const Text('조건 지우기'),
            ),
          ],
        ),
      ),
    );
  }
}
