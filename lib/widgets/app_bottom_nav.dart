import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// Вкладки нижней панели (без центральной «+»).
enum BottomNavTab { statistics, notes, calendar, articles }

class AppBottomNavBar extends StatelessWidget {
  const AppBottomNavBar({
    super.key,
    required this.activeTab,
    required this.onTabSelected,
    this.onCenterTap,
  });

  /// `null` — ни одна вкладка не выделена (главный экран).
  final BottomNavTab? activeTab;
  final ValueChanged<BottomNavTab> onTabSelected;
  final VoidCallback? onCenterTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 96,
      color: AppColors.orange,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _BottomNavItem(
                label: 'СТАТИСТИКА',
                isActive: activeTab == BottomNavTab.statistics,
                iconBuilder: (a) => StatisticsNavIcon(active: a),
                onTap: () => onTabSelected(BottomNavTab.statistics),
              ),
              _BottomNavItem(
                label: 'ЗАМЕТКИ',
                isActive: activeTab == BottomNavTab.notes,
                iconBuilder: (a) => NotesNavIcon(active: a),
                onTap: () => onTabSelected(BottomNavTab.notes),
              ),
              const SizedBox(width: 72),
              _BottomNavItem(
                label: 'КАЛЕНДАРЬ',
                isActive: activeTab == BottomNavTab.calendar,
                iconBuilder: (a) => CalendarNavIcon(active: a),
                onTap: () => onTabSelected(BottomNavTab.calendar),
              ),
              _BottomNavItem(
                label: 'СТАТЬИ',
                isActive: activeTab == BottomNavTab.articles,
                iconBuilder: (a) => ArticlesNavIcon(active: a),
                onTap: () => onTabSelected(BottomNavTab.articles),
              ),
            ],
          ),
          Positioned(
            child: GestureDetector(
              onTap: onCenterTap,
              child: Container(
                width: 72,
                height: 72,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(6, -8),
                    child: SvgPicture.asset(
                      'assets/icons/plus.svg',
                      width: 48,
                      height: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNavItem extends StatelessWidget {
  const _BottomNavItem({
    required this.label,
    required this.isActive,
    required this.iconBuilder,
    required this.onTap,
  });

  final String label;
  final bool isActive;
  final Widget Function(bool active) iconBuilder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          iconBuilder(isActive),
          if (!isActive) ...[
            const SizedBox(height: 4),
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: AppColors.white,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class StatisticsNavIcon extends StatelessWidget {
  const StatisticsNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 74.0 : 43.0;
    return Transform.translate(
      offset: const Offset(0, -2),
      child: SvgPicture.asset(
        active
            ? 'assets/icons/highlighted diagram.svg'
            : 'assets/icons/Diagram.svg',
        width: size,
        height: size,
      ),
    );
  }
}

class NotesNavIcon extends StatelessWidget {
  const NotesNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 67.0 : 43.0;
    return SvgPicture.asset(
      active
          ? 'assets/icons/highlighted notebook.svg'
          : 'assets/icons/notebook.svg',
      width: size,
      height: size,
    );
  }
}

class CalendarNavIcon extends StatelessWidget {
  const CalendarNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 66.0 : 43.0;
    return SvgPicture.asset(
      active
          ? 'assets/icons/highlighted calendar.svg'
          : 'assets/icons/calendar.svg',
      width: size,
      height: size,
    );
  }
}

class ArticlesNavIcon extends StatelessWidget {
  const ArticlesNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 66.0 : 43.0;
    return SvgPicture.asset(
      active
          ? 'assets/icons/highlighted megaphone.svg'
          : 'assets/icons/Megaphone.svg',
      width: size,
      height: size,
    );
  }
}
