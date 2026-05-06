import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/calendar_reminders.dart';
import '../models/calendar_entry.dart';
import '../services/calendar_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/time_picker_modal.dart';

<<<<<<< Updated upstream
const _frequencies = ['Ежедневно', 'Через день', 'Раз в неделю', 'По необходимости'];
=======
/// Сколько дней вперёд создавать записи при «Ежедневно».
const int _kDailySeriesDays = 365;

void _disposeTextControllerNextFrame(TextEditingController c) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    c.dispose();
  });
}
>>>>>>> Stashed changes

class AddMedicationScreen extends StatefulWidget {
  const AddMedicationScreen({
    super.key,
    this.medication,
    required this.date,
  });

  final Medication? medication;
  final DateTime date;

  @override
  State<AddMedicationScreen> createState() => _AddMedicationScreenState();
}

class _AddMedicationScreenState extends State<AddMedicationScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _dailyDosageController;
  late String _reminder;
  late List<MedicationDose> _schedule;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _nameController = TextEditingController(text: m?.name ?? '');
<<<<<<< Updated upstream
    _dosageController = TextEditingController(text: m?.dosage ?? '');
    _dailyDosageController = TextEditingController(text: m?.dailyDosage ?? '');
    _frequency = m?.frequency ?? _frequencies[0];
=======
    _dailyDosageController = TextEditingController(
      text: m?.dailyDosage ?? m?.dosage ?? '',
    );
    _reminder = m?.reminder ?? kCalendarReminderOptions[0];
