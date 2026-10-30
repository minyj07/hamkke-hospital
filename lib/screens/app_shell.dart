import 'dart:async';

import 'package:flutter/material.dart';

import '../models/search_conditions.dart';
import '../ui/icons.dart';
import '../ui/tokens.dart';
import 'app_scope.dart';
import 'care_card_screen.dart';
import 'favorites_screen.dart';
import 'find_screen.dart';
import 'home_screen.dart';
import 'my_page_screen.dart';

/// 탭 화면. 하단 탭은 홈·즐겨찾기·마이페이지 3개이고(메디움 디자인), 병원 찾기는 홈의 바로가기로
/// 여는 화면이라 탭 막대에서는 '홈'이 켜져 있다. 탭을 바꿔도 각 화면에서 하던 것은 그대로 둔다.
enum AppTab { home, find, favorites, my }

/// 하단 탭 막대의 칸.
enum _Destination {
  home('홈', DesignIcons.home),
  favorites('즐겨찾기', DesignIcons.heart),
  my('마이페이지', DesignIcons.user);

  const _Destination(this.label, this.icon);
  final String label;
  final DesignIcons icon;
}

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  static AppShellState of(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>()!;

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.home;
  final _find = GlobalKey<FindScreenState>();

  late final AppServices _services = AppScope.of(context);

  @override
  void initState() {
    super.initState();
    // 즐겨찾기·최근 본 병원은 탭과 병원 정보 화면이 함께 쓰므로 탭이 생길 때 한 번 읽어 둔다.
    // 안 읽으면 다음에 켰을 때 목록을 바꾸기 전까지 비어 보인다.
    unawaited(_services.favorites.load());
    unawaited(_services.recent.load());
    // 홈 화면 바로가기로 켰으면 첫 화면을 그린 뒤에 그 화면으로 간다.
    _services.shortcut.addListener(_openShortcut);
    if (_services.shortcut.value != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openShortcut());
    }
  }

  @override
  void dispose() {
    _services.shortcut.removeListener(_openShortcut);
    super.dispose();
  }

  /// 홈 화면 바로가기가 가리키는 화면을 연다. 진료 카드는 만들어 두었으면 바로 '병원에 보여 주기'를 연다.
  void _openShortcut() {
    final shortcut = _services.shortcut.value;
    if (shortcut == null || !mounted) return;
    _services.shortcut.value = null;
    switch (shortcut) {
      case AppShortcut.find:
        showTab(AppTab.find);
      case AppShortcut.favorites:
        showTab(AppTab.favorites);
      case AppShortcut.card:
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) =>
              _services.careCard.card != null ? const ShowCardScreen() : const CareCardScreen(),
        ));
    }
  }

  AppTab get tab => _tab;

  void showTab(AppTab tab) => setState(() => _tab = tab);

  /// [conditions] 를 채운 병원 찾기의 [step] 단계를 연다 (결과 화면의 '진료 목적 바꾸기').
  void editSearch(SearchConditions conditions, FindStep step) {
    showTab(AppTab.find);
    _find.currentState?.edit(conditions, step);
  }

  /// 뒤로 가기: 병원 찾기는 이전 단계로, 다른 탭은 홈으로 간다.
  void _back() {
    if (_tab == AppTab.find && (_find.currentState?.back() ?? false)) return;
    showTab(AppTab.home);
  }

  _Destination get _destination => switch (_tab) {
        AppTab.home || AppTab.find => _Destination.home,
        AppTab.favorites => _Destination.favorites,
        AppTab.my => _Destination.my,
      };

  @override
  Widget build(BuildContext context) {
    final c = MediumColors.of(context);
    return PopScope(
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Scaffold(
        body: IndexedStack(
          index: _tab.index,
          children: [
            const HomeScreen(),
            FindScreen(key: _find),
            const FavoritesScreen(),
            const MyPageScreen(),
          ],
        ),
        // 디자인: 흰 탭 막대 위에 옅은 선과 그림자.
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            color: c.background,
            border: Border(top: BorderSide(color: c.divider)),
            boxShadow: [BoxShadow(color: c.shadow.withValues(alpha: 0.05), blurRadius: 12, offset: const Offset(0, -2))],
          ),
          child: NavigationBar(
            selectedIndex: _destination.index,
            onDestinationSelected: (i) => showTab(switch (_Destination.values[i]) {
              _Destination.home => AppTab.home,
              _Destination.favorites => AppTab.favorites,
              _Destination.my => AppTab.my,
            }),
            destinations: [
              for (final d in _Destination.values)
                NavigationDestination(icon: DesignIcon(d.icon, size: 22), label: d.label),
            ],
          ),
        ),
      ),
    );
  }
}
