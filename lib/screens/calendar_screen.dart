import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/calendar_entry.dart';
import '../services/calendar_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/delete_confirm_dialog.dart';
import 'add_appointment_screen.dart';
import 'add_medication_screen.dart';
import 'articles_screen.dart';
import 'calendar_full_screen.dart';
import 'notes_screen.dart';
import 'state_categories_sheet.dart';
import 'statistics_screen.dart';

const _weekdaysShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const _months = [
  'ЯНВАРЯ', 'ФЕВРАЛЯ', 'МАРТА', 'АПРЕЛЯ', 'МАЯ', 'ИЮНЯ',
  'ИЮЛЯ', 'АВГУСТА', 'СЕНТЯБРЯ', 'ОКТЯБРЯ', 'НОЯБРЯ', 'ДЕКАБРЯ',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

<<<<<<< Updated upstream
=======
/// Единый размер иллюстрации слева от вертикальной линии в карточках календаря (приём / препарат).
const double _kCalendarCardLeadingIconExtent = 44;

/// Одна строка списка дня: приём врача или один слот препарата.
sealed class _CalendarDayRow {
  int get sortMinutes;
}

final class _MedDoseRow extends _CalendarDayRow {
  _MedDoseRow(this.med, this.doseIndex);
  final Medication med;
  final int doseIndex;

  @override
  int get sortMinutes {
    final TimeOfDay t;
    if (med.schedule.isEmpty) {
      t = med.time;
    } else {
      t = med.schedule[doseIndex.clamp(0, med.schedule.length - 1)].time;
    }
    return t.hour * 60 + t.minute;
  }
}

final class _AppDayRow extends _CalendarDayRow {
  _AppDayRow(this.appointment);
  final Appointment appointment;

  @override
  int get sortMinutes {
    final t = appointment.time;
    return t.hour * 60 + t.minute;
  }
}

List<_CalendarDayRow> _sortedDayRows(List<CalendarEntry> entries) {
  final out = <_CalendarDayRow>[];
  for (final e in entries) {
    switch (e) {
      case Medication m:
        if (m.schedule.isEmpty) {
          out.add(_MedDoseRow(m, 0));
        } else {
          for (var i = 0; i < m.schedule.length; i++) {
            out.add(_MedDoseRow(m, i));
          }
        }
      case Appointment a:
        out.add(_AppDayRow(a));
    }
  }
  out.sort((a, b) => a.sortMinutes.compareTo(b.sortMinutes));
  return out;
}

>>>>>>> Stashed changes
class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<CalendarEntry> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final date = _selectedDate;
    final list = await CalendarStorage.instance.loadForDate(date);
    if (mounted && date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day) {
      setState(() => _entries = list);
    }
  }

  void _onDateChanged(DateTime d) {
    if (d.year == _selectedDate.year &&
        d.month == _selectedDate.month &&
        d.day == _selectedDate.day) {
      return;
    }
    setState(() => _selectedDate = d);
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _load();
    });
  }

  void _openFullCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarFullScreen(
          selectedDate: _selectedDate,
          onDateSelected: _onDateChanged,
          onOpenDay: (_) => _load(),
          onAddAppointment: (d) async {
            Navigator.pop(context);
            _onDateChanged(d);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddAppointmentScreen(date: d),
              ),
            );
            _load();
          },
        ),
      ),
    ).then((_) => _load());
  }

  void _showAddChoice() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.medication_outlined, color: AppColors.orange),
                title: const Text('Добавить препарат'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddMedication();
                },
              ),
              ListTile(
                leading: const Icon(Icons.event_note_outlined, color: AppColors.orange),
                title: const Text('Добавить запись на приём'),
                onTap: () {
                  Navigator.pop(ctx);
                  _openAddAppointment();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openAddMedication({Medication? m}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddMedicationScreen(
          medication: m,
          date: _selectedDate,
        ),
      ),
    );
    _load();
  }

  Future<void> _openAddAppointment({Appointment? a}) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AddAppointmentScreen(
          appointment: a,
          date: _selectedDate,
        ),
      ),
    );
    _load();
  }

  Future<void> _deleteEntry(CalendarEntry e) async {
    final name = switch (e) {
      Medication(:final name) => name,
      Appointment(:final title) => title,
    };
    final ok = await showDeleteConfirmDialog(
      context,
      title: 'ВЫ ТОЧНО ХОТИТЕ УДАЛИТЬ $name?',
    );
    if (ok == true) {
      await CalendarStorage.instance.delete(e.id);
      _load();
    }
  }

  Future<void> _markTaken(Medication m) async {
    await CalendarStorage.instance.save(
      m.copyWith(takenAt: DateTime.now()),
    );
    _load();
  }

  void _onNavTab(BottomNavTab tab) {
    switch (tab) {
      case BottomNavTab.calendar:
        return;
      case BottomNavTab.statistics:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StatisticsScreen()),
        );
      case BottomNavTab.notes:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NotesScreen()),
        );
      case BottomNavTab.articles:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const ArticlesScreen()),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _buildHeader(),
            _buildDateStrip(),
            Expanded(
              child: Stack(
                children: [
                  _buildBackgroundShapes(),
                  _entries.isEmpty ? _buildEmpty() : _buildList(),
                ],
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          elevation: 6,
          shadowColor: AppColors.orange.withValues(alpha: 0.45),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: _showAddChoice,
            child: Ink(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.orange,
              ),
              child: Center(
                child: SizedBox(
                  width: 60,
                  height: 60,
                  child: SvgPicture.asset(
                    'assets/icons/new pill button.svg',
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: AppBottomNavBar(
        activeTab: BottomNavTab.calendar,
        onTabSelected: _onNavTab,
        onCenterTap: () => showStateCategoriesSheet(context),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
      decoration: const BoxDecoration(
        color: AppColors.headerPeach,
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () {},
            style: IconButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.white,
            ),
            icon: const Icon(Icons.person_outline_rounded),
          ),
          Expanded(
            child: Center(
              child: Text(
                _formatDate(_selectedDate).toUpperCase(),
                style: GoogleFonts.alegreyaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.white,
                ),
              ),
            ),
          ),
          IconButton(
            onPressed: _openFullCalendar,
            style: IconButton.styleFrom(
              backgroundColor: AppColors.orange,
              foregroundColor: AppColors.white,
            ),
            icon: const Icon(Icons.calendar_month_rounded),
          ),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
<<<<<<< Updated upstream
    final days = List.generate(14, (i) => base.add(Duration(days: i - 5)));
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: days.map((d) {
          final isToday = d.year == today.year &&
              d.month == today.month &&
              d.day == today.day;
          final selected = d.year == _selectedDate.year &&
              d.month == _selectedDate.month &&
              d.day == _selectedDate.day;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () => _onDateChanged(d),
                borderRadius: BorderRadius.circular(24),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        isToday ? 'Сегодня' : _weekdaysShort[d.weekday - 1],
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: selected
                              ? AppColors.white
                              : AppColors.textDark.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected ? AppColors.orange : AppColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: selected
                                ? AppColors.orange
                                : AppColors.orange.withValues(alpha: 0.3),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? AppColors.white
                                : AppColors.textDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBackgroundShapes() {
    return Stack(
      children: [
        Positioned(
          top: -80,
          right: -80,
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
          ),
        ),
        Positioned(
          bottom: 100,
          left: -60,
          child: Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
          ),
        ),
      ],
=======
    var days = List.generate(14, (i) => base.add(Duration(days: i - 5)));
    final sel = _dayOnly(_selectedDate);
    if (sel.isBefore(days.first) || sel.isAfter(days.last)) {
      days = List.generate(14, (i) => sel.add(Duration(days: i - 5)));
    }
    return UnifiedHorizontalDateStrip(
      days: days,
      selectedDay: _selectedDate,
      onDaySelected: _onDateChanged,
>>>>>>> Stashed changes
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Text(
        'Нет препаратов сегодня',
        style: GoogleFonts.alegreyaSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: AppColors.textDark.withValues(alpha: 0.7),
        ),
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: _entries.length,
      itemBuilder: (context, i) {
        final e = _entries[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: switch (e) {
            Medication() => _MedicationCard(
                medication: e,
                onEdit: () => _openAddMedication(m: e),
                onDelete: () => _deleteEntry(e),
                onMarkTaken: () => _markTaken(e),
              ),
            Appointment() => _AppointmentCard(
                appointment: e,
                onEdit: () => _openAddAppointment(a: e),
                onDelete: () => _deleteEntry(e),
              ),
          },
        );
      },
    );
  }
}

<<<<<<< Updated upstream
class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
=======
/// Кнопки действия в макете: пастельный фон + тёмный текст (белый на таких фонах нечитаем).
const Color _medBtnSkipBg = Color(0xFFFFCDD2);
const Color _medBtnTakeBg = Color(0xFFC8E6C9);
const Color _medBtnTimeBg = Color(0xFFFFF9C4);

class _MedicationDoseCard extends StatelessWidget {
  const _MedicationDoseCard({
>>>>>>> Stashed changes
    required this.medication,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkTaken,
  });

  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkTaken;

  Widget _pillLeadingIcon() {
    return SizedBox(
      width: _kCalendarCardLeadingIconExtent,
      height: _kCalendarCardLeadingIconExtent,
      child: SvgPicture.asset(
        'assets/icons/pill.svg',
        fit: BoxFit.contain,
      ),
    );
  }

  Widget _orangeFrameShell({required Widget whiteBody}) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.appointmentCardFrame,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.appointmentCardFrame.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 0, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: AppColors.white, size: 24),
                ),
                IconButton(
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.white, size: 24),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: whiteBody,
          ),
        ],
      ),
    );
  }

  Widget _infoRow({
    required String timeStr,
    required String takeText,
    bool muted = false,
    Widget? footer,
  }) {
    final m = medication;
    final opacity = muted ? 0.5 : 1.0;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Opacity(
              opacity: opacity,
              child: _pillLeadingIcon(),
            ),
          ),
          const SizedBox(width: 10),
          Container(
            width: 1,
            color: AppColors.textDark.withValues(alpha: muted ? 0.2 : 0.35),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textDark.withValues(alpha: muted ? 0.55 : 1),
                          ),
                          children: [
                            TextSpan(text: '${m.name.toUpperCase()} '),
                            TextSpan(
                              text: m.dosage,
                              style: GoogleFonts.alegreyaSans(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: AppColors.textDark.withValues(alpha: muted ? 0.45 : 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Text(
                      timeStr,
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark.withValues(alpha: muted ? 0.35 : 1),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  takeText.toUpperCase(),
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                    color: AppColors.textDark.withValues(alpha: muted ? 0.45 : 0.95),
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 10),
                  footer,
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
<<<<<<< Updated upstream
    final taken = medication.takenAt != null;
    final timeStr = medication.schedule.isNotEmpty
        ? '${medication.schedule.first.time.hour.toString().padLeft(2, '0')}:${medication.schedule.first.time.minute.toString().padLeft(2, '0')}'
        : '--:--';
    final takeText = medication.schedule.map((s) => s.amount).join(' + ');

    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.orange, width: 3),
        boxShadow: [
          BoxShadow(
            color: AppColors.orange.withValues(alpha: 0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
            decoration: BoxDecoration(
              color: AppColors.orange.withValues(alpha: 0.2),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.textDark),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.textDark),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.medication_outlined, color: AppColors.orange, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${medication.name} ${medication.dosage}',
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        taken
                            ? 'Принято в ${medication.takenAt!.hour.toString().padLeft(2, '0')}:${medication.takenAt!.minute.toString().padLeft(2, '0')}'
                            : 'Принять $takeText',
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: taken ? AppColors.takeGreen : AppColors.textDark.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  timeStr,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: taken ? AppColors.takeGreen : AppColors.textDark,
=======
    final MedicationDose dose;
    if (medication.schedule.isNotEmpty) {
      dose = medication.schedule[doseIndex.clamp(0, medication.schedule.length - 1)];
    } else {
      dose = MedicationDose(
        time: medication.time,
        amount: medication.dosage.isEmpty ? '—' : medication.dosage,
      );
    }
    final takenList = medication.takenAtPerDose;
    final idx = medication.schedule.isNotEmpty ? doseIndex : 0;
    final taken = idx < takenList.length && takenList[idx] != null;
    final takenAt = taken ? takenList[idx]! : null;
    final skippedList = medication.skippedPerDose;
    final skipped = idx < skippedList.length && skippedList[idx];
    final timeStr =
        '${dose.time.hour.toString().padLeft(2, '0')}:${dose.time.minute.toString().padLeft(2, '0')}';
    final takeText = dose.amount;
    final instruction = 'Принять $takeText';

    if (taken && takenAt != null) {
      final takenStr =
          '${takenAt.hour.toString().padLeft(2, '0')}:${takenAt.minute.toString().padLeft(2, '0')}';
      return _orangeFrameShell(
        whiteBody: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: _infoRow(
            timeStr: timeStr,
            takeText: takeText,
            footer: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Принято в',
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.takeGreen,
                  ),
                ),
                Text(
                  takenStr,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.takeGreen,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!taken && skipped) {
      return _orangeFrameShell(
        whiteBody: Padding(
          padding: const EdgeInsets.fromLTRB(14, 16, 14, 16),
          child: _infoRow(
            timeStr: timeStr,
            takeText: takeText,
            muted: true,
            footer: Text(
              'Приём пропущен',
              style: GoogleFonts.alegreyaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark.withValues(alpha: 0.5),
              ),
            ),
          ),
        ),
      );
    }

    return _orangeFrameShell(
      whiteBody: Padding(
        padding: const EdgeInsets.fromLTRB(14, 16, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: _pillLeadingIcon(),
                  ),
                  const SizedBox(width: 10),
                  Container(width: 1, color: AppColors.textDark.withValues(alpha: 0.35)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.alegreyaSans(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textDark,
                              letterSpacing: 0.2,
                            ),
                            children: [
                              TextSpan(text: '${medication.name.toUpperCase()} '),
                              if (medication.dosage.isNotEmpty)
                                TextSpan(
                                  text: medication.dosage,
                                  style: GoogleFonts.alegreyaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textDark,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          instruction,
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark,
                          ),
                        ),
                      ],
                    ),
>>>>>>> Stashed changes
                  ),
                  const SizedBox(width: 8),
                  Text(
                    timeStr,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
<<<<<<< Updated upstream
          ),
          if (!taken) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _actionBtn('Пропустить', AppColors.skipRed, () {}),
=======
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _actionBtn('Пропустить', _medBtnSkipBg, onSkip),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn('Принять сейчас', _medBtnTakeBg, onMarkTaken, fontSize: 11),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _actionBtn(
                    'Принять в выбранное время',
                    _medBtnTimeBg,
                    onMarkAtChosenTime,
                    fontSize: 10,
>>>>>>> Stashed changes
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionBtn('Принять сейчас', AppColors.takeGreen, onMarkTaken),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _actionBtn('В выбранное время', AppColors.takeYellow, () {}),
                  ),
                ],
              ),
            ),
          ],
<<<<<<< Updated upstream
        ],
