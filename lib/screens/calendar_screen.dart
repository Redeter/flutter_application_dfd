import 'package:flutter/material.dart';
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
              child: const Icon(
                Icons.medication_outlined,
                color: AppColors.white,
                size: 32,
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

class _MedicationCard extends StatelessWidget {
  const _MedicationCard({
    required this.medication,
    required this.onEdit,
    required this.onDelete,
    required this.onMarkTaken,
  });

  final Medication medication;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onMarkTaken;

  @override
  Widget build(BuildContext context) {
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
                  ),
                ),
              ],
            ),
          ),
          if (!taken) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: _actionBtn('Пропустить', AppColors.skipRed, () {}),
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
        ],
      ),
    );
  }

  Widget _actionBtn(String label, Color bg, VoidCallback onTap) {
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
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
                Icon(Icons.event_available_rounded, color: AppColors.orange, size: 40),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.title.toUpperCase(),
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textDark,
                        ),
                      ),
                      if (appointment.meetingDate != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Дата встречи: ${_formatDate(appointment.meetingDate!)}',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textDark.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                      if (appointment.note != null && appointment.note!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          'Дополнительная информация: ${appointment.note}',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 12,
                            color: AppColors.textDark.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Text(
                  timeStr,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
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
