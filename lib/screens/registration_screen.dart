import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../constants/privacy_copy.dart';
import '../models/foundation_score.dart';
import '../models/foundation_sphere.dart';
import '../models/user_profile.dart';
import '../neural/neural_insights_service.dart';
import '../services/auth_service.dart';
import '../services/foundation_service.dart';
import '../services/user_profile_service.dart';
import '../utils/email_validation.dart';
import '../widgets/foundation_sphere_checkboxes.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';

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
  final _emailController = TextEditingController();
  final _displayNameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _selectedConditions = <MentalCondition>{};
  FoundationSpherePriorities _spherePriorities =
      const FoundationSpherePriorities();
  bool _loading = false;

  Future<void> _register() async {
    final email = _emailController.text.trim();
    final displayName = _displayNameController.text.trim();
    final password = _passwordController.text;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    setState(() => _loading = true);
    try {
      try {
        await AuthService.instance.register(email: email, password: password);
      } on AuthEmailTakenException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message)),
        );
        return;
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_registerErrorRu(e))),
        );
        return;
      }
      await UserProfileService.instance.save(
        UserProfile(
          name: displayName,
          conditions: _selectedConditions.toList(),
          priorityFocus: PriorityStateFocus.mood,
          spherePriorities: _spherePriorities,
        ),
      );
      await FoundationService.instance.saveGoals(
        FoundationGoals(priorities: _spherePriorities),
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
    _emailController.dispose();
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
                controller: _emailController,
                style: AppTypography.formField,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                enableSuggestions: false,
                autofillHints: const [AutofillHints.email],
                cursorColor: Colors.black,
                decoration: _inputDecoration('Почта'),
                validator: validateEmailField,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _displayNameController,
                style: AppTypography.formField,
                textCapitalization: TextCapitalization.none,
                keyboardType: TextInputType.name,
                autocorrect: false,
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
                style: AppTypography.formField,
                textCapitalization: TextCapitalization.none,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
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
                style: AppTypography.formField,
                textCapitalization: TextCapitalization.none,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
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
                  side: AppCheckboxStyle.side,
                  activeColor: AppCheckboxStyle.activeColor,
                  checkColor: AppCheckboxStyle.checkColor,
                  title: Text(
                    condition.label,
                    style: AppTypography.checkboxTileTitle(),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ),
              const SizedBox(height: 8),
              FoundationSphereCheckboxes(
                priorities: _spherePriorities,
                onChanged: (next) => setState(() => _spherePriorities = next),
              ),
              const SizedBox(height: 14),
              Text(
                PrivacyCopy.registrationHint,
                style: AppTypography.fieldHelper,
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

  String _registerErrorRu(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'Этот адрес почты уже зарегистрирован';
      case 'invalid-email':
        return 'Некорректный адрес почты';
      case 'weak-password':
        return 'Пароль слишком слабый';
      case 'network-request-failed':
        return 'Нет сети. Проверьте подключение.';
      default:
        return 'Не удалось зарегистрироваться (${e.code})';
    }
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
