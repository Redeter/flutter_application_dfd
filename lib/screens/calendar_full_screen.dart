import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

const _months = [
  'ЯНВАРЬ', 'ФЕВРАЛЬ', 'МАРТ', 'АПРЕЛЬ', 'МАЙ', 'ИЮНЬ',
  'ИЮЛЬ', 'АВГУСТ', 'СЕНТЯБРЬ', 'ОКТЯБРЬ', 'НОЯБРЬ', 'ДЕКАБРЬ',
];
const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

class CalendarFullScreen extends StatefulWidget {
  const CalendarFullScreen({
    super.key,
    required this.selectedDate,
    required this.onDateSelected,
    required this.onOpenDay,
    this.onAddAppointment,
  });

  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;
  final ValueChanged<DateTime> onOpenDay;
  final ValueChanged<DateTime>? onAddAppointment;

  @override
  State<CalendarFullScreen> createState() => _CalendarFullScreenState();
}

class _CalendarFullScreenState extends State<CalendarFullScreen> {
  bool _isMonthView = true;
  late DateTime _cursor;
  late DateTime _pickedDate;

  @override
  void initState() {
    super.initState();
    _cursor = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _pickedDate = widget.selectedDate;
  }

  List<DateTime> get _visibleMonths {
    if (_isMonthView) {
      return [
        DateTime(_cursor.year, _cursor.month),
        DateTime(_cursor.year, _cursor.month + 1),
        DateTime(_cursor.year, _cursor.month + 2),
      ];
    }
    return List.generate(
      12,
      (i) => DateTime(_cursor.year, i + 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppColors.headerPeach,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            padding: EdgeInsets.only(top: topInset),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textDark),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _toggleChip('Месяц', _isMonthView),
                        _toggleChip('Год', !_isMonthView),
                      ],
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 48),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: _weekdays.map((w) => Expanded(
                        child: Center(
                          child: Text(
                            w,
                            style: GoogleFonts.alegreyaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark.withValues(alpha: 0.6),
                            ),
                          ),
                        ),
                      )).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                      itemCount: _visibleMonths.length,
                      itemBuilder: (context, i) {
                        final m = _visibleMonths[i];
                        return _MonthCard(
                          month: m,
                          selectedDate: _pickedDate,
                          onDateTap: (d) {
                            setState(() => _pickedDate = d);
                            widget.onDateSelected(d);
                            widget.onOpenDay(d);
                            Navigator.pop(context);
                          },
                        );
                      },
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    child: Row(
                      children: [
                        if (widget.onAddAppointment != null)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: FilledButton(
                                onPressed: () {
                                  widget.onAddAppointment!(_pickedDate);
                                },
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.orange,
                                  foregroundColor: AppColors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 18),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(24),
                                  ),
                                ),
                                child: Text(
                                  'Добавить запись',
                                  style: GoogleFonts.alegreyaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        Expanded(
                          child: FilledButton(
                            onPressed: () {
                              widget.onDateSelected(_pickedDate);
                              widget.onOpenDay(_pickedDate);
                              Navigator.pop(context);
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.orange,
                              foregroundColor: AppColors.white,
                              padding: const EdgeInsets.symmetric(vertical: 18),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
                              ),
                            ),
                            child: Text(
                              'Открыть этот день',
                              style: GoogleFonts.alegreyaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toggleChip(String label, bool selected) {
    return GestureDetector(
      onTap: () => setState(() => _isMonthView = label == 'Месяц'),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.orange : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          label,
          style: GoogleFonts.alegreyaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: selected ? AppColors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({
    required this.month,
    required this.selectedDate,
    required this.onDateTap,
  });

  final DateTime month;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateTap;

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final last = DateTime(month.year, month.month + 1, 0);
    final leadingEmpty = first.weekday - 1;
    final daysInMonth = last.day;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            _months[month.month - 1],
            style: GoogleFonts.alegreyaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.orange,
            ),
          ),
          const SizedBox(height: 16),
          ...List.generate(rows, (row) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: List.generate(7, (col) {
                  final idx = row * 7 + col;
                  if (idx < leadingEmpty) {
                    return const Expanded(child: SizedBox());
                  }
                  final day = idx - leadingEmpty + 1;
                  if (day > daysInMonth) {
                    return const Expanded(child: SizedBox());
                  }
                  final d = DateTime(month.year, month.month, day);
                  final selected = _isSameDay(d, selectedDate);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onDateTap(d),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            color: selected ? AppColors.orange : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '$day',
                              style: GoogleFonts.alegreyaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: selected
                                    ? AppColors.white
                                    : AppColors.textDark,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            );
          }),
        ],
      ),
    );
  }
}