=======
        ),
>>>>>>> Stashed changes
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, VoidCallback onTap) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.alegreyaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({
    required this.appointment,
    required this.onEdit,
    required this.onDelete,
  });

  final Appointment appointment;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final timeStr =
        '${appointment.time.hour.toString().padLeft(2, '0')}:${appointment.time.minute.toString().padLeft(2, '0')}';
    final meeting = appointment.meetingDate ?? appointment.date;
    final note = appointment.note;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.appointmentCardFrame,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: AppColors.appointmentCardFrame.withValues(alpha: 0.35),
            blurRadius: 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(5, 5, 5, 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 0, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline, color: AppColors.white, size: 24),
                ),
                IconButton(
                  onPressed: onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.white, size: 24),
                ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: SizedBox(
                          width: _kCalendarCardLeadingIconExtent,
                          height: _kCalendarCardLeadingIconExtent,
                          child: SvgPicture.asset(
                            'assets/icons/couch and clock.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(width: 1, color: AppColors.textDark.withValues(alpha: 0.35)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              appointment.title.toUpperCase(),
                              style: GoogleFonts.alegreyaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                                letterSpacing: 0.2,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'ДАТА ВСТРЕЧИ: ${_formatDate(meeting)}'.toUpperCase(),
                              style: GoogleFonts.alegreyaSans(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textDark,
                                letterSpacing: 0.15,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeStr,
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
                if (note != null && note.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    'ДОПОЛНИТЕЛЬНАЯ ИНФОРМАЦИЯ: $note'.toUpperCase(),
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                      height: 1.25,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
