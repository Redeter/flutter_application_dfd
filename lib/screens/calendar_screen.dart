import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/calendar_entry.dart';
import '../services/calendar_storage.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/peach_app_bar.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/cream_background_decor.dart';
import '../widgets/unified_horizontal_date_strip.dart';
import '../widgets/delete_confirm_dialog.dart';
import '../widgets/time_picker_modal.dart';
import 'add_appointment_screen.dart';
import 'add_medication_screen.dart';
import 'calendar_full_screen.dart';
import 'goals_screen.dart';
import 'notes_screen.dart';
import 'state_categories_sheet.dart';
import 'statistics_screen.dart';
import 'user_profile_screen.dart';

const _months = [
  'ЯНВАРЯ', 'ФЕВРАЛЯ', 'МАРТА', 'АПРЕЛЯ', 'МАЯ', 'ИЮНЯ',
  'ИЮЛЯ', 'АВГУСТА', 'СЕНТЯБРЯ', 'ОКТЯБРЯ', 'НОЯБРЯ', 'ДЕКАБРЯ',
];

String _formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';
const double _kCalendarCardLeadingIconExtent = 44;

const _kMedCardHeaderIconConstraints = BoxConstraints(minWidth: 32, minHeight: 32);

/// Компактная цветная полоска с удалением и редактированием.
Widget _medicationCardHeaderBar({
  required VoidCallback onDelete,
  required VoidCallback onEdit,
  Color iconColor = AppColors.white,
  Color barColor = AppColors.appointmentCardFrame,
  BorderRadius borderRadius = const BorderRadius.vertical(top: Radius.circular(16)),
}) {
  return Container(
    padding: const EdgeInsets.fromLTRB(4, 0, 0, 0),
    decoration: BoxDecoration(
      color: barColor,
      borderRadius: borderRadius,
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        IconButton(
          onPressed: onDelete,
          padding: EdgeInsets.zero,
          constraints: _kMedCardHeaderIconConstraints,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.delete_outline, color: iconColor, size: 20),
        ),
        IconButton(
          onPressed: onEdit,
          padding: EdgeInsets.zero,
          constraints: _kMedCardHeaderIconConstraints,
          visualDensity: VisualDensity.compact,
          icon: Icon(Icons.edit_outlined, color: iconColor, size: 20),
        ),
      ],
    ),
  );
}



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

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key, this.embeddedInShell = false});

  final bool embeddedInShell;

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _selectedDate = DateTime.now();
  List<CalendarEntry> _entries = [];
  Set<DateTime> _appointmentMarkedDays = const <DateTime>{};

  @override
  void initState() {
    super.initState();
    _loadEntries();
  }

  DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> _loadEntries() async {
    final day = _dayOnly(_selectedDate);
    final list = await CalendarStorage.instance.loadForDate(day);
    final all = await CalendarStorage.instance.loadAll();
    final marked = all
        .whereType<Appointment>()
        .map((a) => DateTime(a.date.year, a.date.month, a.date.day))
        .toSet();
    if (!mounted) return;
    if (_dayOnly(_selectedDate) != day) return;
    setState(() {
      _entries = list;
      _appointmentMarkedDays = marked;
    });
  }

  /// Сначала обновляем список на экране, затем пересчитываем пуши в фоне — карточка меняется сразу.
  Future<void> _reloadAfterCalendarMutation() async {
    await _loadEntries();
    unawaited(NotificationService.instance.rescheduleCalendarNotifications());
  }

  void _onDateChanged(DateTime d) {
    if (d.year == _selectedDate.year &&
        d.month == _selectedDate.month &&
        d.day == _selectedDate.day) {
      return;
    }
    setState(() => _selectedDate = d);
    Future<void>.delayed(const Duration(milliseconds: 50), () {
      if (mounted) _loadEntries();
    });
  }

  void _openFullCalendar() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CalendarFullScreen(
          selectedDate: _selectedDate,
          appointmentDays: _appointmentMarkedDays,
          onDateSelected: _onDateChanged,
          onOpenDay: (_) => _loadEntries(),
          onAddAppointment: (d) async {
            Navigator.pop(context);
            _onDateChanged(d);
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => AddAppointmentScreen(date: d),
              ),
            );
            await _reloadAfterCalendarMutation();
          },
        ),
      ),
    ).then((_) => _loadEntries());
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
    await _reloadAfterCalendarMutation();
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
    await _reloadAfterCalendarMutation();
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
      switch (e) {
        case Medication m:
          await CalendarStorage.instance.deleteMedication(m);
        case Appointment a:
          await CalendarStorage.instance.delete(a.id);
      }
      await _reloadAfterCalendarMutation();
    }
  }

  Future<void> _markDoseTaken(Medication m, int doseIndex) async {
    if (m.schedule.isEmpty) return;
    final list = List<DateTime?>.from(m.takenAtPerDose);
    while (list.length < m.schedule.length) {
      list.add(null);
    }
    if (doseIndex < 0 || doseIndex >= m.schedule.length) return;
    list[doseIndex] = DateTime.now();
    final skipped = List<bool>.from(m.skippedPerDose);
    while (skipped.length < m.schedule.length) {
      skipped.add(false);
    }
    skipped[doseIndex] = false;
    await CalendarStorage.instance.save(
      m.copyWith(takenAtPerDose: list, skippedPerDose: skipped),
    );
    await _reloadAfterCalendarMutation();
  }

  Future<void> _skipMedication(Medication m, int doseIndex) async {
    if (m.schedule.isEmpty || doseIndex < 0 || doseIndex >= m.schedule.length) return;
    if (doseIndex < m.takenAtPerDose.length && m.takenAtPerDose[doseIndex] != null) return;
    final skipped = List<bool>.from(m.skippedPerDose);
    while (skipped.length < m.schedule.length) {
      skipped.add(false);
    }
    skipped[doseIndex] = true;
    await CalendarStorage.instance.save(m.copyWith(skippedPerDose: skipped));
    await _reloadAfterCalendarMutation();
  }

  Future<void> _markDoseTakenAtChosenTime(Medication m, int doseIndex) async {
    if (m.schedule.isEmpty || doseIndex < 0 || doseIndex >= m.schedule.length) return;
    final scheduled = m.schedule[doseIndex].time;
    final picked = await showTimePickerModal(context, initial: scheduled);
    if (picked == null || !mounted) return;
    final day = DateTime(m.date.year, m.date.month, m.date.day);
    final when = DateTime(day.year, day.month, day.day, picked.hour, picked.minute);
    final list = List<DateTime?>.from(m.takenAtPerDose);
    while (list.length < m.schedule.length) {
      list.add(null);
    }
    list[doseIndex] = when;
    final skipped = List<bool>.from(m.skippedPerDose);
    while (skipped.length < m.schedule.length) {
      skipped.add(false);
    }
    skipped[doseIndex] = false;
    await CalendarStorage.instance.save(
      m.copyWith(takenAtPerDose: list, skippedPerDose: skipped),
    );
    await _reloadAfterCalendarMutation();
  }

  void _onNavTab(BottomNavTab tab) {
    if (widget.embeddedInShell) return;
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
          MaterialPageRoute(builder: (_) => const GoalsScreen()),
        );
    }
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(),
                Padding(
                  padding: const EdgeInsets.only(
                    bottom: kPeachHeaderStripBottomPadding,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDateStripInner(),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: kPeachAppBarHorizontalInset,
                        ),
                        child: _buildCalendarLegend(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              bottom: false,
              child: Stack(
                fit: StackFit.expand,
                clipBehavior: Clip.hardEdge,
                children: [
                  Positioned.fill(
                    child: const CreamBackgroundDecor(),
                  ),
                  Positioned.fill(
                    child: _buildRefreshableBody(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Material(
          elevation: 6,
          shadowColor: AppColors.orange.withValues(alpha: 0.45),
          color: Colors.transparent,
          clipBehavior: Clip.antiAlias,
          borderRadius: BorderRadius.circular(20),
          child: InkWell(
            borderRadius: BorderRadius.circular(20),
            onTap: () => _openAddMedication(),
            child: SizedBox(
              width: 64,
              height: 64,
              child: SvgPicture.asset(
                'assets/icons/new pill button.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: widget.embeddedInShell
          ? null
          : AppBottomNavBar(
              activeTab: BottomNavTab.calendar,
              onTabSelected: _onNavTab,
              onCenterTap: () => showStateCategoriesSheet(context),
            ),
    );
  }

  Widget _buildHeader() {
    return SizedBox(
      height: kPeachAppBarToolbarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: kPeachAppBarHorizontalInset,
        ),
        child: Row(
          children: [
            IconButton(
              style: peachAppBarCircleIconButtonStyle(),
              tooltip: 'Личный кабинет',
              onPressed: () async {
                await Navigator.push<void>(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const UserProfileScreen(),
                  ),
                );
                if (!mounted) return;
                await _loadEntries();
              },
              icon: const Icon(Icons.person_outline_rounded),
            ),
            Expanded(
              child: Center(
                child: Text(
                  _formatDate(_selectedDate).toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: peachAppBarTitleStyle(),
                ),
              ),
            ),
            IconButton(
              style: peachAppBarCircleIconButtonStyle(),
              onPressed: _openFullCalendar,
              icon: const Icon(Icons.calendar_month_rounded),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateStripInner() {
    final today = DateTime.now();
    final base = DateTime(today.year, today.month, today.day);
    final days = List.generate(14, (i) => base.add(Duration(days: i - 5)));
    return UnifiedHorizontalDateStrip(
      days: days,
      selectedDay: _selectedDate,
      onDaySelected: _onDateChanged,
      markedDays: _appointmentMarkedDays,
    );
  }

  Widget _buildCalendarLegend() {
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: const BoxDecoration(
            color: AppColors.orange,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          'Есть посещение врача',
          style: GoogleFonts.alegreyaSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark.withValues(alpha: 0.78),
          ),
        ),
      ],
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

  Widget _buildRefreshableBody() {
    return RefreshIndicator(
      color: AppColors.orange,
      onRefresh: _loadEntries,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (_entries.isEmpty) {
            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: _buildEmpty(),
              ),
            );
          }
          return _buildList();
        },
      ),
    );
  }

  Widget _buildList() {
    final rows = _sortedDayRows(_entries);
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
      itemCount: rows.length,
      itemBuilder: (context, i) {
        final row = rows[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 14),
          child: switch (row) {
            _MedDoseRow r => _MedicationDoseCard(
                medication: r.med,
                doseIndex: r.doseIndex,
                onEdit: () => _openAddMedication(m: r.med),
                onDelete: () => _deleteEntry(r.med),
                onMarkTaken: () => _markDoseTaken(r.med, r.doseIndex),
                onSkip: () => _skipMedication(r.med, r.doseIndex),
                onMarkAtChosenTime: () => _markDoseTakenAtChosenTime(r.med, r.doseIndex),
              ),
            _AppDayRow r => _AppointmentCard(
                appointment: r.appointment,
                onEdit: () => _openAddAppointment(a: r.appointment),
                onDelete: () => _deleteEntry(r.appointment),
              ),
          },
        );
      },
    );
  }
}

class _MedicationDoseCard extends StatelessWidget {
  const _MedicationDoseCard({
    required this.medication,
    required this.doseIndex,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkTaken,
    required this.onSkip,
    required this.onMarkAtChosenTime,
  });

  final Medication medication;
  final int doseIndex;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkTaken;
  final VoidCallback onSkip;
  final VoidCallback onMarkAtChosenTime;

  @override
  Widget build(BuildContext context) {
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

    final decoration = BoxDecoration(
      color: AppColors.appointmentCardFrame,
      borderRadius: BorderRadius.circular(24),
      boxShadow: [
        BoxShadow(
          color: AppColors.appointmentCardFrame.withValues(alpha: 0.22),
          blurRadius: 12,
          offset: const Offset(0, 4),
        ),
      ],
    );

    final skippedDecoration = BoxDecoration(
      color: AppColors.greyMuted.withValues(alpha: 0.35),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.greyMuted, width: 2),
    );

    if (taken && takenAt != null) {
      final takenStr =
          '${takenAt.hour.toString().padLeft(2, '0')}:${takenAt.minute.toString().padLeft(2, '0')}';
      return Container(
        decoration: decoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 0, 0, 2),
              child: _medicationCardHeaderBar(
                onDelete: onDelete,
                onEdit: onEdit,
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
              decoration: BoxDecoration(
                color: AppColors.white,
                borderRadius: BorderRadius.circular(18),
              ),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: SizedBox(
                        width: _kCalendarCardLeadingIconExtent,
                        height: _kCalendarCardLeadingIconExtent,
                        child: SvgPicture.asset('assets/icons/pill.svg', fit: BoxFit.contain),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(width: 1, color: AppColors.textDark.withValues(alpha: 0.35)),
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
                                    style: GoogleFonts.alegreyaSans(fontSize: 15, fontWeight: FontWeight.w800, color: AppColors.textDark),
                                    children: [
                                      TextSpan(text: '${medication.name.toUpperCase()} '),
                                      const WidgetSpan(child: SizedBox(width: 4)),
                                      TextSpan(
                                        text: medication.dosage,
                                        style: GoogleFonts.alegreyaSans(fontSize: 14, fontWeight: FontWeight.w500, color: AppColors.textDark),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                timeStr,
                                style: GoogleFonts.alegreyaSans(fontSize: 18, fontWeight: FontWeight.w600, color: AppColors.textDark.withValues(alpha: 0.45)),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            takeText.toUpperCase(),
                            style: GoogleFonts.alegreyaSans(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.3, color: AppColors.textDark),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Принято в', style: GoogleFonts.alegreyaSans(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.takeGreen)),
                              Text(takenStr, style: GoogleFonts.alegreyaSans(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.takeGreen)),
                            ],
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

    if (!taken && skipped) {
      return Container(
        decoration: skippedDecoration,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(2, 2, 2, 0),
              child: _medicationCardHeaderBar(
                onDelete: onDelete,
                onEdit: onEdit,
                iconColor: AppColors.textDark,
                barColor: AppColors.greyMuted.withValues(alpha: 0.35),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 14),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Opacity(
                        opacity: 0.55,
                        child: SizedBox(
                          width: _kCalendarCardLeadingIconExtent,
                          height: _kCalendarCardLeadingIconExtent,
                          child: SvgPicture.asset(
                            'assets/icons/pill.svg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Container(width: 1, color: AppColors.textDark.withValues(alpha: 0.2)),
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
                                      color: AppColors.textDark.withValues(alpha: 0.55),
                                    ),
                                    children: [
                                      TextSpan(text: '${medication.name.toUpperCase()} '),
                                      TextSpan(
                                        text: medication.dosage,
                                        style: GoogleFonts.alegreyaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: AppColors.textDark.withValues(alpha: 0.45),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              Text(
                                timeStr,
                                style: GoogleFonts.alegreyaSans(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textDark.withValues(alpha: 0.35),
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
                              color: AppColors.textDark.withValues(alpha: 0.45),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Приём пропущен',
                            style: GoogleFonts.alegreyaSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textDark.withValues(alpha: 0.5),
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

    return Container(
      decoration: decoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _medicationCardHeaderBar(
            onDelete: onDelete,
            onEdit: onEdit,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _kCalendarCardLeadingIconExtent,
                      height: _kCalendarCardLeadingIconExtent,
                      child: SvgPicture.asset('assets/icons/pill.svg', fit: BoxFit.contain),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          RichText(
                            text: TextSpan(
                              style: GoogleFonts.alegreyaSans(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textDark,
                              ),
                              children: [
                                TextSpan(text: '${medication.name.toUpperCase()} '),
                                const WidgetSpan(child: SizedBox(width: 4)),
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
                          const SizedBox(height: 4),
                          Text(
                            'Принять $takeText',
                            style: GoogleFonts.alegreyaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark.withValues(alpha: 0.8)),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      timeStr,
                      style: GoogleFonts.alegreyaSans(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: _actionBtn('Пропустить', AppColors.skipRed, onSkip)),
                    const SizedBox(width: 8),
                    Expanded(child: _actionBtn('Принять сейчас', AppColors.takeGreen, onMarkTaken)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _actionBtn(
                        'Принять в выбранное время',
                        AppColors.orange.withValues(alpha: 0.22),
                        onMarkAtChosenTime,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, VoidCallback onTap, {double fontSize = 12}) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 3,
            overflow: TextOverflow.fade,
            softWrap: true,
            style: GoogleFonts.alegreyaSans(
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
              height: 1.15,
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

    return Container(
      decoration: BoxDecoration(
        color: AppColors.appointmentCardFrame,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.appointmentCardFrame.withValues(alpha: 0.22),
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
              color: AppColors.appointmentCardFrame,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(21)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, color: AppColors.white),
                ),
                IconButton(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, color: AppColors.white),
                ),
              ],
            ),
          ),
          Container(
            margin: const EdgeInsets.fromLTRB(6, 0, 6, 6),
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: _kCalendarCardLeadingIconExtent,
                  height: _kCalendarCardLeadingIconExtent,
                  child: SvgPicture.asset('assets/icons/couch and clock.svg', fit: BoxFit.contain),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.title.toUpperCase(),
                        style: GoogleFonts.alegreyaSans(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.textDark),
                      ),
                      if (appointment.meetingDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Дата встречи: ${_formatDate(appointment.meetingDate!)}',
                          style: GoogleFonts.alegreyaSans(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textDark.withValues(alpha: 0.8)),
                        ),
                      ],
                      if (appointment.note != null && appointment.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Дополнительная информация: ${appointment.note}',
                          style: GoogleFonts.alegreyaSans(fontSize: 12, color: AppColors.textDark.withValues(alpha: 0.6)),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  timeStr,
                  style: GoogleFonts.alegreyaSans(fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textDark),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
