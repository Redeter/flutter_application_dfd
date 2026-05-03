import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/note_item.dart';
import '../theme/app_colors.dart';
import '../theme/peach_app_bar.dart';
import '../widgets/cream_background_decor.dart';
import '../widgets/unified_horizontal_date_strip.dart';

/// Создание / редактирование заметки (макет справа).
class NoteEditScreen extends StatefulWidget {
  const NoteEditScreen({
    super.key,
    this.initialTitle,
    this.initialBody,
    this.initialTags,
    this.selectedDate,
    this.initialSticker,
    this.allowDelete = false,
  });

  final String? initialTitle;
  final String? initialBody;
  final String? initialTags;
  final DateTime? selectedDate;
  final NoteStickerKind? initialSticker;

  /// Редактирование существующей заметки — показать удаление.
  final bool allowDelete;

  @override
  State<NoteEditScreen> createState() => _NoteEditScreenState();
}

class _NoteEditScreenState extends State<NoteEditScreen> {
  late DateTime _selectedDay;
  late NoteStickerKind _selectedSticker;
  late final TextEditingController _tagsController;
  late final TextEditingController _titleController;
  late final TextEditingController _bodyController;

  static const _stickersOrder = NoteStickerKind.values;
  static const Color _stickerPreviewCircleFill = Color(0xFFF8C994);

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.selectedDate ?? DateTime.now();
    _selectedSticker = widget.initialSticker ?? NoteStickerKind.sun;
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
    final norm = DateTime(base.year, base.month, base.day);
    return List.generate(14, (i) => norm.add(Duration(days: i - 5)));
  }

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
    final tagsHintStyle = GoogleFonts.alegreyaSans(
      fontSize: 17,
      fontWeight: FontWeight.w500,
      color: AppColors.textDark.withValues(alpha: 0.38),
    );
    final tagsStyle = GoogleFonts.alegreyaSans(
      fontSize: 17,
      color: const Color(0xFF636366),
    );
    return Scaffold(
      backgroundColor: AppColors.creamBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CreamBackgroundDecor(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildDateStripSection(),
              Expanded(
                child: SafeArea(
                  top: false,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            _buildBackButton(context),
                            const Spacer(),
                            if (widget.allowDelete) ...[
                              _buildDeleteButton(context),
                              const SizedBox(width: 10),
                            ],
                            _buildSaveButton(context),
                          ],
                        ),
                        const SizedBox(height: 18),
                        _buildStickerPickerRow(),
                        const SizedBox(height: 22),
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
                          hint: 'Тэги',
                          minLines: 1,
                          maxLines: 1,
                          style: tagsStyle,
                          hintStyle: tagsHintStyle,
                        ),
                        const SizedBox(height: 14),
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
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDateStripSection() {
    final days = _stripDays;
    final topInset = MediaQuery.paddingOf(context).top;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.headerPeach,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      padding: EdgeInsets.only(
        top: topInset + 8,
        bottom: kPeachHeaderStripBottomPadding,
      ),
      child: UnifiedHorizontalDateStrip(
        days: days,
        selectedDay: _selectedDay,
        onDaySelected: (d) => setState(() => _selectedDay = d),
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
            border: Border.all(color: AppColors.orange, width: 2),
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
            color: AppColors.orange,
            size: 20,
          ),
        ),
      ),
    );
  }

  Widget _buildDeleteButton(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => _confirmDelete(context),
        borderRadius: BorderRadius.circular(14),
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.redAccent.withValues(alpha: 0.55), width: 1.4),
            color: AppColors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.delete_outline_rounded, color: Colors.redAccent.shade400, size: 22),
              const SizedBox(width: 6),
              Text(
                'Удалить',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: Colors.redAccent.shade400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (!context.mounted || confirmed != true) return;
    Navigator.pop(context, {'deleted': true});
  }

  Widget _buildSaveButton(BuildContext context) {
    return Material(
      color: AppColors.orange,
      borderRadius: BorderRadius.circular(24),
      elevation: 0,
      shadowColor: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.pop(context, {
            'title': _titleController.text,
            'body': _bodyController.text,
            'tags': _tagsController.text,
            'date': _selectedDay,
            'sticker': _selectedSticker,
          });
        },
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 13),
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

  Widget _stickerSvg(NoteStickerKind kind) {
    final svg = SvgPicture.asset(kind.assetPath, fit: BoxFit.contain);
    final s = kind.glyphVisualScale;
    if (s == 1.0) return svg;
    return Transform.scale(scale: s, alignment: Alignment.center, child: svg);
  }

  /// Большой стикер слева; справа компактная сетка 2×2.
  Widget _buildStickerPickerRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 132,
          height: 132,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _stickerPreviewCircleFill,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: ClipOval(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: _stickerSvg(_selectedSticker),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 6, left: 4, right: 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _stickerChip(_stickersOrder[0]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _stickerChip(_stickersOrder[1]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _stickerChip(_stickersOrder[2]),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: _stickerChip(_stickersOrder[3]),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stickerChip(NoteStickerKind kind) {
    final selected = kind == _selectedSticker;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => setState(() => _selectedSticker = kind),
        customBorder: const CircleBorder(),
        child: Ink(
          width: double.infinity,
          height: double.infinity,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.white : AppColors.peachBackground.withValues(alpha: 0.65),
            border: Border.all(
              color: selected ? AppColors.orange : AppColors.orange.withValues(alpha: 0.55),
              width: selected ? 2.5 : 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.orange.withValues(alpha: 0.18),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: _stickerSvg(kind),
          ),
        ),
      ),
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
    double borderRadius = 24,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(borderRadius),
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
