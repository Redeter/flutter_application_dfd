import 'dart:async';

import 'package:flutter/material.dart';

import '../neural/neural_insights_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import 'app_shell.dart';
import 'login_screen.dart';
import '../widgets/pin_lock_gate.dart';

class AuthGateScreen extends StatefulWidget {
  const AuthGateScreen({super.key});

  @override
  State<AuthGateScreen> createState() => _AuthGateScreenState();
}

class _AuthGateScreenState extends State<AuthGateScreen> {
  late final Future<bool> _autoLoginFuture = AuthService.instance.shouldAutoLogin();
  bool _scheduledNeuralReload = false;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _autoLoginFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        if (snapshot.data == true) {
          if (!_scheduledNeuralReload) {
            _scheduledNeuralReload = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              unawaited(NeuralInsightsService.instance.reloadForActiveUser());
              unawaited(
                NotificationService.instance.bootstrapRemindersForActiveSession(),
              );
            });
          }
          return const PinLockGate(child: AppShell());
        }

        return LoginScreen(
          onSuccess: () {
            unawaited(
              NotificationService.instance.bootstrapRemindersForActiveSession(),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (_) => const PinLockGate(child: AppShell()),
              ),
            );
          },
        );
      },
    );
  }
}