>>>>>>> Stashed changes
    _schedule = m != null ? List.from(m.schedule) : [];
    if (_schedule.isEmpty) {
      _schedule.add(const MedicationDose(time: TimeOfDay(hour: 8, minute: 0), amount: '1 таблетка'));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _dailyDosageController.dispose();
    super.dispose();
  }

  Future<void> _addScheduleItem() async {
    final t = await showTimePickerModal(
      context,
      initial: _schedule.isNotEmpty ? _schedule.last.time : const TimeOfDay(hour: 8, minute: 0),
    );
    if (t != null && mounted) {
      setState(() => _schedule.add(MedicationDose(time: t, amount: '1 таблетка')));
    }
  }

  Future<void> _editScheduleItem(int index) async {
    final item = _schedule[index];
<<<<<<< Updated upstream
    final t = await showTimePickerModal(context, initial: item.time);
    if (t != null && mounted) {
      setState(() {
        _schedule[index] = MedicationDose(time: t, amount: item.amount);
      });
=======
    final amountCtrl = TextEditingController(text: item.amount);
    var time = item.time;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) {
          return AlertDialog(
            title: Text(
              'Время и количество',
              style: GoogleFonts.alegreyaSans(fontWeight: FontWeight.w700),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  onPressed: () async {
                    final picked = await showTimePickerModal(ctx, initial: time);
                    if (picked != null) setDlg(() => time = picked);
                  },
                  icon: SvgPicture.asset(
                    'assets/icons/add/clock.svg',
                    width: 20,
                    height: 20,
                  ),
                  label: Text(
                    '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}',
                    style: GoogleFonts.alegreyaSans(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amountCtrl,
                  decoration: _inputDecoration(hint: 'количество таблеток'),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                child: const Text('Сохранить'),
              ),
            ],
          );
        },
      ),
    );
    final amt = amountCtrl.text.trim();
    _disposeTextControllerNextFrame(amountCtrl);
    if (ok != true || !mounted) {
      return;
>>>>>>> Stashed changes
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final m = widget.medication;
<<<<<<< Updated upstream
    final entry = Medication(
      id: m?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      time: _schedule.first.time,
      name: name,
      dosage: _dosageController.text.trim(),
      frequency: _frequency,
      dailyDosage: _dailyDosageController.text.trim().isEmpty
          ? null
          : _dailyDosageController.text.trim(),
      schedule: _schedule,
    );
    await CalendarStorage.instance.save(entry);
=======
    if (m != null) {
      final nextSchedule = List<MedicationDose>.from(_schedule);
      final mergedTaken = List<DateTime?>.generate(
        nextSchedule.length,
        (i) => i < m.takenAtPerDose.length ? m.takenAtPerDose[i] : null,
      );
      final mergedSkipped = List<bool>.generate(
        nextSchedule.length,
        (i) => i < m.skippedPerDose.length && m.skippedPerDose[i],
      );
      final entry = Medication(
        id: m.id,
        date: DateTime(m.date.year, m.date.month, m.date.day),
        time: _schedule.first.time,
        name: name,
        dosage: dosage,
        frequency: m.frequency,
        dailyDosage: dailyDosage,
        reminder: _reminder,
        schedule: nextSchedule,
        seriesId: m.seriesId,
        takenAtPerDose: mergedTaken,
        skippedPerDose: mergedSkipped,
      );
      await CalendarStorage.instance.save(entry);
    } else {
      final baseMillis = DateTime.now().millisecondsSinceEpoch;
      final start = DateTime(widget.date.year, widget.date.month, widget.date.day);
      final seriesId = 'series_$baseMillis';
      final batch = <Medication>[];
      for (var i = 0; i < _kDailySeriesDays; i++) {
        final d = start.add(Duration(days: i));
        batch.add(
          Medication(
            id: 'med_${baseMillis}_$i',
            date: d,
            time: _schedule.first.time,
            name: name,
            dosage: dosage,
            frequency: 'Ежедневно',
            dailyDosage: dailyDosage,
            reminder: _reminder,
            schedule: List<MedicationDose>.from(_schedule),
            seriesId: seriesId,
          ),
        );
      }
      await CalendarStorage.instance.saveMany(batch);
    }
>>>>>>> Stashed changes
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Препарат сохранён'), behavior: SnackBarBehavior.floating),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      appBar: AppBar(
        backgroundColor: AppColors.headerPeach,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AppColors.textDark),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Добавить препарат',
          style: GoogleFonts.alegreyaSans(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _card(
              iconAsset: 'assets/icons/add/blister.svg',
              label: 'КАКОЕ ЛЕКАРСТВО ВЫ ХОТИТЕ ДОБАВИТЬ?',
              child: TextField(
                controller: _nameController,
                decoration: _inputDecoration(),
              ),
            ),
            const SizedBox(height: 16),
            _card(
<<<<<<< Updated upstream
              icon: Icons.medical_information_outlined,
              label: 'ДОЗИРОВКА (мг, мл)',
              child: TextField(
                controller: _dosageController,
                decoration: _inputDecoration(hint: '200мг'),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              icon: Icons.schedule_outlined,
              label: 'КАК ЧАСТО ВЫ ЕГО ПРИНИМАЕТЕ?',
=======
              iconAsset: 'assets/icons/add/bell.svg',
              label: 'КОГДА ВЫ ХОТИТЕ, ЧТОБЫ ВАМ НАПОМНИЛИ О ПРИЁМЕ?',
>>>>>>> Stashed changes
              child: DropdownButtonFormField<String>(
                value: _reminder,
                decoration: _inputDecoration(),
<<<<<<< Updated upstream
                items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
=======
                iconEnabledColor: AppColors.textDark,
                items: kCalendarReminderOptions
                    .map((r) => DropdownMenuItem(value: r, child: Text(r)))
                    .toList(),
                onChanged: (v) => setState(() => _reminder = v ?? _reminder),
>>>>>>> Stashed changes
              ),
            ),
            const SizedBox(height: 16),
            _card(
<<<<<<< Updated upstream
              icon: Icons.medical_services_outlined,
=======
              iconAsset: 'assets/icons/add/pills dose.svg',
>>>>>>> Stashed changes
              label: 'УСТАНОВИТЕ СУТОЧНУЮ ДОЗИРОВКУ',
              child: TextField(
                controller: _dailyDosageController,
                decoration: _inputDecoration(hint: 'мг, мл...'),
              ),
            ),
            const SizedBox(height: 16),
            _card(
<<<<<<< Updated upstream
              icon: Icons.notifications_outlined,
=======
              iconAsset: 'assets/icons/add/clock.svg',
>>>>>>> Stashed changes
              label: 'УСТАНОВИТЕ ВРЕМЯ ПРИЕМА И КОЛИЧЕСТВО ТАБЛЕТОК',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ..._schedule.asMap().entries.map((e) {
                    final item = e.value;
                    final i = e.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _editScheduleItem(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.orange),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Text(
                                item.amount,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const Spacer(),
                              if (_schedule.length > 1)
                                IconButton(
                                  onPressed: () => setState(() => _schedule.removeAt(i)),
                                  icon: const Icon(Icons.delete_outline, color: AppColors.orange),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: AppColors.orange,
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: _addScheduleItem,
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.add, color: AppColors.white),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _saveButton(),
          ],
        ),
      ),
    );
  }

  Widget _card({
    required String iconAsset,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SvgPicture.asset(
                iconAsset,
                width: 28,
                height: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  InputDecoration _inputDecoration({String? hint}) {
    return InputDecoration(
      hintText: hint,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.orange),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.orange),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _saveButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _save,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.orange,
          foregroundColor: AppColors.white,
          padding: const EdgeInsets.symmetric(vertical: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
        child: Text(
          'Сохранить',
          style: GoogleFonts.alegreyaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
