import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';

class RegistrationScreen extends StatefulWidget {
  const RegistrationScreen({
    super.key,
    required this.onCompleted,
  });

  final VoidCallback onCompleted;

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _doctorController = TextEditingController();
  final _selectedConditions = <MentalCondition>{};
  PriorityStateFocus _priorityFocus = PriorityStateFocus.mood;
  bool _loading = false;

  Future<void> _register() async {
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirm = _confirmPasswordController.text;
    if (username.isEmpty || password.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите имя пользователя и пароль не короче 4 символов')),
      );
      return;
    }
    if (password != confirm) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пароли не совпадают')),
      );
      return;
    }
    setState(() => _loading = true);
    await AuthService.instance.register(username: username, password: password);
    await UserProfileService.instance.save(
      UserProfile(
        name: username,
        doctorName: _doctorController.text.trim(),
        conditions: _selectedConditions.toList(),
        priorityFocus: _priorityFocus,
      ),
    );
    if (!mounted) return;
    setState(() => _loading = false);
    widget.onCompleted();
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _doctorController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Регистрация'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Создайте профиль для персональной аналитики',
              style: GoogleFonts.alegreyaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _usernameController,
              decoration: const InputDecoration(
                labelText: 'Имя пользователя',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Пароль',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _confirmPasswordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: 'Подтвердите пароль',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _doctorController,
              decoration: const InputDecoration(
                labelText: 'Врач (если есть)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Диагноз (если есть)',
              style: GoogleFonts.alegreyaSans(fontWeight: FontWeight.w700),
            ),
            ...MentalCondition.values.map(
              (condition) => CheckboxListTile(
                value: _selectedConditions.contains(condition),
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedConditions.add(condition);
                    } else {
                      _selectedConditions.remove(condition);
                    }
                  });
                },
                title: Text(condition.label),
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<PriorityStateFocus>(
              value: _priorityFocus,
              decoration: const InputDecoration(
                labelText: 'Приоритет наблюдения',
                border: OutlineInputBorder(),
              ),
              items: PriorityStateFocus.values
                  .map(
                    (f) => DropdownMenuItem(
                      value: f,
                      child: Text(f.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() => _priorityFocus = value);
                }
              },
            ),
            const SizedBox(height: 14),
            FilledButton(
              onPressed: _loading ? null : _register,
              style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
              child: _loading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Зарегистрироваться'),
            ),
          ],
        ),
      ),
    );
  }
}
