import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/calendar_entry.dart';
import '../services/calendar_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/laconic_tap.dart';
import '../widgets/time_picker_modal.dart';

const _frequencies = ['Ежедневно', 'Через день', 'Раз в неделю', 'По необходимости'];

/// Сколько дней вперёд создавать записи при «Ежедневно».
const int _kDailySeriesDays = 365;

void _disposeTextControllerNextFrame(TextEditingController c) {
  WidgetsBinding.instance.addPostFrameCallback((_) {
    c.dispose();
  });
}

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
  late final TextEditingController _dailyDosageController;
  late String _frequency;
  late List<MedicationDose> _schedule;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _nameController = TextEditingController(text: m?.name ?? '');
    _dailyDosageController = TextEditingController(
      text: m?.dailyDosage ?? m?.dosage ?? '',
    );
    _frequency = m?.frequency ?? _frequencies[0];
    _schedule = m != null ? List.from(m.schedule) : [];
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dailyDosageController.dispose();
    super.dispose();
  }

  Future<void> _pickAmountThenAdd(TimeOfDay time) async {
    final ctrl = TextEditingController(text: '1 таблетка');
    final amount = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Количество',
          style: GoogleFonts.alegreyaSans(fontWeight: FontWeight.w700),
        ),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: _inputDecoration(hint: 'например 1/2 таблетки'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
    _disposeTextControllerNextFrame(ctrl);
    if (!mounted || amount == null || amount.isEmpty) return;
    setState(() => _schedule.add(MedicationDose(time: time, amount: amount)));
  }

  Future<void> _addScheduleItem() async {
    final t = await showTimePickerModal(
      context,
      initial: _schedule.isNotEmpty ? _schedule.last.time : const TimeOfDay(hour: 8, minute: 0),
    );
    if (t != null && mounted) await _pickAmountThenAdd(t);
  }

  Future<void> _editScheduleItem(int index) async {
    final item = _schedule[index];
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
                  icon: const Icon(Icons.access_time, color: AppColors.orange),
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
    }
    setState(() {
      _schedule[index] = MedicationDose(
        time: time,
        amount: amt.isEmpty ? item.amount : amt,
      );
    });
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    if (_schedule.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Добавьте хотя бы одно время приёма и количество (кнопка +).'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final daily = _dailyDosageController.text.trim();
    final dosage = daily.isEmpty ? '—' : daily;
    final dailyDosage = daily.isEmpty ? null : daily;

    final m = widget.medication;
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
        frequency: _frequency,
        dailyDosage: dailyDosage,
        schedule: nextSchedule,
        seriesId: m.seriesId,
        takenAtPerDose: mergedTaken,
        skippedPerDose: mergedSkipped,
      );
      await CalendarStorage.instance.save(entry);
    } else {
      final baseMillis = DateTime.now().millisecondsSinceEpoch;
      final start = DateTime(widget.date.year, widget.date.month, widget.date.day);

      if (_frequency == 'Ежедневно') {
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
              frequency: _frequency,
              dailyDosage: dailyDosage,
              schedule: List<MedicationDose>.from(_schedule),
              seriesId: seriesId,
            ),
          );
        }
        await CalendarStorage.instance.saveMany(batch);
      } else {
        await CalendarStorage.instance.save(
          Medication(
            id: baseMillis.toString(),
            date: start,
            time: _schedule.first.time,
            name: name,
            dosage: dosage,
            frequency: _frequency,
            dailyDosage: dailyDosage,
            schedule: List<MedicationDose>.from(_schedule),
            seriesId: null,
          ),
        );
      }
    }
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
              icon: Icons.medication_outlined,
              label: 'КАКОЕ ЛЕКАРСТВО ВЫ ХОТИТЕ ДОБАВИТЬ?',
              child: TextField(
                controller: _nameController,
                decoration: _inputDecoration(),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              icon: Icons.access_time,
              label: 'КАК ЧАСТО ВЫ ЕГО ПРИНИМАЕТЕ?',
              child: DropdownButtonFormField<String>(
                value: _frequency,
                decoration: _inputDecoration(),
                iconEnabledColor: AppColors.textDark,
                items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              icon: Icons.medication,
              label: 'УСТАНОВИТЕ СУТОЧНУЮ ДОЗИРОВКУ',
              child: TextField(
                controller: _dailyDosageController,
                decoration: _inputDecoration(hint: 'мг, мл, капли…'),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              icon: Icons.notifications_active_outlined,
              label: 'УСТАНОВИТЕ ВРЕМЯ ПРИЕМА И КОЛИЧЕСТВО ТАБЛЕТОК',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_schedule.isEmpty)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        'Нажмите «+», чтобы добавить время приёма и количество таблеток.',
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 13,
                          color: AppColors.textDark.withValues(alpha: 0.65),
                        ),
                      ),
                    ),
                  ..._schedule.asMap().entries.map((e) {
                    final item = e.value;
                    final i = e.key;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: InkWell(
                        onTap: () => _editScheduleItem(i),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            border: Border.all(color: AppColors.orange, width: 2.5),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Text(
                                '${item.time.hour.toString().padLeft(2, '0')}:${item.time.minute.toString().padLeft(2, '0')}',
                                style: GoogleFonts.alegreyaSans(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textDark,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  item.amount.toUpperCase(),
                                  style: GoogleFonts.alegreyaSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textDark,
                                  ),
                                ),
                              ),
                              if (_schedule.isNotEmpty)
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
                    child: LaconicTap(
                      onTap: _addScheduleItem,
                      child: Material(
                        color: AppColors.orange,
                        shape: const CircleBorder(),
                        child: InkWell(
                          onTap: _addScheduleItem,
                          customBorder: const CircleBorder(),
                          child: const Padding(
                            padding: EdgeInsets.all(12),
                            child: Icon(Icons.add, color: AppColors.white, size: 28),
                          ),
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
    required IconData icon,
    required String label,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.65)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: AppColors.orange, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.2,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
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
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.orange, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    );
  }

  Widget _saveButton() {
    return LaconicTap(
      onTap: _save,
      child: SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.orange,
            foregroundColor: AppColors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          ),
          child: Text(
            'Сохранить',
            style: GoogleFonts.alegreyaSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
