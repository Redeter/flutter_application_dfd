import 'package:flutter/material.dart';

import '../screens/pin_lock_screen.dart';
import '../services/pin_lock_service.dart';

/// Показывает экран PIN один раз после входа в приложение.
class PinLockGate extends StatefulWidget {
  const PinLockGate({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<PinLockGate> createState() => _PinLockGateState();
}

class _PinLockGateState extends State<PinLockGate> {
  bool _checking = true;
  bool _pinEnabled = false;
  bool _unlocked = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final enabled = await PinLockService.instance.isEnabled();
    if (!mounted) return;
    setState(() {
      _pinEnabled = enabled;
      _unlocked = !enabled || PinLockService.instance.isSessionUnlocked;
      _checking = false;
    });
  }

  void _onUnlocked() {
    PinLockService.instance.unlockSession();
    setState(() => _unlocked = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_checking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_pinEnabled && !_unlocked) {
      return PinLockScreen(
        flow: PinLockFlow.unlock,
        onSuccess: _onUnlocked,
      );
    }

    return widget.child;
  }
}
