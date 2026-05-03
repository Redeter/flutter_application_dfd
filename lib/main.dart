import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'neural/neural_insights_service.dart';
import 'services/notification_service.dart';
import 'screens/app_shell.dart';
import 'screens/calendar_screen.dart';
import 'screens/goals_screen.dart';
import 'screens/notes_screen.dart';
import 'screens/state_categories_sheet.dart';
import 'screens/statistics_screen.dart';
import 'theme/app_colors.dart';
import 'widgets/app_bottom_nav.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SharedPreferences.getInstance();
  unawaited(NeuralInsightsService.instance.init());
  unawaited(NotificationService.instance.init());
  unawaited(NotificationService.instance.rescheduleCalendarNotifications());
  runApp(const MyApp());
}

void unawaited(Future<void> f) {}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Helper App',
      theme: ThemeData(
        fontFamily: GoogleFonts.alegreyaSansSc().fontFamily,
        textTheme: GoogleFonts.alegreyaSansScTextTheme(
          ThemeData.light().textTheme,
        ),
        scaffoldBackgroundColor: AppColors.cream,
      ),
      home: const AppShell(),
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
