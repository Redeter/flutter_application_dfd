import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/state_entries.dart';
import '../services/plus_dashboard_unlock_service.dart';
import '../services/state_storage.dart';
import '../theme/app_colors.dart';
import '../widgets/asset_scale_slider.dart';

void showSleepEntrySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _SleepEntrySheet(),
  );
}

const _tags = [
  'Бессонница',
  'Крепкий сон',
  'Прерывистый сон',
  'Снились кошмары',
  'Средний сон',
  'Было тяжело вставать',
];

class _SleepEntrySheet extends StatefulWidget {
  const _SleepEntrySheet();

  @override
  State<_SleepEntrySheet> createState() => _SleepEntrySheetState();
}

class _SleepEntrySheetState extends State<_SleepEntrySheet> {
  TimeOfDay _bedTime = const TimeOfDay(hour: 21, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 8, minute: 0);
  double _quality = 9;
  final _selectedTags = <String>{};

  Future<void> _pickTime(BuildContext context, bool isBed) async {
    final initial = isBed ? _bedTime : _wakeTime;
    final t = await showTimePicker(
      context: context,
      initialTime: initial,
    );
    if (t != null && mounted) {
      setState(() {
        if (isBed) {
          _bedTime = t;
        } else {
          _wakeTime = t;
        }
      });
    }
  }

  String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.9,
      decoration: const BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(Icons.nightlight_round, color: Colors.blue.shade700, size: 32),
                const SizedBox(width: 12),
                Text(
                  'СОН',
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
                      color: Colors.blue.shade700, size: 24),
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
                  _timeCard(context),
                  const SizedBox(height: 20),
                  _qualityCard(),
                  const SizedBox(height: 20),
                  _tagsCard(),
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

  Widget _timeCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Во сколько вы легли спать вчера?',
            style: GoogleFonts.alegreyaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _pickTime(context, true),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.orangeHandle.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Text(
                    _format(_bedTime),
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Во сколько вы проснулись сегодня?',
            style: GoogleFonts.alegreyaSans(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: () => _pickTime(context, false),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.orangeHandle.withValues(alpha: 0.5)),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.access_time, color: Colors.blue.shade700),
                  const SizedBox(width: 12),
                  Text(
                    _format(_wakeTime),
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark,
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

  Widget _qualityCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Отметьте качество вашего сна по данной шкале:',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: Text(
              _quality.round().toString(),
              style: GoogleFonts.alegreyaSansSc(
                fontSize: 64,
                fontWeight: FontWeight.w400,
                color: AppColors.textDark,
              ),
            ),
          ),
          const SizedBox(height: 16),
          AssetScaleSlider(
            value: _quality,
            onChanged: (v) => setState(() => _quality = v),
            scaleAssetPath: 'assets/icons/sleep scale.svg',
          ),
        ],
      ),
    );
  }

  Widget _tagsCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Каким был ваш сон?',
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
            children: _tags.map((tag) {
              final selected = _selectedTags.contains(tag);
              return GestureDetector(
                onTap: () {
                  setState(() {
                    if (selected) {
                      _selectedTags.remove(tag);
                    } else {
                      _selectedTags.add(tag);
                    }
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: selected ? AppColors.orangeHandle : AppColors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.orangeHandle, width: 2),
                  ),
                  child: Text(
                    tag,
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
    final entry = SleepEntry(
      createdAt: DateTime.now(),
      bedTime: _bedTime,
      wakeTime: _wakeTime,
      quality: _quality.round(),
      tags: _selectedTags.toList(),
    );
    await StateStorage.instance.save(entry);
    await PlusDashboardUnlockService.instance.markUnlockedAfterPlusEntry();
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Данные о сне сохранены'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
