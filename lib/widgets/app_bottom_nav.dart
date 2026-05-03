import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Зона иконки фиксированной высоты (чуть выше базовых 60 — под увеличенную иконку статистики).
const double _kBottomNavIconSlotHeight = 62;
/// Высота блока подписи не меняется; текст скрывают через opacity, чтобы не дергалась верстка.
const double _kBottomNavLabelSlotHeight = 20;
/// Обычные иконки + подпись чуть выше (отрицательное dy — вверх).
const double _kBottomNavInactiveLift = 10;
/// Highlight-иконки активной вкладки чуть ниже.
const double _kBottomNavActiveDrop = 10;
/// Сдвиг только иконки «Статистика» (вверх).
const double _kStatisticsIconNudgeY = -2;
/// Сдвиг только иконки «Календарь» (вниз).
const double _kCalendarIconNudgeY = 1;

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
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _BottomNavItem(
                  label: 'СТАТИСТИКА',
                  isActive: activeTab == BottomNavTab.statistics,
                  iconBuilder: (a) => StatisticsNavIcon(active: a),
                  onTap: () => onTabSelected(BottomNavTab.statistics),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'ЗАМЕТКИ',
                  isActive: activeTab == BottomNavTab.notes,
                  iconBuilder: (a) => NotesNavIcon(active: a),
                  onTap: () => onTabSelected(BottomNavTab.notes),
                ),
              ),
              const SizedBox(width: 72),
              Expanded(
                child: _BottomNavItem(
                  label: 'КАЛЕНДАРЬ',
                  isActive: activeTab == BottomNavTab.calendar,
                  iconBuilder: (a) => CalendarNavIcon(active: a),
                  onTap: () => onTabSelected(BottomNavTab.calendar),
                ),
              ),
              Expanded(
                child: _BottomNavItem(
                  label: 'ЦЕЛИ',
                  isActive: activeTab == BottomNavTab.articles,
                  iconBuilder: (a) => ArticlesNavIcon(active: a),
                  onTap: () => onTabSelected(BottomNavTab.articles),
                ),
              ),
            ],
          ),
          Positioned(
            child: GestureDetector(
              onTap: onCenterTap,
              child: SizedBox(
                width: 72,
                height: 72,
                child: Center(
                  child: Transform.translate(
                    offset: const Offset(0, -8),
                    child: SvgPicture.asset(
                      'assets/icons/plus.svg',
                      width: 60,
                      height: 60,
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
      child: Transform.translate(
        offset: Offset(
          0,
          isActive ? _kBottomNavActiveDrop : -_kBottomNavInactiveLift,
        ),
        child: SizedBox(
          width: double.infinity,
          height: _kBottomNavIconSlotHeight + _kBottomNavLabelSlotHeight,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(
                height: _kBottomNavIconSlotHeight,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: iconBuilder(isActive),
                ),
              ),
              SizedBox(
                height: _kBottomNavLabelSlotHeight,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: ExcludeSemantics(
                      excluding: isActive,
                      child: Opacity(
                        opacity: isActive ? 0 : 1,
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class StatisticsNavIcon extends StatelessWidget {
  const StatisticsNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 61.0 : 42.0;
    return Transform.translate(
      offset: const Offset(0, _kStatisticsIconNudgeY),
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
    final size = active ? 60.0 : 40.0;
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
    final size = active ? 60.0 : 40.0;
    return Transform.translate(
      offset: const Offset(0, _kCalendarIconNudgeY),
      child: SvgPicture.asset(
        active
            ? 'assets/icons/highlighted calendar.svg'
            : 'assets/icons/calendar.svg',
        width: size,
        height: size,
      ),
    );
  }
}

class ArticlesNavIcon extends StatelessWidget {
  const ArticlesNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final size = active ? 60.0 : 40.0;
    return SvgPicture.asset(
      active
          ? 'assets/icons/highlighted megaphone.svg'
          : 'assets/icons/Megaphone.svg',
      width: size,
      height: size,
    );
  }
}
