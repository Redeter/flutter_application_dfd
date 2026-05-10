import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/user_profile.dart';
import '../neural/neural_insights_service.dart';
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
  final _loginController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  static final RegExp _usernameRegExp = RegExp(r'^[a-zA-Z0-9._-]{3,32}$');
  final _selectedConditions = <MentalCondition>{};
  PriorityStateFocus _priorityFocus = PriorityStateFocus.mood;
  bool _loading = false;

  Future<void> _register() async {
    final login = _loginController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    setState(() => _loading = true);
    try {
      try {
        await AuthService.instance.register(username: login, password: password);
      } on AuthUsernameTakenException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      }
      await UserProfileService.instance.save(
        UserProfile(
          name: displayName,
          conditions: _selectedConditions.toList(),
          priorityFocus: _priorityFocus,
        ),
      );
      try {
        await NeuralInsightsService.instance.reloadForActiveUser();
      } catch (_) {}
      if (!mounted) return;
      widget.onCompleted();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _loginController.dispose();
    _displayNameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
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
        child: Form(
          key: _formKey,
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
              TextFormField(
                controller: _loginController,
                autocorrect: false,
                cursorColor: Colors.black,
                decoration: _inputDecoration('Логин'),
                validator: (value) {
                  final loginValue = (value ?? '').trim();
                  if (loginValue.isEmpty) return 'Введите логин';
                  if (!_usernameRegExp.hasMatch(loginValue)) {
                    return 'Логин: 3-32 символа, латиница/цифры/._-';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _displayNameController,
                cursorColor: Colors.black,
                maxLength: 200,
                buildCounter: (
                  context, {
                  required currentLength,
                  required isFocused,
                  maxLength,
                }) =>
                    null,
                decoration: _inputDecoration('Имя (как к вам обращаться)'),
                validator: (value) {
                  final name = (value ?? '').trim();
                  if (name.length > 200) return 'Не длиннее 200 символов';
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                cursorColor: Colors.black,
                decoration: _inputDecoration('Пароль'),
                validator: (value) {
                  final passwordValue = value ?? '';
                  if (passwordValue.isEmpty) return 'Введите пароль';
                  if (passwordValue.length < 8) {
                    return 'Пароль должен быть не короче 8 символов';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                cursorColor: Colors.black,
                decoration: _inputDecoration('Подтвердите пароль'),
                validator: (value) {
                  if ((value ?? '').isEmpty) return 'Подтвердите пароль';
                  if (value != _passwordController.text) {
                    return 'Пароли не совпадают';
                  }
                  return null;
                },
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
                  side: const BorderSide(color: Colors.black54),
                  activeColor: Colors.black,
                  checkColor: Colors.white,
                  title: Text(condition.label),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<PriorityStateFocus>(
                value: _priorityFocus,
                dropdownColor: AppColors.cream,
                iconEnabledColor: Colors.black54,
                decoration: _inputDecoration('Приоритет наблюдения'),
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
      ),
    );
  }

  InputDecoration _inputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      labelStyle: const TextStyle(color: Colors.black),
      floatingLabelStyle: const TextStyle(color: Colors.black),
      enabledBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black54),
      ),
      focusedBorder: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black, width: 1.5),
      ),
      border: const OutlineInputBorder(
        borderSide: BorderSide(color: Colors.black54),
      ),
    );
  }
}
