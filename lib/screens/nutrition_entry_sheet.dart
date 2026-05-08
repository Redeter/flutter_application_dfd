import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/state_entries.dart';
import '../services/plus_dashboard_unlock_service.dart';
import '../services/state_storage.dart';
import '../theme/app_colors.dart';

void showNutritionEntrySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _NutritionEntrySheet(),
  );
}

const _meals = ['ЗАВТРАК', 'ОБЕД', 'УЖИН'];
const _mealColors = [Color(0xFFFFF9E6), Color(0xFFE3F2FD), Color(0xFFE2DDF0)];

const _sensations = [
  'Голод',
  'Сытость',
  'Переедание',
  'Ограничение',
  'Тяжесть',
  'Отвращение',
];

const _emotionalConnection = [
  'Ел(а) из-за стресса',
  'Ел(а) автоматически',
  'Ел(а) с удовольствием',
  'Было сложно есть',
  'Не связано с эмоциями',
];

class _NutritionEntrySheet extends StatefulWidget {
  const _NutritionEntrySheet();

  @override
  State<_NutritionEntrySheet> createState() => _NutritionEntrySheetState();
}

class _NutritionEntrySheetState extends State<_NutritionEntrySheet> {
  int _mealIndex = 0;
  /// Отметки завтрак / обед / ужин по индексу `_mealIndex`.
  final List<bool> _mealMarked = [false, false, false];
  int _snackCount = 0;
  final _sensationsSel = <String>{};
  final _emotionalSel = <String>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.lightGreen,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(Icons.restaurant_rounded, color: Colors.green.shade700, size: 32),
                const SizedBox(width: 12),
                Text(
                  'ПИТАНИЕ',
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.green.shade700, size: 24),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _mealCard(),
                  const SizedBox(height: 20),
                  _sensationsCard(),
                  const SizedBox(height: 20),
                  _emotionalCard(),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.orangeHandle,
                        foregroundColor: AppColors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHandle() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: const BoxDecoration(
        color: AppColors.orangeHandle,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Center(
        child: Container(
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.white,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _mealCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Отметьте приемы пищи в течении дня:',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
            decoration: BoxDecoration(
              color: _mealColors[_mealIndex],
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.orangeHandle.withValues(alpha: 0.4)),
            ),
            child: Column(
              children: [
                Text(
                  _meals[_mealIndex],
                  textAlign: TextAlign.center,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      onPressed: _mealIndex > 0
                          ? () => setState(() => _mealIndex--)
                          : null,
                      icon: Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: _mealIndex > 0 ? AppColors.orangeHandle : AppColors.greyMuted,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => setState(() {
                          _mealMarked[_mealIndex] = !_mealMarked[_mealIndex];
                        }),
                        borderRadius: BorderRadius.circular(14),
                        child: Ink(
                          width: 70,
                          height: 70,
                          decoration: BoxDecoration(
                            color: AppColors.white.withValues(alpha: 0.92),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: _mealMarked[_mealIndex]
                                  ? AppColors.orangeHandle
                                  : AppColors.greyMuted.withValues(alpha: 0.65),
                              width: _mealMarked[_mealIndex] ? 2.5 : 1.5,
                            ),
                          ),
                          child: Center(
                            child: _mealMarked[_mealIndex]
                                ? SvgPicture.asset(
                                    'assets/icons/hand1.svg',
                                    width: 50,
                                    height: 50,
                                    fit: BoxFit.contain,
                                  )
                                : const SizedBox.shrink(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                      padding: EdgeInsets.zero,
                      onPressed: _mealIndex < _meals.length - 1
                          ? () => setState(() => _mealIndex++)
                          : null,
                      icon: Icon(
                        Icons.arrow_forward_ios_rounded,
                        color: _mealIndex < _meals.length - 1
                            ? AppColors.orangeHandle
                            : AppColors.greyMuted,
                        size: 22,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filled(
                onPressed: _snackCount > 0
                    ? () => setState(() => _snackCount--)
                    : null,
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.orangeHandle,
                  foregroundColor: AppColors.white,
                ),
                icon: const Icon(Icons.remove),
              ),
              const SizedBox(width: 20),
              Text(
                'ПЕРЕКУС x $_snackCount',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark,
                ),
              ),
              const SizedBox(width: 20),
              IconButton.filled(
                onPressed: () => setState(() => _snackCount++),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.orangeHandle,
                  foregroundColor: AppColors.white,
                ),
                icon: const Icon(Icons.add),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sensationsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Какие были ощущения, связанные с едой?',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _sensations.map((s) => _tagChip(s, _sensationsSel)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _emotionalCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Как еда была связана с эмоциями сегодня?',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _emotionalConnection
                .map((s) => _tagChip(s, _emotionalSel))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _tagChip(String label, Set<String> selected) {
    final sel = selected.contains(label);
    return GestureDetector(
      onTap: () {
        setState(() {
          if (sel) {
            selected.remove(label);
          } else {
            selected.add(label);
          }
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: sel ? AppColors.orangeHandle : AppColors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.orangeHandle, width: 2),
        ),
        child: Text(
          label,
          style: GoogleFonts.alegreyaSans(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: sel ? AppColors.white : AppColors.orangeHandle,
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final mealsSaved = <String>[];
    for (var i = 0; i < _meals.length; i++) {
      if (_mealMarked[i]) mealsSaved.add(_meals[i]);
    }
    final entry = NutritionEntry(
      createdAt: DateTime.now(),
      meals: mealsSaved,
      snackCount: _snackCount,
      sensations: _sensationsSel.toList(),
      emotionalConnection: _emotionalSel.toList(),
    );
    await StateStorage.instance.save(entry);
    await PlusDashboardUnlockService.instance.markUnlockedAfterPlusEntry();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные о питании сохранены'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
