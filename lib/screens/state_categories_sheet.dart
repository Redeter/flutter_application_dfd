import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';
import 'energy_entry_sheet.dart';
import 'emotions_entry_sheet.dart';
import 'mood_entry_sheet.dart';
import 'nutrition_entry_sheet.dart';
import 'sleep_entry_sheet.dart';

/// Выбор категории: настроение, эмоции, сон, питание, энергия.
void showStateCategoriesSheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _StateCategoriesSheet(),
  );
}

class _StateCategoriesSheet extends StatelessWidget {
  const _StateCategoriesSheet();

  static const _items = [
    (
      label: 'Настроение',
      color: AppColors.moodCategoryBackground,
      iconColor: AppColors.moodAccent,
      icon: Icons.sentiment_satisfied_alt_rounded,
    ),
    (
      label: 'Эмоции',
      color: AppColors.lightPink,
      iconColor: Colors.redAccent,
      icon: Icons.face_retouching_natural_rounded,
    ),
    (
      label: 'Сон',
      color: AppColors.lightBlue,
      iconColor: Colors.blue,
      icon: Icons.nightlight_round,
    ),
    (
      label: 'Питание',
      color: AppColors.lightGreen,
      iconColor: Colors.green,
      icon: Icons.restaurant_rounded,
    ),
    (
      label: 'Энергия',
      color: AppColors.lightYellow,
      iconColor: Colors.amber,
      icon: Icons.battery_charging_full_rounded,
    ),
  ];

  void _openSheet(BuildContext context, int index) {
    switch (index) {
      case 0:
        showMoodEntrySheet(context);
        break;
      case 1:
        showEmotionsEntrySheet(context);
        break;
      case 2:
        showSleepEntrySheet(context);
        break;
      case 3:
        showNutritionEntrySheet(context);
        break;
      case 4:
        showEnergyEntrySheet(context);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHandle(),
            const SizedBox(height: 20),
            ...List.generate(_items.length, (i) {
              final item = _items[i];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                child: _CategoryTile(
                  label: item.label,
                  backgroundColor: item.color,
                  iconColor: item.iconColor,
                  icon: item.icon,
                  onTap: () => _openSheet(context, i),
                ),
              );
            }),
            const SizedBox(height: 24),
          ],
        ),
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
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.backgroundColor,
    required this.iconColor,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final Color backgroundColor;
  final Color iconColor;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: iconColor.withValues(alpha: 0.4),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  label,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 18,
                color: iconColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
