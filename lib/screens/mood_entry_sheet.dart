import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/state_entries.dart';
import '../services/state_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/asset_scale_slider.dart';

void showMoodEntrySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _MoodEntrySheet(),
  );
}

const _factors = [
  'Дела по дому',
  'Сон',
  'Стресс',
  'Работа/учеба',
  'Социальные контакты',
  'Спорт',
  'Отдых',
  'Погода',
  'Не знаю',
];

class _MoodEntrySheet extends StatefulWidget {
  const _MoodEntrySheet();

  @override
  State<_MoodEntrySheet> createState() => _MoodEntrySheetState();
}

class _MoodEntrySheetState extends State<_MoodEntrySheet> {
  double _value = 9;
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.lavender,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(Icons.sentiment_satisfied_alt_rounded,
                    color: AppColors.purple, size: 32),
                const SizedBox(width: 12),
                Text(
                  'НАСТРОЕНИЕ',
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
                      color: AppColors.purple, size: 24),
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
                  _timeBadge(),
                  const SizedBox(height: 20),
                  _scaleCard(),
                  const SizedBox(height: 20),
                  _factorsCard(),
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

  Widget _timeBadge() {
    final now = DateTime.now();
    final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          t,
          style: GoogleFonts.alegreyaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textDark,
          ),
        ),
      ),
    );
  }

  Widget _scaleCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ОТМЕТЬТЕ УРОВЕНЬ НАСТРОЕНИЯ, КОТОРОЕ СЕЙЧАС ИСПЫТЫВАЕТЕ ПО ДАННОЙ ШКАЛЕ:',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _value.round().toString(),
              style: GoogleFonts.alegreyaSansSc(
                fontSize: 64,
                fontWeight: FontWeight.w400,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AssetScaleSlider(
            value: _value,
            onChanged: (v) => setState(() => _value = v),
            scaleAssetPath: 'assets/icons/mood scale.svg',
          ),
        ],
      ),
    );
  }

  Widget _factorsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppColors.purple.withValues(alpha: 0.12),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ЧТО МОГЛО ПОВЛИЯТЬ НА ВАШЕ НАСТРОЕНИЕ?',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: _factors.map((f) {
              final selected = _selected.contains(f);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selected.remove(f);
                    } else {
                      _selected.add(f);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.orangeHandle : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.orangeHandle,
                      width: 2,
                    ),
                  ),
                  child: Text(
                    f,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: selected ? AppColors.white : AppColors.orangeHandle,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
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
    );
  }

  Future<void> _save() async {
    final entry = MoodEntry(
      createdAt: DateTime.now(),
      value: _value.round(),
      factors: _selected.toList(),
    );
    await StateStorage.instance.save(entry);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Настроение сохранено'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
