import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../services/auth_service.dart';
import '../services/pin_lock_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../widgets/pin_keypad.dart';
import 'auth_gate_screen.dart';

enum PinLockFlow {
  unlock,
  create,
  change,
  verifyToDisable,
}

class PinLockScreen extends StatefulWidget {
  const PinLockScreen({
    super.key,
    required this.flow,
    required this.onSuccess,
    this.onCancel,
  });

  final PinLockFlow flow;
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;

  @override
  State<PinLockScreen> createState() => _PinLockScreenState();
}

class _PinLockScreenState extends State<PinLockScreen> {
  final _service = PinLockService.instance;
  final _buffer = StringBuffer();

  _PinStep _step = _PinStep.enter;
  String? _firstPin;
  String? _oldPin;

  String? _error;
  bool _shake = false;
  bool _busy = false;
  DateTime? _lockoutUntil;
  Timer? _lockoutTimer;

  @override
  void initState() {
    super.initState();
    _initLockout();
    if (widget.flow == PinLockFlow.create) {
      _step = _PinStep.enter;
    } else if (widget.flow == PinLockFlow.change) {
      _step = _PinStep.enterOld;
    }
  }

  @override
  void dispose() {
    _lockoutTimer?.cancel();
    super.dispose();
  }

  Future<void> _initLockout() async {
    final until = await _service.lockoutUntil();
    if (!mounted) return;
    setState(() => _lockoutUntil = until);
    _scheduleLockoutTick(until);
  }

  void _scheduleLockoutTick(DateTime? until) {
    _lockoutTimer?.cancel();
    if (until == null) return;
    _lockoutTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      final current = await _service.lockoutUntil();
      setState(() => _lockoutUntil = current);
      if (current == null) _lockoutTimer?.cancel();
    });
  }

  bool get _inputEnabled => !_busy && _lockoutUntil == null;

  String get _title {
    return switch (widget.flow) {
      PinLockFlow.unlock => 'Введите PIN-код',
      PinLockFlow.create => switch (_step) {
          _PinStep.enter => 'Придумайте PIN-код',
          _ => 'Повторите PIN-код',
        },
      PinLockFlow.change => switch (_step) {
          _PinStep.enterOld => 'Текущий PIN-код',
          _PinStep.enter => 'Новый PIN-код',
          _ => 'Повторите новый PIN',
        },
      PinLockFlow.verifyToDisable => 'Введите PIN для отключения',
    };
  }

  String? get _subtitle {
    if (_lockoutUntil != null) {
      final left = _lockoutUntil!.difference(DateTime.now()).inSeconds;
      return 'Слишком много попыток. Подождите ${left.clamp(0, 999)} сек.';
    }
    if (_error != null) return _error;
    return null;
  }

  Future<void> _onDigit(String digit) async {
    if (!_inputEnabled) return;
    if (_buffer.length >= PinLockService.pinLength) return;

    setState(() {
      _error = null;
      _shake = false;
      _buffer.write(digit);
    });

    if (_buffer.length < PinLockService.pinLength) return;
    await _submitPin(_buffer.toString());
  }

  void _onBackspace() {
    if (!_inputEnabled) return;
    if (_buffer.isEmpty) return;
    setState(() {
      _error = null;
      _shake = false;
      _buffer.clear();
    });
  }

  Future<void> _submitPin(String pin) async {
    setState(() => _busy = true);
    try {
      switch (widget.flow) {
        case PinLockFlow.unlock:
          await _handleUnlock(pin);
        case PinLockFlow.create:
          await _handleCreate(pin);
        case PinLockFlow.change:
          await _handleChange(pin);
        case PinLockFlow.verifyToDisable:
          await _handleVerifyToDisable(pin);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleUnlock(String pin) async {
    final ok = await _service.verifyPin(pin);
    if (!mounted) return;
    if (ok) {
      widget.onSuccess();
      return;
    }
    await _failAttempt('Неверный PIN-код');
  }

  Future<void> _handleCreate(String pin) async {
    if (_step == _PinStep.enter) {
      setState(() {
        _firstPin = pin;
        _buffer.clear();
        _step = _PinStep.confirm;
      });
      return;
    }

    if (pin != _firstPin) {
      setState(() {
        _firstPin = null;
        _step = _PinStep.enter;
      });
      await _failAttempt('PIN-коды не совпали. Попробуйте снова');
      return;
    }

    await _service.setPin(pin);
    if (!mounted) return;
    widget.onSuccess();
  }

  Future<void> _handleChange(String pin) async {
    if (_step == _PinStep.enterOld) {
      final ok = await _service.matchesPin(pin);
      if (!mounted) return;
      if (!ok) {
        await _failAttempt('Неверный PIN-код');
        return;
      }
      _oldPin = pin;
      _service.lockSession();
      setState(() {
        _buffer.clear();
        _step = _PinStep.enter;
        _error = null;
      });
      return;
    }

    if (_step == _PinStep.enter) {
      setState(() {
        _firstPin = pin;
        _buffer.clear();
        _step = _PinStep.confirm;
      });
      return;
    }

    if (pin != _firstPin) {
      setState(() {
        _firstPin = null;
        _step = _PinStep.enter;
      });
      await _failAttempt('PIN-коды не совпали. Попробуйте снова');
      return;
    }

    try {
      await _service.changePin(oldPin: _oldPin!, newPin: pin);
      if (!mounted) return;
      widget.onSuccess();
    } catch (_) {
      await _failAttempt('Не удалось сменить PIN');
    }
  }

  Future<void> _handleVerifyToDisable(String pin) async {
    try {
      await _service.disablePin(pin);
      if (!mounted) return;
      widget.onSuccess();
    } catch (_) {
      await _failAttempt('Неверный PIN-код');
    }
  }

  Future<void> _failAttempt(String message) async {
    final until = await _service.lockoutUntil();
    if (!mounted) return;
    setState(() {
      _buffer.clear();
      _error = message;
      _shake = true;
      _lockoutUntil = until;
    });
    _scheduleLockoutTick(until);
    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (mounted) setState(() => _shake = false);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('PIN-код останется для этого аккаунта на устройстве.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dialogPrimary,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    await AuthService.instance.logout();
    await _service.onLogout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const AuthGateScreen()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Column(
                children: [
                  SvgPicture.asset(
                    'assets/icons/welcome_icon.svg',
                    height: 88,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _title,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textDark,
                    ),
                  ),
                  if (_subtitle != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _subtitle!,
                      textAlign: TextAlign.center,
                      style: AppTypography.fieldHelper.copyWith(
                        color: _error != null || _lockoutUntil != null
                            ? const Color(0xFFB71C1C)
                            : AppColors.textDark.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                  const SizedBox(height: 28),
                  PinDotsIndicator(
                    length: PinLockService.pinLength,
                    filled: _buffer.length,
                    shake: _shake,
                  ),
                  const SizedBox(height: 28),
                  PinKeypad(
                    enabled: _inputEnabled,
                    onDigit: _onDigit,
                    onBackspace: _onBackspace,
                  ),
                  const SizedBox(height: 16),
                  if (widget.onCancel != null)
                    TextButton(
                      onPressed: _busy ? null : widget.onCancel,
                      child: const Text('Отмена'),
                    ),
                  if (widget.flow == PinLockFlow.unlock)
                    TextButton(
                      onPressed: _busy ? null : _logout,
                      child: const Text('Выйти из аккаунта'),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

enum _PinStep {
  enterOld,
  enter,
  confirm,
}
