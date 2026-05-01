
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/state_entries.dart';
import '../services/state_storage.dart';
import '../theme/app_colors.dart';

void showEmotionsEntrySheet(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _EmotionsEntrySheet(),
  );
}

const _emotions = [
  ('Спокойствие', 'assets/icons/emotions/chill.png', [Color(0xFFE8E4E0), Color(0xFFFFD8B1)]),
  ('Радость', 'assets/icons/emotions/joy.png', [Color(0xFFFFE082), Color(0xFFFFAB6D)]),
  ('Отвращение', 'assets/icons/emotions/disgust.png', [Color(0xFF558B2F), Color(0xFFD4A574)]),
  ('Злость', 'assets/icons/emotions/anger.png', [Color(0xFFE53935), Color(0xFFFFAB6D)]),
  ('Тревога', 'assets/icons/emotions/anxiety.png', [Color(0xFFD4A574), Color(0xFFE8DCC8)]),
  ('Страх', 'assets/icons/emotions/fear.png', [Color(0xFF7E57C2), Color(0xFFFFAB9E)]),
  ('Грусть', 'assets/icons/emotions/sadness.png', [Color(0xFF42A5F5), Color(0xFFFFD8B1)]),
  ('Стыд', 'assets/icons/emotions/shame.png', [Color(0xFFF48FB1), Color(0xFFFFD8B1)]),
  ('Раздражение', 'assets/icons/emotions/irritation.png', [Color(0xFFC62828), Color(0xFFFFAB6D)]),
  ('Беспокойство', 'assets/icons/emotions/worry.png', [Color(0xFF66BB6A), Color(0xFFA5D6A7)]),
  ('Напряжение', 'assets/icons/emotions/voltage.png', [Color(0xFF424242), Color(0xFFBCAAA4)]),
  ('Вдохновение', 'assets/icons/emotions/inspiration.png', [Color(0xFFFFF59D), Color(0xFFFFD8B1)]),
];

class _EmotionsEntrySheet extends StatefulWidget {
  const _EmotionsEntrySheet();

  @override
  State<_EmotionsEntrySheet> createState() => _EmotionsEntrySheetState();
}

class _EmotionsEntrySheetState extends State<_EmotionsEntrySheet> {
  final _selected = <String>{};

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.lightPink,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          _buildHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Row(
              children: [
                Icon(Icons.face_retouching_natural_rounded,
                    color: Colors.redAccent.shade400, size: 32),
                const SizedBox(width: 12),
                Text(
                  'ЭМОЦИИ',
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
                      color: Colors.redAccent.shade400, size: 24),
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
                  const SizedBox(height: 16),
                  Text(
                    'Отметьте эмоции, которые сейчас испытываете:',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textDark.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.12),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: GridView.count(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      crossAxisCount: 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      childAspectRatio: 0.78,
                      children: _emotions.asMap().entries.map((e) {
                        final (label, iconPath, _) = e.value;
                        final selected = _selected.contains(label);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _selected.remove(label);
                              } else {
                                _selected.add(label);
                              }
                            });
                          },
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 120),
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              color: AppColors.white.withValues(alpha: 0.55),
                              border: selected
                                  ? Border.all(color: AppColors.orangeHandle, width: 4)
                                  : null,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  height: 68,
                                  width: double.infinity,
                                  child: Image.asset(
                                    iconPath,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
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

  Future<void> _save() async {
    final entry = EmotionsEntry(
      createdAt: DateTime.now(),
      emotions: _selected.toList(),
    );
    await StateStorage.instance.save(entry);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Эмоции сохранены'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}
