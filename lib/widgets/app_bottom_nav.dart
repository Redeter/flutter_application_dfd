import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';

/// Зона иконки фиксированной высоты (чуть выше базовых 60 — под увеличенную иконку статистики).
const double _kBottomNavIconSlotHeight = 58;
/// Высота блока подписи не меняется; текст скрывают через opacity, чтобы не дергалась верстка.
const double _kBottomNavLabelSlotHeight = 22;
/// Обычные иконки + подпись чуть выше (отрицательное dy — вверх).
const double _kBottomNavInactiveLift = 1;
/// Highlight-иконки активной вкладки чуть ниже.
const double _kBottomNavActiveDrop = 0;
/// Сдвиг только иконки «Статистика» (вверх).
const double _kStatisticsIconNudgeY = -1;
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
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      height: 94,
      decoration: BoxDecoration(
        color: AppColors.orange,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
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
            child: _RotatingPlusButton(onTap: onCenterTap),
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
    final targetDy = isActive ? _kBottomNavActiveDrop : -_kBottomNavInactiveLift;
    return _TapScale(
      onTap: onTap,
      child: SizedBox(
        width: double.infinity,
        height: _kBottomNavIconSlotHeight + _kBottomNavLabelSlotHeight,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: targetDy, end: targetDy),
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOutCubic,
          builder: (_, dy, child) => Transform.translate(
            offset: Offset(0, dy),
            child: child,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.max,
            children: [
              SizedBox(
                height: _kBottomNavIconSlotHeight,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.center,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: isActive ? 0.92 : 1.0, end: isActive ? 1.0 : 0.92),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    builder: (_, scale, child) => Transform.scale(
                      scale: scale,
                      child: child,
                    ),
                    child: iconBuilder(isActive),
                  ),
                ),
              ),
              SizedBox(
                height: _kBottomNavLabelSlotHeight,
                width: double.infinity,
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Transform.translate(
                    offset: const Offset(0, -5),
                    child: ExcludeSemantics(
                      excluding: isActive,
                      child: AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
                        opacity: isActive ? 0 : 1,
                        child: Text(
                          label.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 10.5,
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
    final size = active ? 60.0 : 40.0;
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

class _TapScale extends StatefulWidget {
  const _TapScale({
    required this.child,
    required this.onTap,
  });

  final Widget child;
  final VoidCallback? onTap;

  @override
  State<_TapScale> createState() => _TapScaleState();
}

class _RotatingPlusButton extends StatefulWidget {
  const _RotatingPlusButton({required this.onTap});

  final VoidCallback? onTap;

  @override
  State<_RotatingPlusButton> createState() => _RotatingPlusButtonState();
}

class _RotatingPlusButtonState extends State<_RotatingPlusButton> {
  double _turns = 0;
  bool _animating = false;

  Future<void> _handleTap() async {
    widget.onTap?.call();
    if (_animating) {
      return;
    }
    _animating = true;
    setState(() => _turns = 0.125);
    await Future<void>.delayed(const Duration(milliseconds: 280));
    if (mounted) {
      setState(() => _turns = 0.0);
    }
    _animating = false;
  }

  @override
  Widget build(BuildContext context) {
    return _TapScale(
      onTap: _handleTap,
      child: SizedBox(
        width: 72,
        height: 72,
        child: Center(
          child: Transform.translate(
            offset: const Offset(0, -6),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 66,
                  height: 66,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
                ),
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.14),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                ),
                AnimatedRotation(
                  turns: _turns,
                  duration: const Duration(milliseconds: 360),
                  curve: Curves.easeOutBack,
                  child: SvgPicture.asset(
                    'assets/icons/plus.svg',
                    width: 60,
                    height: 60,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TapScaleState extends State<_TapScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOutCubic,
        scale: _pressed ? 0.97 : 1.0,
        child: widget.child,
      ),
    );
  }
}
