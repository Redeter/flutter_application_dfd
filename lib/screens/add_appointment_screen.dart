import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../models/calendar_entry.dart';
import '../services/calendar_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/time_picker_modal.dart';

const _reminders = ['За 15 мин', 'За 1 час', 'За день', 'Не напоминать'];

class AddAppointmentScreen extends StatefulWidget {
  const AddAppointmentScreen({
    super.key,
    this.appointment,
    required this.date,
  });

  final Appointment? appointment;
  final DateTime date;

  @override
  State<AddAppointmentScreen> createState() => _AddAppointmentScreenState();
}

class _AddAppointmentScreenState extends State<AddAppointmentScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late TimeOfDay _time;
  late String _reminder;

  @override
  void initState() {
    super.initState();
    final a = widget.appointment;
    _titleController = TextEditingController(text: a?.title ?? '');
    _noteController = TextEditingController(text: a?.note ?? '');
    _time = a?.time ?? const TimeOfDay(hour: 15, minute: 0);
    _reminder = a?.reminder ?? _reminders[0];
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final t = await showTimePickerModal(context, initial: _time);
    if (t != null && mounted) setState(() => _time = t);
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final a = widget.appointment;
    final entry = Appointment(
      id: a?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      date: widget.date,
      time: _time,
      title: title,
      meetingDate: widget.date,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
      reminder: _reminder,
    );
    await CalendarStorage.instance.save(entry);
    if (mounted) {
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Запись сохранена'), behavior: SnackBarBehavior.floating),
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
          'Добавить запись',
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
              iconAsset: 'assets/icons/add/Aa.svg',
              iconSize: 19,
              label: 'КАКОЕ НАЗВАНИЕ ВАШЕЙ ЗАПИСИ?',
              child: TextField(
                controller: _titleController,
                decoration: _inputDecoration(hint: 'Например: Приём врача'),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              iconAsset: 'assets/icons/add/clock.svg',
              label: 'УСТАНОВИТЕ ВРЕМЯ ВАШЕЙ ЗАПИСИ',
              child: InkWell(
                onTap: _pickTime,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.orange),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                       SvgPicture.asset(
                        'assets/icons/add/clock.svg',
                        width: 20,
                        height: 20,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              iconAsset: 'assets/icons/add/bell.svg',
              label: 'КОГДА ВЫ ХОТИТЕ, ЧТОБЫ ВАМ НАПОМНИЛИ О ЗАПИСИ?',
              child: DropdownButtonFormField<String>(
                value: _reminder,
                decoration: _inputDecoration(),
                items: _reminders.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                onChanged: (v) => setState(() => _reminder = v ?? _reminder),
              ),
            ),
            const SizedBox(height: 16),
            _card(
              iconAsset: 'assets/icons/add/note_page.svg',
              iconSize: 30,
              label: 'ДОБАВЬТЕ ДОПОЛНИТЕЛЬНУЮ ИНФОРМАЦИЮ О ЗАПИСИ',
              child: TextField(
                controller: _noteController,
                maxLines: 4,
                decoration: _inputDecoration(hint: 'Текст заметки...'),
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
    double iconSize = 28,
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
                width: iconSize,
                height: iconSize,
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
