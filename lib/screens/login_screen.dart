import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../neural/neural_insights_service.dart';
import '../services/auth_service.dart';
import '../utils/email_validation.dart';
import 'registration_screen.dart';
import '../theme/app_typography.dart';
import '../theme/app_colors.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({
    super.key,
    required this.onSuccess,
  });

  final VoidCallback onSuccess;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _loading = false;
  bool _rememberMe = true;

  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final isValid = _formKey.currentState?.validate() ?? false;
    if (!isValid) return;
    setState(() => _loading = true);
    try {
      final ok = await AuthService.instance.login(
        email: email,
        password: password,
        rememberSession: _rememberMe,
      );
      if (!mounted) return;
      setState(() => _loading = false);
      if (ok) {
        await NeuralInsightsService.instance.reloadForActiveUser();
        widget.onSuccess();
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверная почта или пароль')),
      );
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_authErrorRu(e))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ошибка входа. Проверьте интернет.')),
      );
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SvgPicture.asset(
                    'assets/icons/welcome_icon.svg',
                    height: 132,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Raise',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  const SizedBox(height: 18),
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
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    style: AppTypography.formField,
                    textCapitalization: TextCapitalization.none,
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    cursorColor: Colors.black,
                    decoration: _inputDecoration('Пароль'),
                    validator: (value) {
                      if ((value ?? '').isEmpty) return 'Введите пароль';
                      return null;
                    },
                  ),
                  CheckboxListTile(
                    value: _rememberMe,
                    onChanged: _loading
                        ? null
                        : (value) {
                            setState(() => _rememberMe = value ?? false);
                          },
                    contentPadding: EdgeInsets.zero,
                    side: const BorderSide(color: Colors.black54),
                    activeColor: Colors.black,
                    checkColor: Colors.white,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: const Text(
                      'Запомнить меня',
                      style: TextStyle(color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 14),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.orange,
                    ),
                    child: _loading
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Войти'),
                  ),
                  const SizedBox(height: 10),
                  OutlinedButton(
                    onPressed: _loading
                        ? null
                        : () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => RegistrationScreen(
                                  onCompleted: () {
                                    Navigator.pop(context);
                                    widget.onSuccess();
                                  },
                                ),
                              ),
                            );
                          },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.black,
                      side: const BorderSide(color: Colors.black54),
                    ),
                    child: const Text('Зарегистрироваться'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String _authErrorRu(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'Некорректный адрес почты';
      case 'network-request-failed':
        return 'Нет сети. Проверьте подключение к интернету.';
      case 'too-many-requests':
        return 'Слишком много попыток. Подождите и попробуйте снова.';
      default:
        return 'Не удалось войти (${e.code})';
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
