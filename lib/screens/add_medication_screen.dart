import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/calendar_entry.dart';
import '../services/calendar_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/time_picker_modal.dart';

const _frequencies = ['Ежедневно', 'Через день', 'Раз в неделю', 'По необходимости'];

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
  late String _frequency;
  late List<MedicationDose> _schedule;

  @override
  void initState() {
    super.initState();
    final m = widget.medication;
    _nameController = TextEditingController(text: m?.name ?? '');
    _dosageController = TextEditingController(text: m?.dosage ?? '');
    _dailyDosageController = TextEditingController(text: m?.dailyDosage ?? '');
    _frequency = m?.frequency ?? _frequencies[0];
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
    final t = await showTimePickerModal(context, initial: item.time);
    if (t != null && mounted) {
      setState(() {
        _schedule[index] = MedicationDose(time: t, amount: item.amount);
      });
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    final m = widget.medication;
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
              child: DropdownButtonFormField<String>(
                value: _frequency,
                decoration: _inputDecoration(),
                items: _frequencies.map((f) => DropdownMenuItem(value: f, child: Text(f))).toList(),
                onChanged: (v) => setState(() => _frequency = v ?? _frequency),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              icon: Icons.medical_services_outlined,
              label: 'УСТАНОВИТЕ СУТОЧНУЮ ДОЗИРОВКУ',
              child: TextField(
                controller: _dailyDosageController,
                decoration: _inputDecoration(hint: 'мг, мл...'),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              icon: Icons.notifications_outlined,
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
    required IconData icon,
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
              Icon(icon, color: AppColors.orange, size: 28),
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
