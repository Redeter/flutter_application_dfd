import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'calendar_screen.dart';
import 'goals_screen.dart';
import 'notes_screen.dart';
import 'state_categories_sheet.dart';
import 'statistics_screen.dart';

/// Корневой контейнер вкладок: экраны создаются один раз и остаются в памяти,
/// переключение без [Navigator.pushReplacement] и без повторной тяжёлой загрузки.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  final List<Widget?> _pages = List<Widget?>.filled(4, null);

  BottomNavTab get _tab => switch (_index) {
        0 => BottomNavTab.statistics,
        1 => BottomNavTab.notes,
        2 => BottomNavTab.calendar,
        _ => BottomNavTab.articles,
      };

  Widget _page(int i) {
    return _pages[i] ??= switch (i) {
      0 => const StatisticsScreen(embeddedInShell: true),
      1 => const NotesScreen(embeddedInShell: true),
      2 => const CalendarScreen(embeddedInShell: true),
      _ => GoalsScreen(
          embeddedInShell: true,
          onNavigateTab: _onTab,
        ),
    };
  }

  void _onTab(BottomNavTab tab) {
    final next = switch (tab) {
      BottomNavTab.statistics => 0,
      BottomNavTab.notes => 1,
      BottomNavTab.calendar => 2,
      BottomNavTab.articles => 3,
    };
    if (_index != next) setState(() => _index = next);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Stack(
        fit: StackFit.expand,
        children: List.generate(4, (i) {
          return Offstage(
            offstage: _index != i,
            child: TickerMode(
              enabled: _index == i,
              child: _page(i),
            ),
          );
        }),
      ),
      bottomNavigationBar: AppBottomNavBar(
        activeTab: _tab,
        onTabSelected: _onTab,
        onCenterTap: () => showStateCategoriesSheet(context),
      ),
    );
  }
}
