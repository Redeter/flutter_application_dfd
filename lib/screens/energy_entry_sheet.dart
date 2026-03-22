import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/state_entries.dart';
import '../services/state_storage.dart';
import '../theme/app_colors.dart';

void showEnergyEntrySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _EnergyEntrySheet(),
  );
}

const _characters = [
  'Устойчивая',
  'Рваная',
  'Вялая',
  'Гиперактивная',
  'Перегруженная',
  'Напряжённая',
];

const _factors = [
  'Работа / учёба',
  'Социальные контакты',
  'Эмоциональные переживания',
  'Физическая активность',
  'Сон',
  'Тревога',
  'Шум / свет',
  'Не знаю',
  'Быт',
];

class _EnergyEntrySheet extends StatefulWidget {
  const _EnergyEntrySheet();

  @override
  State<_EnergyEntrySheet> createState() => _EnergyEntrySheetState();
}

class _EnergyEntrySheetState extends State<_EnergyEntrySheet> {
  double _level = 9;
  String? _character;
  final _factorsSel = <String>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.lightYellow,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(Icons.battery_charging_full_rounded,
                    color: Colors.amber.shade800, size: 32),
                const SizedBox(width: 12),
                Text(
                  'ЭНЕРГИЯ',
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
                      color: Colors.amber.shade800, size: 24),
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
                  _levelCard(),
                  const SizedBox(height: 20),
                  _characterCard(),
                  const SizedBox(height: 20),
                  _factorsCard(),
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

  Widget _levelCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'ОТМЕТЬТЕ УРОВЕНЬ ВАШЕЙ ЭНЕРГИИ ЗА ДЕНЬ ПО ДАННОЙ ШКАЛЕ:',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: Text(
              _level.round().toString(),
              style: GoogleFonts.alegreyaSans(
                fontSize: 64,
                fontWeight: FontWeight.w800,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              activeTrackColor: Colors.transparent,
              inactiveTrackColor: Colors.transparent,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 18),
            ),
            child: Slider(
              value: _level,
              min: 1,
              max: 10,
              divisions: 9,
              thumbColor: AppColors.orangeHandle,
              onChanged: (v) => setState(() => _level = v),
            ),
          ),
          Container(
            height: 8,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(4),
              gradient: const LinearGradient(
                colors: [Color(0xFF5D4037), AppColors.lightYellow],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _characterCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'КАКОЙ ХАРАКТЕР У ВАШЕЙ ЭНЕРГИИ?',
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
            children: _characters.map((c) {
              final sel = _character == c;
              return GestureDetector(
                onTap: () => setState(() => _character = sel ? null : c),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.orangeHandle : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.orangeHandle, width: 2),
                  ),
                  child: Text(
                    c,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppColors.white : AppColors.orangeHandle,
                    ),
                  ),
                ),
              );
            }).toList(),
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
            color: Colors.amber.withValues(alpha: 0.2),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'КАКИЕ БЫЛИ ФАКТОРЫ, ПОВЛИЯВШИЕ НА УРОВЕНЬ ВАШЕЙ ЭНЕРГИИ?',
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
              final sel = _factorsSel.contains(f);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (sel) {
                      _factorsSel.remove(f);
                    } else {
                      _factorsSel.add(f);
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
                    f,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: sel ? AppColors.white : AppColors.orangeHandle,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final entry = EnergyEntry(
      createdAt: DateTime.now(),
      level: _level.round(),
      character: _character,
      factors: _factorsSel.toList(),
    );
    await StateStorage.instance.save(entry);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные об энергии сохранены'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
