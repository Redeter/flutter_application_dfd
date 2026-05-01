import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

/// Создание / редактирование заметки (макет справа).
class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({
    super.key,
    this.initialTitle,
    this.initialBody,
    this.initialTags,
    this.selectedDate,
  });

  final String? initialTitle;
  final String? initialBody;
  final String? initialTags;
  final DateTime? selectedDate;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late DateTime _selectedDay;
  late final TextEditingController _tagsController;
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  static const _weekdaysShort = ['ПН', 'ВТ', 'СР', 'ЧТ', 'ПТ', 'СБ', 'ВС'];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate ?? DateTime.now();
    _tagsController = TextEditingController(text: widget.initialTags ?? '');
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _bodyController = TextEditingController(text: widget.initialBody ?? '');
  }

  @override
  void dispose() {
    _tagsController.dispose();
    _titleController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  List<DateTime> get _stripDays {
    final base = DateTime.now();
    return List.generate(
      18,
      (i) => DateTime(base.year, base.month, base.day).add(Duration(days: i - 5)),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final titleHintStyle = GoogleFonts.alegreyaSans(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.textDark.withValues(alpha: 0.4),
    );
    final bodyHintStyle = GoogleFonts.alegreyaSans(
      fontSize: 18,
      color: AppColors.textDark.withValues(alpha: 0.42),
    );
    return Scaffold(
      backgroundColor: AppColors.peachBackground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 8),
            _buildDateStrip(),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildBackButton(context),
                  const Spacer(),
                  _buildSaveButton(context),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildMediaRow(),
                    const SizedBox(height: 16),
                    _roundedField(
                      controller: _titleController,
                      hint: 'Заголовок...',
                      minLines: 1,
                      maxLines: 2,
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textDark,
                      ),
                      hintStyle: titleHintStyle,
                    ),
                    const SizedBox(height: 12),
                    _roundedField(
                      controller: _tagsController,
                      hint: '#теги (можно не заполнять)',
                      minLines: 1,
                      maxLines: 1,
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 17,
                        color: const Color(0xFF636366),
                      ),
                      hintStyle: GoogleFonts.alegreyaSans(
                        fontSize: 17,
                        color: AppColors.textDark.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _roundedField(
                      controller: _bodyController,
                      hint: 'Текст заметки...',
                      minLines: 12,
                      maxLines: 24,
                      alignTop: true,
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 18,
                        height: 1.45,
                        color: AppColors.textDark,
                      ),
                      hintStyle: bodyHintStyle,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateStrip() {
    final days = _stripDays;
    return SizedBox(
      height: 88,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final d = days[index];
          final today = DateTime.now();
          final isToday = _isSameDay(d, today);
          final selected = _isSameDay(d, _selectedDay);

          return GestureDetector(
            onTap: () => setState(() => _selectedDay = d),
            child: isToday
                ? _todayChip(d, selected)
                : _dayCircle(d, selected),
          );
        },
      ),
    );
  }

  Widget _dayCircle(DateTime d, bool selected) {
    final wd = _weekdaysShort[d.weekday - 1];
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          wd,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textDark.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.white,
            border: Border.all(
              color: selected ? AppColors.orange : AppColors.white,
              width: selected ? 3 : 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Center(
            child: Text(
              '${d.day}',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: AppColors.textDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _todayChip(DateTime d, bool selected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: selected ? AppColors.orange : AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.orange,
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'СЕГОДНЯ',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: selected ? AppColors.white : AppColors.orange,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '${d.day}',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: selected ? AppColors.white : AppColors.textDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => Navigator.pop(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE8E8ED), width: 1.4),
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Color(0xFF8E8E93),
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context) {
    return Material(
      color: const Color(0xFF111111),
      borderRadius: BorderRadius.circular(28),
      child: InkWell(
        onTap: () {
          Navigator.pop(context, {
            'title': _titleController.text,
            'body': _bodyController.text,
            'tags': _tagsController.text,
            'date': _selectedDay,
          });
        },
        borderRadius: BorderRadius.circular(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          child: Text(
            'Сохранить',
            style: GoogleFonts.alegreyaSans(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMediaRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Container(
          width: 70,
          height: 70,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: const Color(0xFFD1D1D6),
            border: Border.all(color: AppColors.white, width: 2),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: List.generate(
              4,
              (_) => Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFD1D1D6),
                  border: Border.all(
                    color: AppColors.white.withValues(alpha: 0.9),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _roundedField({
    required TextEditingController controller,
    required String hint,
    required int minLines,
    required int maxLines,
    required TextStyle style,
    required TextStyle hintStyle,
    bool alignTop = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE8E8ED), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        minLines: minLines,
        maxLines: maxLines,
        textAlignVertical: alignTop ? TextAlignVertical.top : TextAlignVertical.center,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: hintStyle,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        ),
        style: style,
      ),
    );
  }
}
