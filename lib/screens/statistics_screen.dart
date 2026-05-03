import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/aggregated_data.dart';
import '../models/insight_result.dart';
import '../models/local_quality_metrics.dart';
import '../models/state_entries.dart';
import '../models/user_profile.dart';
import '../services/dev_data_seed_service.dart';
import '../services/user_profile_service.dart';
import '../services/insights_service.dart';
import '../services/notification_service.dart';
import '../services/offline_validation_service.dart';
import '../services/quality_metrics_service.dart';
import '../services/stats_period_sync.dart';
import '../theme/app_colors.dart';
import '../theme/peach_app_bar.dart';
import '../utils/stats_helpers.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/unified_horizontal_date_strip.dart';
import 'calendar_screen.dart';
import 'goals_screen.dart';
import 'notes_screen.dart';
import 'state_categories_sheet.dart';
import 'user_profile_screen.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key, this.embeddedInShell = false});

  /// Внутри [AppShell]: без нижней панели и без повторной навигации по вкладкам.
  final bool embeddedInShell;

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  InsightResult? _insight;
  AggregatedData? _data;
  LocalQualityMetrics _qualityMetrics = const LocalQualityMetrics();
  bool _loading = false;
  UserProfile _profile = const UserProfile();
  DateTime _selectedDate = DateTime.now();
  bool _viewWeek = true; // true = неделя, false = день
  String _abMode = 'auto';
  String? _draggingBlockId;
  final List<String> _blockOrder = [
    'data_summary',
    'rings',
    'analysis',
    'advice',
    'accuracy_card',
  ];

  @override
  void initState() {
    super.initState();
    _loadMode();
    _loadProfile();
    _load();
    unawaited(StatsPeriodSync.persistWeekContaining(_selectedDate));
  }

  Future<void> _loadProfile() async {
    final p = await UserProfileService.instance.load();
    if (!mounted) return;
    setState(() => _profile = p);
  }

  Future<void> _loadMode() async {
    final mode = await InsightsService.instance.getManualAbMode();
    if (!mounted) return;
    setState(() => _abMode = mode);
  }

  Future<void> _load({bool blocking = true}) async {
    if (blocking && mounted) {
      setState(() => _loading = true);
    }
    try {
      final data = await InsightsService.instance.aggregateData();
      final result = await InsightsService.instance.getInsights(data);
      await QualityMetricsService.instance.registerInsightShown(result, data);
      final metrics = await QualityMetricsService.instance.getMetrics();
      if (mounted) {
        setState(() {
          _data = data;
          _insight = result;
          _qualityMetrics = metrics;
          _loading = false;
        });
        unawaited(StatsPeriodSync.persistWeekContaining(_selectedDate));
      }
      unawaited(_refreshOfflineMetricsInBackground());
    } catch (e) {
      if (mounted) {
        setState(() {
          _insight = InsightResult.fromError('$e');
          _loading = false;
        });
      }
    }
  }

  Future<void> _onPullToRefresh() async {
    await _loadProfile();
    await _load(blocking: false);
  }

  Future<void> _refreshOfflineMetricsInBackground() async {
    try {
      final offline = await OfflineValidationService.instance.evaluate(
        (sample) => InsightsService.instance.getInsights(sample),
      );
      await QualityMetricsService.instance.saveOfflineValidation(
        score: offline.score,
        cases: offline.totalCases,
      );
      final metrics = await QualityMetricsService.instance.getMetrics();
      if (!mounted) return;
      setState(() => _qualityMetrics = metrics);
    } catch (_) {}
  }

  void _onBottomNavTab(BottomNavTab tab) {
    if (widget.embeddedInShell) return;
    switch (tab) {
      case BottomNavTab.statistics:
        return;
      case BottomNavTab.notes:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const NotesScreen()),
        );
      case BottomNavTab.calendar:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const CalendarScreen()),
        );
      case BottomNavTab.articles:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const GoalsScreen()),
        );
    }
  }

  (DateTime, DateTime) get _range {
    if (_viewWeek) {
      final start = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      return (start, start.add(const Duration(days: 6)));
    } else {
      return (_selectedDate, _selectedDate);
    }
  }

  LocalStats get _localStats {
    if (_data == null) return const LocalStats();
    final (start, end) = _range;
    return computeLocalStats(_data!, start: start, end: end);
  }

  /// Тот же диапазон дней, что и в календаре (−5 … +8 от сегодня).
  List<DateTime> get _stripDays {
    final n = DateTime.now();
    final norm = DateTime(n.year, n.month, n.day);
    return List.generate(14, (i) => norm.add(Duration(days: i - 5)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: AppColors.headerPeach,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        toolbarHeight: kPeachAppBarToolbarHeight,
        leadingWidth: kPeachAppBarLeadingWidth,
        actionsPadding: kPeachAppBarActionsPadding,
        systemOverlayStyle: SystemUiOverlayStyle.dark.copyWith(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        automaticallyImplyLeading: !widget.embeddedInShell,
        leading: widget.embeddedInShell
            ? null
            : IconButton(
                style: peachAppBarCircleIconButtonStyle(),
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.pop(context),
              ),
        title: GestureDetector(
          onLongPress: _showHiddenDevActions,
          child: Text(
            'Статистика',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: peachAppBarTitleStyle(),
          ),
        ),
        actions: [
          IconButton(
            style: peachAppBarCircleIconButtonStyle(),
            icon: const Icon(Icons.person_outline_rounded),
            tooltip: 'Профиль',
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const UserProfileScreen()),
              );
              await _loadProfile();
              await _load(blocking: false);
            },
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: AppColors.headerPeach,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.08),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.fromLTRB(
                      0,
                      kPeachHeaderStripTopGap,
                      0,
                      kPeachHeaderStripBottomPadding,
                    ),
                    child: UnifiedHorizontalDateStrip(
                      days: _stripDays,
                      selectedDay: _selectedDate,
                      onDaySelected: (d) {
                        setState(() {
                          _selectedDate = d;
                          _viewWeek = true;
                        });
                        unawaited(StatsPeriodSync.persistWeekContaining(d));
                      },
                    ),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      color: AppColors.orange,
                      onRefresh: _onPullToRefresh,
                      child: _buildContentBelowStrip(),
                    ),
                  ),
                ],
              ),
      ),
      bottomNavigationBar: widget.embeddedInShell
          ? null
          : AppBottomNavBar(
              activeTab: BottomNavTab.statistics,
              onTabSelected: _onBottomNavTab,
              onCenterTap: () => showStateCategoriesSheet(context),
            ),
    );
  }

  Future<void> _showHiddenDevActions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: AppColors.orange),
                title: const Text('Сгенерировать 90 дней (позитивный сценарий)'),
                subtitle: const Text('Больше стабильных и улучшенных показателей'),
                onTap: () => Navigator.pop(context, 'seed_positive'),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: AppColors.orange),
                title: const Text('Сгенерировать 90 дней (негативный сценарий)'),
                subtitle: const Text('Больше рисковых и нестабильных показателей'),
                onTap: () => Navigator.pop(context, 'seed_negative'),
              ),
              ListTile(
                leading: const Icon(Icons.auto_graph, color: AppColors.orange),
                title: const Text('Сгенерировать 90 дней (смешанный сценарий)'),
                subtitle: const Text('Волны: улучшение -> просадка -> восстановление'),
                onTap: () => Navigator.pop(context, 'seed_mixed'),
              ),
              ListTile(
                leading: const Icon(Icons.science_outlined, color: AppColors.orange),
                title: const Text('Режим анализа (A/B)'),
                subtitle: Text('Текущий: ${_abMode.toUpperCase()}'),
                onTap: () => Navigator.pop(context, 'mode'),
              ),
              ListTile(
                leading: const Icon(Icons.analytics_outlined, color: AppColors.orange),
                title: const Text('Показать качество модели'),
                subtitle: const Text('Локальные метрики и offline test'),
                onTap: () => Navigator.pop(context, 'quality'),
              ),
              ListTile(
                leading: const Icon(Icons.notifications_active_outlined, color: AppColors.orange),
                title: const Text('Проверить пуш'),
                subtitle: const Text('Тест локального уведомления'),
                onTap: () => Navigator.pop(context, 'test_push'),
              ),
              ListTile(
                leading: const Icon(Icons.delete_forever_outlined, color: Colors.redAccent),
                title: const Text('Стереть все данные'),
                subtitle: const Text('Полный сброс данных и модели'),
                onTap: () => Navigator.pop(context, 'wipe'),
              ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );

    if (action == 'mode') {
      await _showHiddenModeSelector();
      return;
    }
    if (action == 'quality') {
      _showHiddenQualityDialog();
      return;
    }
    if (action == 'test_push') {
      await NotificationService.instance.showTestNotification();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Тестовое уведомление отправлено.')),
      );
      return;
    }
    if (action == 'wipe') {
      await _confirmAndWipeAllData();
      return;
    }
    if (action != 'seed_positive' &&
        action != 'seed_negative' &&
        action != 'seed_mixed') {
      return;
    }
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      final created = action == 'seed_positive'
          ? await DevDataSeedService.instance.generatePositive90Days()
          : (action == 'seed_negative'
              ? await DevDataSeedService.instance.generateNegative90Days()
              : await DevDataSeedService.instance.generateMixed90Days());
      await NotificationService.instance.rescheduleCalendarNotifications();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            action == 'seed_positive'
                ? 'Добавлен позитивный набор: $created записей'
                : (action == 'seed_negative'
                    ? 'Добавлен негативный набор: $created записей'
                    : 'Добавлен смешанный набор: $created записей'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка генерации: $e')),
      );
    }
  }

  Future<void> _showHiddenModeSelector() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
        return ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.65,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ListTile(
                title: const Text('ML (по умолчанию)'),
                trailing: _abMode == 'ml' ? const Icon(Icons.check, color: AppColors.orange) : null,
                onTap: () => Navigator.pop(context, 'ml'),
              ),
              ListTile(
                title: const Text('Rule'),
                trailing: _abMode == 'rule' ? const Icon(Icons.check, color: AppColors.orange) : null,
                onTap: () => Navigator.pop(context, 'rule'),
              ),
              ListTile(
                title: const Text('Auto'),
                trailing: _abMode == 'auto' ? const Icon(Icons.check, color: AppColors.orange) : null,
                onTap: () => Navigator.pop(context, 'auto'),
              ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null) return;
    await InsightsService.instance.setManualAbMode(selected);
    if (!mounted) return;
    setState(() => _abMode = selected);
    await _load();
  }

  void _showHiddenQualityDialog() {
    final m = _qualityMetrics;
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Качество модели (локально)'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Precision@k: ${(m.precisionAtK * 100).round()}%'),
            Text('Acceptance: ${(m.acceptanceRate * 100).round()}%'),
            Text('Follow-through: ${(m.followThroughRate * 100).round()}%'),
            Text('7d delta: ${(m.outcomeDelta7d * 100).round()}%'),
            Text('Calib.err: ${(m.calibrationError * 100).round()}%'),
            Text('Stability: ${(m.insightStability * 100).round()}%'),
            Text('Coverage: ${(m.coverage * 100).round()}%'),
            Text('Offline test: ${(m.offlineValidationScore * 100).round()}% (${m.offlineValidationCases})'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmAndWipeAllData() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Стереть все данные?'),
        content: const Text(
          'Будут удалены все записи, метрики, кэш модели и тестовые данные. Действие необратимо.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Стереть'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    setState(() => _loading = true);
    try {
      await DevDataSeedService.instance.wipeAllData();
      await NotificationService.instance.rescheduleCalendarNotifications();
      await _loadMode();
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Все локальные данные удалены.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка сброса: $e')),
      );
    }
  }

  Widget _buildContentBelowStrip() {
    if (_insight == null) return const SizedBox.shrink();
    if (_insight!.hasError) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: _buildError(_insight!.error!),
      );
    }
    final blocks = <String, Widget>{};
    if (_data != null && _hasAnyData) {
      blocks['data_summary'] = _buildDataSummary();
    }
    if (_localStats.hasAny || _hasAnyData) {
      blocks['rings'] = _buildRingsAndCards();
    }
    if (_insight!.stateSummary.isNotEmpty ||
        _insight!.overallInsight.isNotEmpty ||
        _insight!.keywords.isNotEmpty) {
      blocks['analysis'] = _buildAiAnalysisCard();
    }
    if (_insight!.recommendations.isNotEmpty) {
      blocks['advice'] = _buildAdviceCard();
    }
    if (_data != null && _insight!.recommendations.isNotEmpty) {
      blocks['accuracy_card'] = _buildEvidenceCard();
    }

    final visibleIds = _blockOrder.where(blocks.containsKey).toList();
    final ordered = visibleIds
        .map((id) => _buildDraggableBlock(id: id, child: blocks[id]!))
        .toList();

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...ordered,
          if (_insight!.insufficientData) _buildInsufficientDataCard(),
          if (!_localStats.hasAny &&
              !_hasAnyData &&
              _insight!.keywords.isEmpty &&
              _insight!.stateSummary.isEmpty &&
              _insight!.overallInsight.isEmpty &&
              _insight!.recommendations.isEmpty)
            _buildEmpty(),
        ],
      ),
    );
  }

  Widget _buildDraggableBlock({
    required String id,
    required Widget child,
  }) {
    final width = MediaQuery.of(context).size.width - 32;
    return DragTarget<String>(
      onWillAcceptWithDetails: (details) => details.data != id,
      onAcceptWithDetails: (details) {
        final fromId = details.data;
        final fromIndex = _blockOrder.indexOf(fromId);
        final toIndex = _blockOrder.indexOf(id);
        if (fromIndex < 0 || toIndex < 0 || fromIndex == toIndex) return;
        setState(() {
          final moved = _blockOrder.removeAt(fromIndex);
          _blockOrder.insert(toIndex, moved);
          _draggingBlockId = null;
        });
      },
      builder: (context, candidateData, rejectedData) {
        final highlighted = candidateData.isNotEmpty;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: highlighted
                ? Border.all(color: AppColors.orange.withValues(alpha: 0.5), width: 1.5)
                : null,
          ),
          child: LongPressDraggable<String>(
            data: id,
            delay: const Duration(milliseconds: 220),
            onDragStarted: () => setState(() => _draggingBlockId = id),
            onDragEnd: (_) => setState(() => _draggingBlockId = null),
            feedback: Material(
              color: Colors.transparent,
              child: SizedBox(
                width: width,
                child: Opacity(
                  opacity: 0.9,
                  child: child,
                ),
              ),
            ),
            childWhenDragging: Opacity(
              opacity: 0.35,
              child: child,
            ),
            child: AnimatedScale(
              duration: const Duration(milliseconds: 120),
              scale: _draggingBlockId == id ? 0.98 : 1.0,
              child: child,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRingsAndCards() {
    final stats = _localStats;
    final medsCount = stats.medicationsCount;
    final visitsCount = stats.appointmentsCount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сводка за период',
          style: GoogleFonts.alegreyaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.textDark,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: _buildRing(
                  rawOutOf10: stats.avgMood,
                  label: 'Настроение',
                  color: AppColors.orange,
                ),
              ),
              Expanded(
                child: _buildRing(
                  rawOutOf10: stats.avgSleep,
                  label: 'Сон',
                  color: AppColors.lavender,
                ),
              ),
              Expanded(
                child: _buildRing(
                  rawOutOf10: stats.avgEnergy,
                  label: 'Энергия',
                  color: AppColors.lightGreen,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, c) {
            final cardWidth = (c.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricCard(
                  cardWidth,
                  'Заметок',
                  '${stats.notesCount}',
                  Icons.edit_note_rounded,
                  [AppColors.lightBlue, const Color(0xFF64B5F6)],
                ),
                _buildMetricCard(
                  cardWidth,
                  'Таблетки',
                  '$medsCount',
                  Icons.medication_outlined,
                  [const Color(0xFFF8BBD0), const Color(0xFFF48FB1)],
                ),
                _buildMetricCard(
                  cardWidth,
                  'Приёмы',
                  '$visitsCount',
                  Icons.event_available_rounded,
                  [const Color(0xFFC8E6C9), const Color(0xFFA5D6A7)],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRing({
    required double? rawOutOf10,
    required String label,
    required Color color,
  }) {
    final progress =
        rawOutOf10 != null ? (rawOutOf10 / 10).clamp(0.0, 1.0) : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(56, 56),
                painter: _RingPainter(
                  progress: progress,
                  color: color,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              if (rawOutOf10 == null)
                Text(
                  '—',
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.white,
                  ),
                )
              else
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        rawOutOf10.toStringAsFixed(1),
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.0,
                          color: AppColors.white,
                        ),
                      ),
                      Text(
                        '/10',
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          height: 1.0,
                          color: Colors.white.withValues(alpha: 0.75),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.alegreyaSans(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    double width,
    String label,
    String value,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.alegreyaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisCard() {
    if (_insight!.stateSummary.isEmpty &&
        _insight!.overallInsight.isEmpty &&
        _insight!.keywords.isEmpty) {
      return const SizedBox.shrink();
    }
    final parts = <String>[];
    if (_insight!.stateSummary.isNotEmpty) parts.add(_insight!.stateSummary);
    if (_insight!.overallInsight.isNotEmpty) parts.add(_insight!.overallInsight);
    final text = parts.join('\n\n');
    final detailed = _composeStateNarrative();
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppColors.orange, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Анализ состояния',
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'на устройстве',
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 11,
                    color: AppColors.textDark.withValues(alpha: 0.8),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.orange.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'уверенность ${(_insight!.confidence * 100).round()}% (${_confidenceLabel(_insight!.confidence)})',
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 11,
                    color: AppColors.textDark.withValues(alpha: 0.8),
                  ),
                ),
              ),
              if (_insight!.insufficientData)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.lavender.withValues(alpha: 0.28),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'это гипотеза',
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 11,
                      color: AppColors.textDark.withValues(alpha: 0.8),
                    ),
                  ),
                ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: GoogleFonts.alegreyaSans(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textDark,
              ),
            ),
          ],
          if (detailed.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              detailed,
              style: GoogleFonts.alegreyaSans(
                fontSize: 14,
                height: 1.45,
                color: AppColors.textDark.withValues(alpha: 0.82),
              ),
            ),
          ],
          if (_insight!.weeklyDigest.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Дайджест недели: ${_insight!.weeklyDigest}',
              style: GoogleFonts.alegreyaSans(
                fontSize: 13,
                height: 1.4,
                color: AppColors.textDark.withValues(alpha: 0.82),
              ),
            ),
          ],
          if (_insight!.burnoutAlert.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF3E0),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.orange.withValues(alpha: 0.4)),
              ),
              child: Text(
                _insight!.burnoutAlert,
                style: GoogleFonts.alegreyaSans(
                  fontSize: 12,
                  height: 1.35,
                  color: AppColors.textDark.withValues(alpha: 0.85),
                ),
              ),
            ),
          ],
          if (_insight!.topTriggers.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Топ-триггеры недели',
              style: GoogleFonts.alegreyaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _insight!.topTriggers
                  .map((t) => Chip(
                        label: Text(t, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.lightBlue.withValues(alpha: 0.2),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
          if (_insight!.causalInsights.isNotEmpty) ...[
            const SizedBox(height: 8),
            ..._insight!.causalInsights.take(2).map(
                  (c) => Text(
                    '• $c',
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 12,
                      color: AppColors.textDark.withValues(alpha: 0.78),
                    ),
                  ),
                ),
          ],
          if (_insight!.confidenceReasons.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'Почему такая уверенность',
              style: GoogleFonts.alegreyaSans(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textDark,
              ),
            ),
            const SizedBox(height: 4),
            ..._insight!.confidenceReasons.take(4).map(
                  (r) => Text(
                    '• $r',
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 12,
                      color: AppColors.textDark.withValues(alpha: 0.72),
                    ),
                  ),
                ),
          ],
          if (_insight!.keywords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _insight!.keywords
                  .take(8)
                  .map((k) => Chip(
                        label: Text(k, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdviceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGreen.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.lightGreen, size: 24),
              const SizedBox(width: 10),
              Text(
                'Советы',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._insight!.recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.check_circle_outline,
                            color: AppColors.orange, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            r,
                            style: GoogleFonts.alegreyaSans(
                              fontSize: 15,
                              height: 1.4,
                              color: AppColors.textDark,
                            ),
                          ),
                        ),
                      ],
                    ),
                    ...(_insight!.recommendationReasons[r] ?? const <String>[])
                        .take(3)
                        .map((reason) => Padding(
                              padding: const EdgeInsets.only(left: 30, top: 4),
                              child: Text(
                                'Почему: $reason',
                                style: GoogleFonts.alegreyaSans(
                                  fontSize: 12,
                                  color: AppColors.textDark.withValues(alpha: 0.65),
                                ),
                              ),
                            )),
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.only(left: 30),
                      child: Wrap(
                        spacing: 8,
                        children: [
                          _feedbackChip(
                            label: 'Полезно',
                            icon: Icons.thumb_up_alt_outlined,
                            onTap: () => _submitRecommendationFeedback(
                              recommendation: r,
                              helpful: true,
                              accepted: false,
                            ),
                          ),
                          _feedbackChip(
                            label: 'Не полезно',
                            icon: Icons.thumb_down_alt_outlined,
                            onTap: () => _submitRecommendationFeedback(
                              recommendation: r,
                              helpful: false,
                              accepted: false,
                            ),
                          ),
                          _feedbackChip(
                            label: 'Сделал',
                            icon: Icons.task_alt,
                            onTap: () => _submitRecommendationFeedback(
                              recommendation: r,
                              helpful: true,
                              accepted: true,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 30, top: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Основание: ${_insight!.recommendationExplanations[r] ?? 'тренд последних дней'}',
                              style: GoogleFonts.alegreyaSans(
                                fontSize: 12,
                                color: AppColors.textDark.withValues(alpha: 0.65),
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: () => _showRecommendationExplain(r),
                            child: const Text('Подробнее'),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildEvidenceCard() {
    final timeline = _buildDayEvidence(_data!);
    final hasTimeline = timeline.isNotEmpty;
    final highRiskDays = timeline.where((d) => d.risk >= 0.66).length;
    final midRiskDays = timeline.where((d) => d.risk >= 0.4 && d.risk < 0.66).length;
    final stableDays = timeline.where((d) => d.risk < 0.4).length;
    final trackedDays = timeline.length;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.fact_check_outlined, color: AppColors.orange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Карточка точности анализа',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textDark,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: _showDecisionTreeDialog,
                icon: const Icon(Icons.account_tree_outlined, size: 16),
                label: const Text('Как решили'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Решения основаны на фактах из последних дней, без выдуманных данных.',
            style: GoogleFonts.alegreyaSans(
              fontSize: 13,
              color: AppColors.textDark.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _metricPill('Дней с данными', '$trackedDays'),
              _metricPill('Рисковых', '$highRiskDays'),
              _metricPill('Средних', '$midRiskDays'),
              _metricPill('Стабильных', '$stableDays'),
            ],
          ),
          if (hasTimeline) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 58,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: timeline.length,
                separatorBuilder: (_, _) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final d = timeline[i];
                  final riskColor = d.risk >= 0.66
                      ? const Color(0xFFE57373)
                      : (d.risk >= 0.4 ? const Color(0xFFFFB74D) : const Color(0xFF81C784));
                  return Container(
                    width: 34,
                    decoration: BoxDecoration(
                      color: riskColor.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: riskColor.withValues(alpha: 0.65)),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          '${d.date.day}',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textDark,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          d.shortLabel,
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 9,
                            color: AppColors.textDark.withValues(alpha: 0.75),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 10,
              children: const [
                _LegendDot(color: Color(0xFF81C784), label: 'стабильно'),
                _LegendDot(color: Color(0xFFFFB74D), label: 'средний риск'),
                _LegendDot(color: Color(0xFFE57373), label: 'высокий риск'),
              ],
            ),
          ] else ...[
            const SizedBox(height: 10),
            Text(
              'Пока мало данных для визуального таймлайна. Добавьте больше записей по дням.',
              style: GoogleFonts.alegreyaSans(
                fontSize: 12,
                color: AppColors.textDark.withValues(alpha: 0.65),
              ),
            ),
          ],
          const SizedBox(height: 10),
          ..._insight!.recommendations.take(3).map((rec) {
            final facts = (_insight!.recommendationReasons[rec] ?? const <String>[]).take(3).toList();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.cream,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rec,
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Скор уверенности: ${(((_insight!.recommendationScores[rec] ?? _insight!.confidence) * 100).round())}%',
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 12,
                        color: AppColors.textDark.withValues(alpha: 0.65),
                      ),
                    ),
                    const SizedBox(height: 4),
                    ...facts.map((f) => Text(
                          '• $f',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 12,
                            color: AppColors.textDark.withValues(alpha: 0.75),
                          ),
                        )),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  List<_DayEvidence> _buildDayEvidence(AggregatedData data) {
    final now = DateTime.now();
    final byDayMood = <DateTime, List<int>>{};
    final byDaySleep = <DateTime, List<int>>{};
    final byDayEnergy = <DateTime, List<int>>{};
    for (final e in data.stateEntries) {
      final day = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      if (now.difference(day).inDays > 13) continue;
      switch (e) {
        case MoodEntry(:final value):
          byDayMood.putIfAbsent(day, () => []).add(value);
        case SleepEntry(:final quality):
          byDaySleep.putIfAbsent(day, () => []).add(quality);
        case EnergyEntry(:final level):
          byDayEnergy.putIfAbsent(day, () => []).add(level);
        default:
          break;
      }
    }

    final out = <_DayEvidence>[];
    for (var i = 13; i >= 0; i--) {
      final day = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      final mood = byDayMood[day];
      final sleep = byDaySleep[day];
      final energy = byDayEnergy[day];
      if (mood == null && sleep == null && energy == null) continue;
      final m = mood == null ? null : mood.reduce((a, b) => a + b) / mood.length;
      final s = sleep == null ? null : sleep.reduce((a, b) => a + b) / sleep.length;
      final e = energy == null ? null : energy.reduce((a, b) => a + b) / energy.length;
      var risk = 0.0;
      var denom = 0.0;
      if (m != null) {
        risk += (10 - m) / 10;
        denom++;
      }
      if (s != null) {
        risk += (10 - s) / 10;
        denom++;
      }
      if (e != null) {
        risk += (10 - e) / 10;
        denom++;
      }
      final normRisk = denom > 0 ? (risk / denom).clamp(0.0, 1.0) : 0.0;
      final label = normRisk >= 0.66 ? 'низк' : (normRisk >= 0.4 ? 'сред' : 'стаб');
      out.add(_DayEvidence(date: day, risk: normRisk, shortLabel: label));
    }
    return out;
  }

  void _showDecisionTreeDialog() {
    final firstRec = _insight?.recommendations.isNotEmpty == true
        ? _insight!.recommendations.first
        : 'Советов пока недостаточно';
    final reasons = _insight?.recommendationReasons[firstRec] ?? const <String>[];
    final confidencePct = ((_insight?.recommendationScores[firstRec] ?? _insight?.confidence ?? 0) * 100).round();
    final trackedDays = _buildDayEvidence(_data ?? AggregatedData(
      notes: const [],
      stateEntries: const [],
      medications: const [],
      appointments: const [],
    )).length;

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Дерево решений (простое)'),
        content: SizedBox(
          width: 380,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _treeNode(
                  title: 'Входные данные',
                  subtitle: '$trackedDays дней наблюдений',
                  color: const Color(0xFFE3F2FD),
                ),
                _treeConnector(),
                Row(
                  children: [
                    Expanded(
                      child: _treeNode(
                        title: 'Качество данных',
                        subtitle: 'шум/дубли/валидность',
                        color: const Color(0xFFFFF3E0),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _treeNode(
                        title: 'Тренды',
                        subtitle: 'сон/энергия/настроение',
                        color: const Color(0xFFE8F5E9),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                _splitConnector(),
                Row(
                  children: [
                    Expanded(
                      child: _treeNode(
                        title: 'Персонализация',
                        subtitle: 'baseline/регулярность',
                        color: const Color(0xFFF3E5F5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _treeNode(
                        title: 'Факты из заметок',
                        subtitle: 'тревожные маркеры',
                        color: const Color(0xFFFFEBEE),
                      ),
                    ),
                  ],
                ),
                _treeConnector(),
                _treeNode(
                  title: 'Ранжирование рекомендаций',
                  subtitle: 'только подтвержденные, top-3',
                  color: const Color(0xFFEDE7F6),
                ),
                _treeConnector(),
                _treeNode(
                  title: 'Итоговое решение',
                  subtitle: '"$firstRec"\nУверенность: $confidencePct%',
                  color: const Color(0xFFE0F2F1),
                ),
                if (reasons.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  _treeNode(
                    title: 'Почему выбран этот совет',
                    subtitle: reasons.take(3).join('\n'),
                    color: const Color(0xFFFFF8E1),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Widget _treeNode({
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.greyMuted.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.alegreyaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: GoogleFonts.alegreyaSans(
              fontSize: 12,
              color: AppColors.textDark.withValues(alpha: 0.78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _treeConnector() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Center(
        child: Icon(Icons.arrow_downward_rounded, size: 18, color: AppColors.orange),
      ),
    );
  }

  Widget _splitConnector() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Divider(color: AppColors.greyMuted.withValues(alpha: 0.7))),
          const SizedBox(width: 6),
          const Icon(Icons.call_split, size: 14, color: AppColors.orange),
          const SizedBox(width: 6),
          Expanded(child: Divider(color: AppColors.greyMuted.withValues(alpha: 0.7))),
        ],
      ),
    );
  }

  Widget _buildInsufficientDataCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.35)),
      ),
      child: Text(
        'Недостаточно качественных данных: желательно минимум 7 дней регулярных записей.',
        style: GoogleFonts.alegreyaSans(
          fontSize: 13,
          color: AppColors.textDark.withValues(alpha: 0.85),
        ),
      ),
    );
  }

  Future<void> _submitRecommendationFeedback({
    required String recommendation,
    required bool helpful,
    required bool accepted,
  }) async {
    await QualityMetricsService.instance.registerRecommendationFeedback(
      recommendation: recommendation,
      helpful: helpful,
      accepted: accepted,
    );
    final metrics = await QualityMetricsService.instance.getMetrics();
    if (!mounted) return;
    setState(() => _qualityMetrics = metrics);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          accepted ? 'Отлично, отметили выполнение.' : 'Спасибо за обратную связь.',
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _feedbackChip({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.cream,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.greyMuted),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: AppColors.textDark.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: GoogleFonts.alegreyaSans(
                fontSize: 12,
                color: AppColors.textDark.withValues(alpha: 0.75),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecommendationExplain(String recommendation) {
    final reasons = (_insight?.recommendationReasons[recommendation] ?? const <String>[]).take(3).toList();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('На чем основан совет'),
        content: Text(
          reasons.isEmpty ? 'Совет построен на трендах последних дней.' : reasons.join('\n'),
          style: GoogleFonts.alegreyaSans(fontSize: 14, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _metricPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.cream,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: GoogleFonts.alegreyaSans(
          fontSize: 12,
          color: AppColors.textDark.withValues(alpha: 0.8),
        ),
      ),
    );
  }

  bool get _hasAnyData {
    if (_data == null) return false;
    return _data!.notes.isNotEmpty ||
        _data!.stateEntries.isNotEmpty ||
        _data!.medications.isNotEmpty ||
        _data!.appointments.isNotEmpty;
  }

  Widget _buildDataSummary() {
    final d = _data!;
    final parts = <String>[];
    if (d.notes.isNotEmpty) parts.add('${d.notes.length} ${_plural(d.notes.length, 'заметка', 'заметки', 'заметок')}');
    if (d.stateEntries.isNotEmpty) parts.add('${d.stateEntries.length} ${_plural(d.stateEntries.length, 'запись', 'записи', 'записей')} о состоянии');
    if (d.medications.isNotEmpty) parts.add('${d.medications.length} ${_plural(d.medications.length, 'препарат', 'препарата', 'препаратов')}');
    if (d.appointments.isNotEmpty) parts.add('${d.appointments.length} ${_plural(d.appointments.length, 'визит', 'визита', 'визитов')}');
    if (_profile.hasConditions) {
      parts.add('режим: ${_profile.conditions.map((e) => e.label).join(', ')}');
    } else {
      parts.add('режим: без заболевания');
    }
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.analytics_outlined, color: AppColors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'На основе: ${parts.join(', ')}',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 14,
                  color: AppColors.textDark.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _composeStateNarrative() {
    if (_data == null) return '';
    final stats = _localStats;
    final pieces = <String>[];

    if (stats.avgMood != null) {
      if (stats.avgMood! < 5) {
        pieces.add('Эмоциональный фон сейчас ниже комфортного уровня, это обычно заметно в повседневной мотивации.');
      } else if (stats.avgMood! < 7) {
        pieces.add('Настроение в нейтральной зоне: без резких провалов, но с потенциалом для улучшения.');
      } else {
        pieces.add('Эмоциональный фон в устойчивой зоне, это хороший базовый признак восстановления.');
      }
    }

    if (stats.avgSleep != null) {
      if (stats.avgSleep! < 5.5) {
        pieces.add('Сон выглядит ключевым ограничителем состояния: при таком качестве часто проседают энергия и настроение.');
      } else if (stats.avgSleep! < 7) {
        pieces.add('Сон на среднем уровне: небольшое улучшение режима обычно дает заметный эффект уже в течение недели.');
      } else {
        pieces.add('Сон сейчас скорее поддерживающий фактор и помогает держать стабильность дня.');
      }
    }

    if (stats.avgEnergy != null) {
      if (stats.avgEnergy! < 5) {
        pieces.add('Энергия снижена: лучше делать упор на короткие, выполнимые действия вместо больших задач.');
      } else if (stats.avgEnergy! >= 7) {
        pieces.add('Энергия в норме — это подходящий момент закреплять полезные привычки и режим.');
      }
    }

    if (_insight!.keywords.isNotEmpty) {
      final k = _insight!.keywords.take(3).join(', ');
      pieces.add('Чаще всего в записях встречаются маркеры: $k — они и влияют на итоговые рекомендации.');
    }

    return pieces.join(' ');
  }

  String _plural(int n, String one, String few, String many) {
    if (n % 10 == 1 && n % 100 != 11) return one;
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return few;
    return many;
  }

  String _confidenceLabel(double value) {
    if (value < 0.45) return 'низкая';
    if (value < 0.72) return 'средняя';
    return 'высокая';
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.insights_rounded,
                size: 64, color: AppColors.orange.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Добавьте заметки, записи о состоянии (кнопка +), препараты и визиты. Анализ выполняется локально — чем больше данных, тем точнее выводы',
              textAlign: TextAlign.center,
              style: GoogleFonts.alegreyaSans(
                fontSize: 16,
                color: AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: GoogleFonts.alegreyaSans(
            fontSize: 16,
            color: Colors.red.shade700,
          ),
        ),
      ),
    );
  }

}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final strokeWidth = 5.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      const startAngle = -3.14159 / 2; // top
      final sweepAngle = 2 * 3.14159 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}

class _DayEvidence {
  const _DayEvidence({
    required this.date,
    required this.risk,
    required this.shortLabel,
  });
  final DateTime date;
  final double risk;
  final String shortLabel;
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({
    required this.color,
    required this.label,
  });

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: GoogleFonts.alegreyaSans(
            fontSize: 11,
            color: AppColors.textDark.withValues(alpha: 0.75),
          ),
        ),
      ],
    );
  }
}
