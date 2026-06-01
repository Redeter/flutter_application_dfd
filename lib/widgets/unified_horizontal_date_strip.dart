import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import '../theme/peach_app_bar.dart';

const _weekdaysShortRu = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Горизонтальная полоса дат — статистика, календарь, заметки (единый стиль).
class UnifiedHorizontalDateStrip extends StatelessWidget {
  const UnifiedHorizontalDateStrip({
    super.key,
    required this.days,
    required this.selectedDay,
    required this.onDaySelected,
    this.markedDays = const <DateTime>{},
    this.stripHeight = defaultStripHeight,
    this.horizontalPadding = kPeachAppBarHorizontalInset,
    this.separatorWidth = 6,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;
  final Set<DateTime> markedDays;

  final double stripHeight;
  final double horizontalPadding;
  final double separatorWidth;

  /// С запасом под тень круга и оранжевой «таблетки» (тень не входит в layout).
  static const double defaultStripHeight = 106;
  static const double _kCircle = 40;
  /// Нижний отступ под boxShadow круга / выбранной даты.
  static const double _kShadowBottomInset = 8;

  static const Color selectedPillOrange = Color(0xFFF5A261);

  static bool sameCalendarDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final todayNorm = DateTime(today.year, today.month, today.day);

    return SizedBox(
      height: stripHeight,
      child: ListView.separated(
        clipBehavior: Clip.none,
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: days.length,
        separatorBuilder: (_, __) => SizedBox(width: separatorWidth),
        itemBuilder: (context, index) {
          final d = days[index];
          final isToday = sameCalendarDay(d, todayNorm);
          final selected = sameCalendarDay(d, selectedDay);
          final marked = markedDays.any((m) => sameCalendarDay(m, d));

          return GestureDetector(
            onTap: () => onDaySelected(d),
            child: selected
                ? _SelectedDatePill(
                    day: d,
                    isToday: isToday,
                    circleSize: _kCircle,
                    marked: marked,
                  )
                : (isToday
                    ? _TodayUnselectedFrame(
                        day: d,
                        circleSize: _kCircle,
                        marked: marked,
                      )
                    : _DayCircle(
                        day: d,
                        circleSize: _kCircle,
                        marked: marked,
                      )),
          );
        },
      ),
    );
  }
}

class _DayCircle extends StatelessWidget {
  const _DayCircle({
    required this.day,
    required this.circleSize,
    required this.marked,
  });

  final DateTime day;
  final double circleSize;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    final wd = _weekdaysShortRu[day.weekday - 1];
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          wd,
          style: GoogleFonts.alegreyaSans(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark.withValues(alpha: 0.74),
          ),
        ),
        const SizedBox(height: 7),
        Padding(
          padding: const EdgeInsets.only(
            bottom: UnifiedHorizontalDateStrip._kShadowBottomInset,
          ),
          child: Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(
                color: marked ? AppColors.orange : const Color(0xFFFFE0C8),
                width: marked ? 2.2 : 1.6,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
        ),
      ],
    ),
        if (marked)
          Positioned(
            right: 2,
            top: 26,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: AppColors.orange,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}

class _SelectedDatePill extends StatelessWidget {
  const _SelectedDatePill({
    required this.day,
    required this.isToday,
    required this.circleSize,
    required this.marked,
  });

  final DateTime day;
  final bool isToday;
  final double circleSize;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        bottom: UnifiedHorizontalDateStrip._kShadowBottomInset,
      ),
      child: Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: UnifiedHorizontalDateStrip.selectedPillOrange,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            isToday ? 'Сегодня' : _weekdaysShortRu[day.weekday - 1],
            style: GoogleFonts.alegreyaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 7),
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
            width: circleSize,
            height: circleSize,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
            ),
            child: Center(
              child: Text(
                '${day.day}',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ),
          ),
              if (marked)
                const Positioned(
                  right: 0,
                  bottom: -2,
                  child: SizedBox(
                    width: 8,
                    height: 8,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.orange,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    ),
    );
  }
}

/// Сегодня без выбора: на персиковой подложке — белая обводка и белая подпись.
class _TodayUnselectedFrame extends StatelessWidget {
  const _TodayUnselectedFrame({
    required this.day,
    required this.circleSize,
    required this.marked,
  });

  final DateTime day;
  final double circleSize;
  final bool marked;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 7, 11, 9),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: AppColors.white, width: 2.5),
        color: Colors.transparent,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Сегодня',
            style: GoogleFonts.alegreyaSans(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.25,
              color: AppColors.white,
            ),
          ),
          const SizedBox(height: 7),
          Padding(
            padding: const EdgeInsets.only(
              bottom: UnifiedHorizontalDateStrip._kShadowBottomInset,
            ),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.white,
                    border: Border.all(
                      color: marked ? AppColors.orange : const Color(0xFFFFE0C8),
                      width: marked ? 2.2 : 1.6,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      '${day.day}',
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                    ),
                  ),
                ),
                if (marked)
                  const Positioned(
                    right: 0,
                    bottom: -2,
                    child: SizedBox(
                      width: 8,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: AppColors.orange,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
