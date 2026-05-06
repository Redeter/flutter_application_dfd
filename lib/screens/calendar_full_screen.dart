import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

const _months = [
  'ЯНВАРЬ', 'ФЕВРАЛЬ', 'МАРТ', 'АПРЕЛЬ', 'МАЙ', 'ИЮНЬ',
  'ИЮЛЬ', 'АВГУСТ', 'СЕНТЯБРЬ', 'ОКТЯБРЬ', 'НОЯБРЬ', 'ДЕКАБРЬ',
];

const _monthsLower = [
  'январь', 'февраль', 'март', 'апрель', 'май', 'июнь',
  'июль', 'август', 'сентябрь', 'октябрь', 'ноябрь', 'декабрь',
];

const _weekdays = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

/// Фиксированная высота одного года в вертикальном списке — совпадает с [ListView.itemExtent]
/// для корректной прокрутки к текущему году (с запасом под сетку 12 месяцев).
const double _kYearBlockExtent = 640;

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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
  late final int _yearListStart;
  late final int _yearListEnd;
  late final ScrollController _yearScrollController;

  @override
  void initState() {
    super.initState();
    _cursor = DateTime(widget.selectedDate.year, widget.selectedDate.month);
    _pickedDate = widget.selectedDate;
    final nowY = DateTime.now().year;
    final selY = widget.selectedDate.year;
    // По умолчанию — годы вокруг текущего; к краям прошлого/будущего расширяем только если выбранная дата вне окна.
    _yearListStart = nowY - 20;
    _yearListEnd = nowY + 15;
    if (selY < _yearListStart) _yearListStart = selY;
    if (selY > _yearListEnd) _yearListEnd = selY;
    final yearIndex = (nowY - _yearListStart).clamp(0, _yearListEnd - _yearListStart);
    _yearScrollController = ScrollController(
      initialScrollOffset: yearIndex * _kYearBlockExtent,
    );
  }

  @override
  void dispose() {
    _yearScrollController.dispose();
    super.dispose();
  }

  void _scrollYearListToCurrentYear() {
    if (!_yearScrollController.hasClients) return;
    final nowY = DateTime.now().year;
    final yi = (nowY - _yearListStart).clamp(0, _yearListEnd - _yearListStart);
    final target = yi * _kYearBlockExtent;
    _yearScrollController.jumpTo(
      target.clamp(0.0, _yearScrollController.position.maxScrollExtent),
    );
  }

  /// Запись на приём — только на будущие даты (не сегодня и не раньше).
  bool get _canAddAppointmentForPickedDay {
    if (widget.onAddAppointment == null) return false;
    final today = _dayOnly(DateTime.now());
    final picked = _dayOnly(_pickedDate);
    return picked.isAfter(today);
  }

  void _openMonthFromYear(int year, int month) {
    final lastDay = DateTime(year, month + 1, 0).day;
    final day = math.min(_pickedDate.day, lastDay);
    setState(() {
      _isMonthView = true;
      _cursor = DateTime(year, month);
      _pickedDate = DateTime(year, month, day);
    });
  }

  List<DateTime> get _visibleMonths {
    if (_isMonthView) {
      return [
        DateTime(_cursor.year, _cursor.month),
        DateTime(_cursor.year, _cursor.month + 1),
        DateTime(_cursor.year, _cursor.month + 2),
      ];
    }
    return const [];
  }

  int get _yearCount => _yearListEnd - _yearListStart + 1;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(),
            const SizedBox(height: 16),
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
<<<<<<< Updated upstream
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
=======
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: AppColors.textDark),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.white.withValues(alpha: 0.75),
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
                  if (_isMonthView) ...[
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Row(
                        children: _weekdays
                            .map(
                              (w) => Expanded(
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
                              ),
                            )
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Expanded(
                    child: _isMonthView ? _buildMonthScroll() : _buildYearScroll(),
                  ),
                  if (_isMonthView)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Row(
                        children: [
                          if (_canAddAppointmentForPickedDay)
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
>>>>>>> Stashed changes
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: const BoxDecoration(
        color: AppColors.headerPeach,
      ),
      child: Column(
        children: [
          Row(
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
        ],
      ),
    );
  }

  Widget _buildMonthScroll() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
      itemCount: _visibleMonths.length,
      itemBuilder: (context, i) {
        final m = _visibleMonths[i];
        return _MonthCard(
          month: m,
          selectedDate: _pickedDate,
          onDateTap: (d) {
            setState(() => _pickedDate = d);
          },
        );
      },
    );
  }

  Widget _buildYearScroll() {
    return ListView.builder(
      controller: _yearScrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemExtent: _kYearBlockExtent,
      itemCount: _yearCount,
      itemBuilder: (context, index) {
        final year = _yearListStart + index;
        final showDivider = index > 0;
        return LayoutBuilder(
          builder: (context, constraints) {
            return FittedBox(
              fit: BoxFit.contain,
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: constraints.maxWidth,
                child: _YearSection(
                  year: year,
                  showTopDivider: showDivider,
                  onOpenMonth: _openMonthFromYear,
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _toggleChip(String label, bool selected) {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isMonthView = label == 'Месяц';
          if (!_isMonthView) {
            _cursor = DateTime(_pickedDate.year, _pickedDate.month);
          }
        });
        if (!_isMonthView) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollYearListToCurrentYear();
          });
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AppColors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.06),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: GoogleFonts.alegreyaSans(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }
}

class _YearSection extends StatelessWidget {
  const _YearSection({
    required this.year,
    required this.showTopDivider,
    required this.onOpenMonth,
  });

  final int year;
  final bool showTopDivider;
  final void Function(int year, int month) onOpenMonth;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showTopDivider) ...[
          const SizedBox(height: 8),
          Divider(height: 1, color: AppColors.greyMuted.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
        ],
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Text(
            '$year',
            style: GoogleFonts.alegreyaSans(
              fontSize: 32,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
              height: 1.1,
            ),
          ),
        ),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.02,
          children: List.generate(
            12,
            (mi) => _CompactMonthCell(
              year: year,
              month: mi + 1,
              onOpenMonth: () => onOpenMonth(year, mi + 1),
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
    );
  }
}

class _CompactMonthCell extends StatelessWidget {
  const _CompactMonthCell({
    required this.year,
    required this.month,
    required this.onOpenMonth,
  });

  final int year;
  final int month;
  final VoidCallback onOpenMonth;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(year, month, 1);
    final last = DateTime(year, month + 1, 0);
    final leadingEmpty = first.weekday - 1;
    final daysInMonth = last.day;
    final totalCells = leadingEmpty + daysInMonth;
    final rows = (totalCells / 7).ceil();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onOpenMonth,
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
              child: Center(
                child: Text(
                  _monthsLower[month - 1],
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.orange,
                    decoration: TextDecoration.underline,
                    decorationColor: AppColors.orange.withValues(alpha: 0.5),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Expanded(
          child: Column(
            children: List.generate(rows, (row) {
              return Expanded(
                child: Row(
                  children: List.generate(7, (col) {
                    final idx = row * 7 + col;
                    if (idx < leadingEmpty || idx - leadingEmpty + 1 > daysInMonth) {
                      return const Expanded(child: SizedBox());
                    }
                    final day = idx - leadingEmpty + 1;
                    return Expanded(
                      child: IgnorePointer(
                        child: Center(
                          child: Text(
                            '$day',
                            style: GoogleFonts.alegreyaSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ),
                    );
                  }),
                ),
              );
            }),
          ),
        ),
      ],
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
    final n = DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
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
                  final isToday = _isSameDay(d, today);
                  final highlighted = selected || isToday;
                  final Color? circleFill = selected
                      ? AppColors.orange
                      : (isToday ? AppColors.appointmentCardFrame : null);
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onDateTap(d),
                      child: Padding(
                        padding: const EdgeInsets.all(2),
                        child: Container(
                          height: 40,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: circleFill,
                          ),
                          child: Text(
                            '$day',
                            style: GoogleFonts.alegreyaSans(
                              fontSize: 16,
                              fontWeight: highlighted ? FontWeight.w700 : FontWeight.w600,
                              color: highlighted ? AppColors.white : AppColors.textDark,
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
