import 'package:flutter/material.dart';

import '../models/search_conditions.dart';
import 'care_card_screen.dart';
import 'favorites_screen.dart';
import 'find_screen.dart';
import 'home_screen.dart';

/// 하단 탭. 설정은 홈 오른쪽 위에 있다.
enum AppTab {
  home('홈', Icons.home_outlined, Icons.home),
  find('병원 찾기', Icons.local_hospital_outlined, Icons.local_hospital),
  card('진료 카드', Icons.badge_outlined, Icons.badge),
  favorites('즐겨찾기', Icons.star_outline, Icons.star);

  const AppTab(this.label, this.icon, this.selectedIcon);
  final String label;
  final IconData icon;
  final IconData selectedIcon;
}

/// 홈·병원 찾기·진료 카드·즐겨찾기 탭. 탭을 바꿔도 각 탭에서 하던 것은 그대로 둔다.
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

  @override
  Widget build(BuildContext context) {
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
            const CareCardScreen(),
            const FavoritesScreen(),
          ],
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _tab.index,
          onDestinationSelected: (i) => showTab(AppTab.values[i]),
          destinations: [
            for (final t in AppTab.values)
              NavigationDestination(
                icon: Icon(t.icon),
                selectedIcon: Icon(t.selectedIcon),
                label: t.label,
              ),
          ],
        ),
      ),
    );
  }
}
