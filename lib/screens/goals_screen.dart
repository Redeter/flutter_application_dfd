import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/aggregated_data.dart';
import '../services/goals_dashboard_reload_hub.dart';
import '../services/insights_service.dart';
import '../theme/app_colors.dart';
import '../theme/peach_app_bar.dart';
import '../widgets/app_bottom_nav.dart';
import 'foundation_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({
    super.key,
    this.embeddedInShell = false,
    this.onNavigateTab,
  });

  final bool embeddedInShell;
  final ValueChanged<BottomNavTab>? onNavigateTab;

  @override
  State<GoalsScreen> createState() => GoalsScreenState();
}

class GoalsScreenState extends State<GoalsScreen> {
  AggregatedData? _data;
  String? _error;
  bool _loading = true;
  int _loadSerial = 0;
  String _periodCaption = 'Все сохранённые данные';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      GoalsDashboardReloadHub.instance.attachQuietReload(this, _quietReloadGoals);
    });
    _load(showLoading: true);
  }

  /// Подтянуть агрегаты с диска (например после сброса на другой вкладке в [AppShell]).
  Future<void> reloadAggregatesFromShell() => _load(showLoading: false);

  void _quietReloadGoals() {
    if (!mounted) return;
    _load(showLoading: false);
  }

  @override
  void dispose() {
    GoalsDashboardReloadHub.instance.detachQuietReload(this);
    super.dispose();
  }

  Future<void> _load({required bool showLoading}) async {
    final serial = ++_loadSerial;
    if (showLoading) {
      setState(() {
        _loading = true;
        _error = null;
      });
    } else if (mounted) {
      setState(() => _error = null);
    }
    try {
      // Фундамент всегда на полном наборе записей: фильтр недели статистики
      // обрезал прошлые дни (например вчера вне текущей Пн–Вс).
      final data = await InsightsService.instance.aggregateData();
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _data = data;
        _loading = false;
        _periodCaption = 'Все сохранённые данные';
      });
    } catch (e) {
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _error = '$e';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.headerPeach,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: kPeachAppBarToolbarHeight,
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          title: Text(
            'Цели',
            style: peachAppBarTitleStyle(),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Center(child: CircularProgressIndicator(color: AppColors.orange)),
        ),
      );
    }

    if (_error != null || _data == null) {
      return Scaffold(
        backgroundColor: AppColors.cream,
        appBar: AppBar(
          backgroundColor: AppColors.headerPeach,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          toolbarHeight: kPeachAppBarToolbarHeight,
          systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
          ),
          title: Text(
            'Цели',
            style: peachAppBarTitleStyle(),
          ),
        ),
        body: SafeArea(
          top: false,
          bottom: false,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Не удалось загрузить данные для целей.\n$_error',
                textAlign: TextAlign.center,
                style: GoogleFonts.alegreyaSans(
                  fontSize: 15,
                  color: AppColors.textDark.withValues(alpha: 0.8),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return FoundationScreen(
      data: _data!,
      periodCaption: _periodCaption,
      embeddedInShell: widget.embeddedInShell,
      onNavigateTab: widget.onNavigateTab,
      onAggregateReload: () => _load(showLoading: false),
    );
  }
}
