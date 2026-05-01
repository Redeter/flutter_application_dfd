import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

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
                label: 'ЦЕЛИ',
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
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.white,
                ),
                child: const Center(
                  child: Icon(
                    Icons.add,
                    color: AppColors.orange,
                    size: 40,
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
      ),
    );
  }
}

class StatisticsNavIcon extends StatelessWidget {
  const StatisticsNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange, width: 2),
      ),
      child: Center(
        child: SizedBox(
          width: 34,
          height: 34,
          child: CustomPaint(
            painter: _PieChartPainter(
              color: AppColors.orange,
              accentColor: AppColors.cream,
            ),
          ),
        ),
      ),
    );
    return _maybeActiveWrap(active, inner);
  }
}

class NotesNavIcon extends StatelessWidget {
  const NotesNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange, width: 2),
      ),
      child: Center(
        child: Stack(
          children: [
            Container(
              margin: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _docLine(1),
                  _docLine(1),
                  _docLine(0.7),
                ],
              ),
            ),
            Positioned(
              right: 8,
              top: 8,
              child: Transform.rotate(
                angle: -0.5,
                child: Container(
                  width: 18,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.greyMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return _maybeActiveWrap(active, inner);
  }

  Widget _docLine(double widthFactor) {
    return SizedBox(
      width: 22 * widthFactor,
      child: Container(
        height: 3,
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

class CalendarNavIcon extends StatelessWidget {
  const CalendarNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange, width: 2),
      ),
      child: Center(
        child: Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Stack(
            children: [
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: 24,
                  height: 22,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 6,
                left: 7,
                right: 7,
                child: Container(
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.greyMuted,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                left: 11,
                child: _bubble(),
              ),
              Positioned(
                top: 2,
                right: 11,
                child: _bubble(),
              ),
            ],
          ),
        ),
      ),
    );
    return _maybeActiveWrap(active, inner);
  }

  Widget _bubble() {
    return Container(
      width: 6,
      height: 6,
      decoration: BoxDecoration(
        color: AppColors.greyMuted,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

class ArticlesNavIcon extends StatelessWidget {
  const ArticlesNavIcon({super.key, required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final inner = Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.orange, width: 2),
      ),
      child: Center(
        child: Stack(
          alignment: Alignment.centerLeft,
          children: [
            Container(
              width: 30,
              height: 22,
              decoration: BoxDecoration(
                color: AppColors.orange,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            Positioned(
              right: 5,
              child: Container(
                width: 10,
                height: 16,
                decoration: BoxDecoration(
                  color: AppColors.greyMuted,
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            Positioned(
              left: 8,
              child: Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
            Positioned(
              left: 14,
              bottom: 5,
              child: Container(
                width: 11,
                height: 11,
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
            ),
          ],
        ),
      ),
    );
    return _maybeActiveWrap(active, inner);
  }
}

/// Белая обводка вокруг активной иконки (макет «Заметки»).
Widget _maybeActiveWrap(bool active, Widget child) {
  if (!active) return child;
  return Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.white, width: 3),
    ),
    child: child,
  );
}

class _PieChartPainter extends CustomPainter {
  const _PieChartPainter({required this.color, required this.accentColor});

  final Color color;
  final Color accentColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, radius, paint);

    final cutoutPaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.fill;

    const startAngle = -0.5;
    const sweepAngle = 0.52;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + 1),
      startAngle,
      sweepAngle,
      true,
      cutoutPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
