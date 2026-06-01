import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase/firebase_bootstrap.dart';
import 'firebase_options.dart';
import 'services/auth_service.dart';
import 'services/notification_service.dart';
import 'services/storage_migration_service.dart';
import 'screens/auth_gate_screen.dart';
import 'screens/calendar_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/state_categories_sheet.dart';
import 'screens/statistics_screen.dart';
import 'theme/app_colors.dart';
import 'widgets/app_bottom_nav.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _BootstrapApp());
}

void unawaited(Future<void> f) {}

/// Быстрый первый кадр: тяжёлая инициализация не блокирует белый splash Android.
class _BootstrapApp extends StatelessWidget {
  const _BootstrapApp();

  static final Future<void> _ready = _initializeApp();

  static Future<void> _initializeApp() async {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    await FirebaseBootstrap.init();
    await AuthService.instance.enforceRememberPolicyOnColdStart();
    await SharedPreferences.getInstance();
    await StorageMigrationService.instance.ensureMigrated();
    unawaited(_preloadFonts());
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_bootstrapNotifications());
    });
  }

  static Future<void> _preloadFonts() async {
    try {
      await GoogleFonts.pendingFonts([
        GoogleFonts.alegreyaSansSc(),
        GoogleFonts.alegreyaSansScTextTheme(ThemeData.light().textTheme),
        GoogleFonts.alegreyaSans(fontWeight: FontWeight.w800),
        GoogleFonts.alegreyaSans(fontSize: 15, height: 1.45),
      ]).timeout(const Duration(seconds: 10));
    } catch (_) {
      // Без интернета используем системный шрифт — приложение должно стартовать.
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _ready,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            home: Scaffold(
              backgroundColor: AppColors.cream,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        'Не удалось запустить приложение',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${snapshot.error}',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }

        if (snapshot.connectionState != ConnectionState.done) {
          return MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: ThemeData(
              scaffoldBackgroundColor: AppColors.cream,
              colorScheme: ColorScheme.fromSeed(seedColor: AppColors.orange),
            ),
            home: const Scaffold(
              body: Center(
                child: CircularProgressIndicator(color: AppColors.orange),
              ),
            ),
          );
        }

        return const MyApp();
      },
    );
  }
}

Future<void> _bootstrapNotifications() async {
  await NotificationService.instance.init();
  await NotificationService.instance.rescheduleCalendarNotifications();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Raise',
      theme: ThemeData(
        fontFamily: GoogleFonts.alegreyaSansSc().fontFamily,
        textTheme: GoogleFonts.alegreyaSansScTextTheme(
          ThemeData.light().textTheme,
        ),
        scaffoldBackgroundColor: AppColors.cream,
        colorScheme: ThemeData.light().colorScheme.copyWith(
          primary: Colors.black,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFE0E0E0),
          onPrimaryContainer: Colors.black,
          secondary: const Color(0xFF424242),
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE8E8E8),
          onSecondaryContainer: Colors.black87,
          tertiary: const Color(0xFF616161),
          onTertiary: Colors.white,
          tertiaryContainer: const Color(0xFFEEEEEE),
          onTertiaryContainer: Colors.black87,
          surfaceTint: Colors.transparent,
        ),
        textSelectionTheme: const TextSelectionThemeData(
          cursorColor: Colors.black,
          selectionHandleColor: Colors.black,
          selectionColor: Color(0x33000000),
        ),
      ),
      home: const AuthGateScreen(),
    );
  }
}

class MainScreen extends StatelessWidget {
  const MainScreen({super.key});

  void _pushTab(BuildContext context, BottomNavTab tab) {
    final screen = switch (tab) {
      BottomNavTab.statistics => const StatisticsScreen(),
      BottomNavTab.notes => const NotesScreen(),
      BottomNavTab.calendar => const CalendarScreen(),
      BottomNavTab.articles => const GoalsScreen(),
    };
    Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (context) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: Stack(
                children: [
                  _buildTopBackground(),
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildProfileButton(),
                        const SizedBox(height: 24),
                        _buildBigCard(),
                        const SizedBox(height: 24),
                        _buildBigCard(),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            AppBottomNavBar(
              activeTab: null,
              onTabSelected: (tab) => _pushTab(context, tab),
              onCenterTap: () => showStateCategoriesSheet(context),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBackground() {
    return Align(
      alignment: Alignment.topCenter,
      child: Container(
        height: 380,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.orange.withValues(alpha: 0.35),
              AppColors.peachBackground.withValues(alpha: 0.65),
            ],
          ),
        ),
        child: ClipPath(
          clipper: _SoftWaveClipper(),
          child: Container(color: Colors.transparent),
        ),
      ),
    );
  }

  Widget _buildProfileButton() {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.orange, width: 4),
        ),
        child: Center(
          child: Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: AppColors.orange,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.cream,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(height: 3),
                Container(
                  width: 16,
                  height: 8,
                  decoration: BoxDecoration(
                    color: AppColors.cream,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBigCard() {
    return Container(
      height: 170,
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(24),
      ),
    );
  }
}

class _SoftWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    path.lineTo(0, size.height * 0.75);
    path.quadraticBezierTo(
      size.width * 0.25,
      size.height * 0.85,
      size.width * 0.5,
      size.height * 0.75,
    );
    path.quadraticBezierTo(
      size.width * 0.8,
      size.height * 0.65,
      size.width,
      size.height * 0.78,
    );
    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
