import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/aggregated_data.dart';
import '../services/insights_service.dart';
import '../services/stats_period_sync.dart';
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
    _load(showLoading: true);
  }

  /// Подтянуть агрегаты с диска (например после сброса на другой вкладке в [AppShell]).
  Future<void> reloadAggregatesFromShell() => _load(showLoading: false);

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
      final (rs, re) = await StatsPeriodSync.loadRange();
      final data = await InsightsService.instance.aggregateData(
        rangeStart: rs,
        rangeEnd: re,
      );
      if (!mounted || serial != _loadSerial) return;
      setState(() {
        _data = data;
        _loading = false;
        if (rs != null && re != null) {
          _periodCaption =
              'Период как в статистике: ${StatsPeriodSync.formatRangeRu(rs, re)}';
        } else {
          _periodCaption = 'Все сохранённые данные (неделя задаётся на «Статистике»)';
        }
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
