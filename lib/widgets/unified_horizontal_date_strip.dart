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
    this.stripHeight = defaultStripHeight,
    this.horizontalPadding = kPeachAppBarHorizontalInset,
    this.separatorWidth = 6,
  });

  final List<DateTime> days;
  final DateTime selectedDay;
  final ValueChanged<DateTime> onDaySelected;

  final double stripHeight;
  final double horizontalPadding;
  final double separatorWidth;

  /// Чуть выше компактного режима — даты не «слипаются».
  static const double defaultStripHeight = 96;
  static const double _kCircle = 40;

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
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        itemCount: days.length,
        separatorBuilder: (_, __) => SizedBox(width: separatorWidth),
        itemBuilder: (context, index) {
          final d = days[index];
          final isToday = sameCalendarDay(d, todayNorm);
          final selected = sameCalendarDay(d, selectedDay);

          return GestureDetector(
            onTap: () => onDaySelected(d),
            child: selected
                ? _SelectedDatePill(
                    day: d,
                    isToday: isToday,
                    circleSize: _kCircle,
                  )
                : (isToday
                    ? _TodayUnselectedFrame(day: d, circleSize: _kCircle)
                    : _DayCircle(day: d, circleSize: _kCircle)),
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
  });

  final DateTime day;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    final wd = _weekdaysShortRu[day.weekday - 1];
    return Column(
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
        Container(
          width: circleSize,
          height: circleSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            border: Border.all(
              color: const Color(0xFFFFE0C8),
              width: 1.6,
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
      ],
    );
  }
}

class _SelectedDatePill extends StatelessWidget {
  const _SelectedDatePill({
    required this.day,
    required this.isToday,
    required this.circleSize,
  });

  final DateTime day;
  final bool isToday;
  final double circleSize;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
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
        ],
      ),
    );
  }
}

/// Сегодня без выбора: на персиковой подложке — белая обводка и белая подпись.
class _TodayUnselectedFrame extends StatelessWidget {
  const _TodayUnselectedFrame({
    required this.day,
    required this.circleSize,
  });

  final DateTime day;
  final double circleSize;

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
          Container(
            width: circleSize,
            height: circleSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.white,
              border: Border.all(color: const Color(0xFFFFE0C8), width: 1.6),
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
        ],
      ),
    );
  }
}
