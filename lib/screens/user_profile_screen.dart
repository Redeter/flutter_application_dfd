import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/laconic_tap.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _nameController = TextEditingController();
  final _selected = <MentalCondition>{};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await UserProfileService.instance.load();
    if (!mounted) return;
    setState(() {
      _nameController.text = profile.name;
      _selected
        ..clear()
        ..addAll(profile.conditions);
      _loading = false;
    });
  }

  Future<void> _save() async {
    await UserProfileService.instance.save(
      UserProfile(
        name: _nameController.text.trim(),
        conditions: _selected.toList(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль сохранен')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Профиль пользователя',
          style: GoogleFonts.alegreyaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Настройте профиль под себя. Поле с состояниями можно оставить пустым.',
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 14,
                      color: AppColors.textDark.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Имя (опционально)',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Особенности состояния (опционально)',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...MentalCondition.values.map((c) {
                          final selected = _selected.contains(c);
                          return CheckboxListTile(
                            value: selected,
                            activeColor: AppColors.orange,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.label),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(c);
                                } else {
                                  _selected.remove(c);
                                }
                              });
                            },
                          );
                        }),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => setState(_selected.clear),
                          child: const Text('Оставить без заболевания'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LaconicTap(
                    onTap: _save,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
