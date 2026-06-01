import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/aggregated_data.dart';
import '../models/foundation_score.dart';
import '../models/foundation_sphere.dart';
import '../models/user_profile.dart';
import '../services/foundation_service.dart';
import '../services/user_profile_service.dart';
import '../widgets/foundation_sphere_checkboxes.dart';
import '../theme/app_colors.dart';
import '../theme/peach_app_bar.dart';
import '../widgets/app_bottom_nav.dart';
import '../widgets/laconic_tap.dart';
import 'calendar_screen.dart';
import 'notes_screen.dart';
import 'state_categories_sheet.dart';
import 'statistics_screen.dart';

String _foundationPluralDaysRu(int n) {
  final mod100 = n % 100;
  if (mod100 >= 11 && mod100 <= 14) return 'дней';
  switch (n % 10) {
    case 1:
      return 'день';
    case 2:
    case 3:
    case 4:
      return 'дня';
    default:
      return 'дней';
  }
}

class FoundationScreen extends StatefulWidget {
  const FoundationScreen({
    super.key,
    required this.data,
    required this.periodCaption,
    this.embeddedInShell = false,
    this.onNavigateTab,
    this.onAggregateReload,
  });

  final AggregatedData data;
  final String periodCaption;
  final bool embeddedInShell;
  final ValueChanged<BottomNavTab>? onNavigateTab;

  /// Перезагрузка агрегатов у родителя ([GoalsScreen]) перед пересчётом фундамента (pull-to-refresh).
  final Future<void> Function()? onAggregateReload;

  @override
  State<FoundationScreen> createState() => _FoundationScreenState();
}

class _FoundationScreenState extends State<FoundationScreen> {
  FoundationGoals _goals = const FoundationGoals();
  UserProfile _profile = const UserProfile();
  FoundationScore? _score;
  bool _loading = true;
  bool _questDone = false;
  int _questStreak = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FoundationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((oldWidget.data != widget.data || oldWidget.periodCaption != widget.periodCaption) &&
        !_loading) {
      _recomputeScore();
    }
  }

  Future<void> _recomputeScore() async {
    final raw = FoundationService.instance.compute(
      widget.data,
      _goals,
      statsPeriodCaption: widget.periodCaption,
    );
    final scored = await FoundationService.instance.applyDisplaySmoothing(raw);
    if (!mounted) return;
    setState(() => _score = scored);
  }

  Future<void> _load() async {
    final profile = await UserProfileService.instance.load();
    var goals = await FoundationService.instance.loadGoals();
    if (goals.priorities.activeWeightSum == 0) {
      await FoundationService.instance
          .syncGoalsPrioritiesFromProfile(profile.spherePriorities);
      goals = await FoundationService.instance.loadGoals();
    }
    await FoundationService.instance.ensureQuestHistorySyncedWithLegacyFlag();
    final streak = await FoundationService.instance.loadQuestCompletionStreak();
    final done = await FoundationService.instance.isQuestDoneToday();
    final raw = FoundationService.instance.compute(
      widget.data,
      goals,
      statsPeriodCaption: widget.periodCaption,
    );
    final scored = await FoundationService.instance.applyDisplaySmoothing(raw);
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _profile = profile;
      _score = scored;
      _questDone = done;
      _questStreak = streak;
      _loading = false;
    });
  }

  Future<void> _applySpherePriorities(FoundationSpherePriorities next) async {
    final merged = _goals.copyWith(priorities: next);
    await FoundationService.instance.saveGoals(merged);
    await UserProfileService.instance.save(
      _profile.copyWith(spherePriorities: next),
    );
    if (!mounted) return;
    setState(() => _goals = merged);
    await _recomputeScore();
  }

  Widget _buildSphereSelectionCard() {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.2)),
      ),
      child: FoundationSphereCheckboxes(
        dense: true,
        priorities: _goals.priorities,
        onChanged: _applySpherePriorities,
      ),
    );
  }

  Future<void> _editGoals() async {
    var sleep = _goals.sleepTarget;
    var mood = _goals.moodTarget;
    var energy = _goals.energyTarget;
    var snackTarget = _goals.snackTarget;
    final priorities = _goals.priorities;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Widget slider(String label, double value, ValueChanged<double> onChanged) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label: ${value.toStringAsFixed(1)}'),
                  Slider(
                    value: value,
                    min: 4,
                    max: 9.5,
                    divisions: 11,
                    onChanged: onChanged,
                    activeColor: AppColors.orange,
                  ),
                ],
              );
            }

            final maxH = MediaQuery.of(sheetContext).size.height * 0.88;
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
              ),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxHeight: maxH),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Цели фундамента',
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (priorities.isActive(FoundationSphereIds.sleep))
                        slider('Сон', sleep, (v) => setSheetState(() => sleep = v)),
                      if (priorities.isActive(FoundationSphereIds.mood))
                        slider(
                          'Настроение',
                          mood,
                          (v) => setSheetState(() => mood = v),
                        ),
                      if (priorities.isActive(FoundationSphereIds.energy))
                        slider(
                          'Энергия',
                          energy,
                          (v) => setSheetState(() => energy = v),
                        ),
                      if (priorities.isActive(FoundationSphereIds.nutrition)) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Перекусов в день (основные приёмы: ${FoundationGoals.mainMealsTarget})',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Slider(
                          value: snackTarget.toDouble(),
                          min: 0,
                          max: 5,
                          divisions: 5,
                          label: '$snackTarget',
                          activeColor: AppColors.orange,
                          onChanged: (v) =>
                              setSheetState(() => snackTarget = v.round()),
                        ),
                      ],
                      const SizedBox(height: 12),
                      LaconicTap(
                        onTap: () => Navigator.pop(context, true),
                        child: FilledButton(
                          onPressed: () => Navigator.pop(context, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.dialogPrimary,
                            foregroundColor: AppColors.white,
                          ),
                          child: const Text('Сохранить'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
    if (saved != true) return;
    final next = FoundationGoals(
      sleepTarget: sleep,
      moodTarget: mood,
      energyTarget: energy,
      snackTarget: snackTarget,
      priorities: priorities,
    );
    await FoundationService.instance.saveGoals(next);
    await UserProfileService.instance.save(
      _profile.copyWith(spherePriorities: priorities),
    );
    final updatedProfile = await UserProfileService.instance.load();
    if (!mounted) return;
    final raw = FoundationService.instance.compute(
      widget.data,
      next,
      statsPeriodCaption: widget.periodCaption,
    );
    final scored = await FoundationService.instance.applyDisplaySmoothing(raw);
    if (!mounted) return;
    setState(() {
      _goals = next;
      _profile = updatedProfile;
      _score = scored;
    });
  }

  Future<void> _toggleQuest(bool value) async {
    await FoundationService.instance.setQuestDoneToday(value);
    if (!mounted) return;
    final confirmed = await FoundationService.instance.isQuestDoneToday();
    final streak = await FoundationService.instance.loadQuestCompletionStreak();
    if (!mounted) return;
    setState(() {
      _questDone = confirmed;
      _questStreak = streak;
    });
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          confirmed
              ? 'Отметка на сегодня сохранена на устройстве'
              : 'Отметка снята',
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onPullRefresh() async {
    if (widget.onAggregateReload != null) {
      await widget.onAggregateReload!();
    }
    await _load();
  }

  void _showHistoryDayDetail(FoundationHistoryDayDetail d) {
    final day = d.windowEndDay;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          '${day.day}.${day.month.toString().padLeft(2, '0')}.${day.year}',
          style: GoogleFonts.alegreyaSans(fontWeight: FontWeight.w800),
        ),
        content: Text(
          'День ${d.windowEndDay.day}.${d.windowEndDay.month}: '
          'прогресс ${d.dailyScorePercent}%, кирпичей ${d.bricks}.\n'
          'Записей «+» ${d.stateCount}, календарь ${d.calendarCount}.',
          style: GoogleFonts.alegreyaSans(
            fontSize: 14,
            height: 1.35,
            color: AppColors.textDark.withValues(alpha: 0.88),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard() {
    final s = _score!;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.lavender.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.flag_outlined, color: AppColors.orange.withValues(alpha: 0.9)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.weeklyFocusTitle,
                  style: GoogleFonts.alegreyaSans(fontSize: 14, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 2),
                Text(
                  s.weeklyFocusSubtitle,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 13,
                    color: AppColors.textDark.withValues(alpha: 0.75),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodAndStatsRow() {
    return Text(
      _score!.statsPeriodCaption,
      style: GoogleFonts.alegreyaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: AppColors.textDark.withValues(alpha: 0.62),
      ),
    );
  }

  Widget _buildTodayStepCard() {
    final met = FoundationService.instance.todayStepSatisfiedByPlusData(
      data: widget.data,
      profile: _profile,
      nextStepSphereId: _score!.nextStepSphereId,
      goals: _goals,
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Отметка за сегодня',
            style: GoogleFonts.alegreyaSans(
              fontSize: 13,
              fontWeight: FontWeight.w800,
              color: AppColors.textDark.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Текст шага — в карточке фундамента выше.',
            style: GoogleFonts.alegreyaSans(
              fontSize: 12,
              height: 1.3,
              color: AppColors.textDark.withValues(alpha: 0.62),
            ),
          ),
          if (met) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.check_circle_outline_rounded,
                    size: 20,
                    color: Colors.green.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _questDone
                          ? 'Запись «+» за сегодня уже закрывает шаг — галочка тоже стоит.'
                          : 'По данным «+» за сегодня шаг уже выполнен. Можно отметить галочкой для серии дней.',
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 13,
                        height: 1.35,
                        color: AppColors.textDark.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (!_questDone) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: _loading ? null : () => _toggleQuest(true),
                  icon: Icon(Icons.auto_awesome_rounded, color: AppColors.dialogPrimary),
                  label: Text(
                    'Отметить автоматически по «+»',
                    style: GoogleFonts.alegreyaSans(
                      fontWeight: FontWeight.w700,
                      color: AppColors.dialogPrimary,
                    ),
                  ),
                ),
              ),
            ],
          ],
          CheckboxTheme(
            data: CheckboxThemeData(
              fillColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppColors.orange;
                }
                return null;
              }),
            ),
            child: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              title: Text(
                _questDone ? 'Сделано сегодня' : 'Отметить выполнение вручную',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textDark.withValues(alpha: 0.88),
                ),
              ),
              subtitle: Text(
                _questDone
                    ? 'Запись только на этом устройстве; завтра сбросится.'
                    : 'Отметьте, когда шаг сделан — учитывается в серии дней ниже.',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 12,
                  height: 1.3,
                  color: AppColors.textDark.withValues(alpha: 0.62),
                ),
              ),
              value: _questDone,
              onChanged: _loading
                  ? null
                  : (bool? v) {
                      if (v != null) {
                        _toggleQuest(v);
                      }
                    },
            ),
          ),
        ],
      ),
    );
  }

  String _profileAdjustedNextStep(String base) {
    if (!_profile.hasConditions) return base;
    if (_profile.conditions.contains(MentalCondition.bipolar)) {
      return 'Шаг на сегодня: отметьте сон в «+» и держите ритм дня.';
    }
    if (_profile.conditions.contains(MentalCondition.anxiety)) {
      return 'Шаг на сегодня: настроение или эмоции в «+» после короткой паузы.';
    }
    if (_profile.conditions.contains(MentalCondition.depression)) {
      return 'Шаг на сегодня: отметьте настроение в «+» — один маленький шаг за раз.';
    }
    return base;
  }

  void _goBack() {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
      return;
    }
    if (widget.embeddedInShell && widget.onNavigateTab != null) {
      widget.onNavigateTab!(BottomNavTab.statistics);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const StatisticsScreen()),
    );
  }

  void _onBottomTab(BottomNavTab tab) {
    if (widget.embeddedInShell && widget.onNavigateTab != null) {
      widget.onNavigateTab!(tab);
      return;
    }
    switch (tab) {
      case BottomNavTab.articles:
        return;
      case BottomNavTab.statistics:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const StatisticsScreen()),
        );
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
    }
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
                onPressed: _goBack,
              ),
        title: Text(
          'Цели',
          style: peachAppBarTitleStyle(),
        ),
        actions: [
          IconButton(
            style: peachAppBarCircleIconButtonStyle(),
            onPressed: _loading ? null : _editGoals,
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: false,
        child: _loading || _score == null
            ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
            : RefreshIndicator(
                color: AppColors.orange,
                onRefresh: _onPullRefresh,
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _FoundationHero(
                      score: _score!,
                      nextStepLine: _profileAdjustedNextStep(_score!.nextStep),
                      questStreak: _questStreak,
                      stepMetByData: FoundationService.instance
                          .todayStepSatisfiedByPlusData(
                        data: widget.data,
                        profile: _profile,
                        nextStepSphereId: _score!.nextStepSphereId,
                        goals: _goals,
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildSphereSelectionCard(),
                    const SizedBox(height: 10),
                    _buildWeeklyCard(),
                    const SizedBox(height: 8),
                    _buildPeriodAndStatsRow(),
                    if (_score!.medicationAdherenceRate != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _score!.medicationAdherenceCaption,
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 12,
                          color: AppColors.textDark.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                    const SizedBox(height: 10),
                    _HistoryStrip(
                      score: _score!,
                      onBarTap: _showHistoryDayDetail,
                    ),
                    const SizedBox(height: 12),
                    ..._score!.spheres.map((s) => _SphereTile(sphere: s)),
                  const SizedBox(height: 12),
                  _buildTodayStepCard(),
                ],
                ),
              ),
            ),
      ),
      bottomNavigationBar: widget.embeddedInShell
          ? null
          : AppBottomNavBar(
              activeTab: BottomNavTab.articles,
              onTabSelected: _onBottomTab,
              onCenterTap: () => showStateCategoriesSheet(context),
            ),
    );
  }
}

class _FoundationHero extends StatelessWidget {
  const _FoundationHero({
    required this.score,
    required this.nextStepLine,
    required this.questStreak,
    required this.stepMetByData,
  });

  final FoundationScore score;
  final String nextStepLine;
  final int questStreak;
  final bool stepMetByData;

  @override
  Widget build(BuildContext context) {
    final pct = (score.overallProgress * 100).round();
    const rows = [18, 16, 14, 12, 12];
    var filledLeft = score.filledBricks;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.28)),
      ),
      child: Column(
        children: [
          Text(
            'Фундамент благосостояния',
            style: GoogleFonts.alegreyaSans(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$pct% к вашей цели',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              color: AppColors.textDark.withValues(alpha: 0.75),
            ),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: AppColors.dialogPrimary,
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nextStepLine,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 14,
                      height: 1.35,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textDark.withValues(alpha: 0.9),
                    ),
                  ),
                ),
              ],
            ),
          ),
          if (stepMetByData) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Шаг закрыт записью «+»',
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.green.shade900,
                  ),
                ),
              ),
            ),
          ],
          if (questStreak > 0) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.lavender.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Серия: $questStreak ${_foundationPluralDaysRu(questStreak)}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark.withValues(alpha: 0.82),
                  ),
                ),
              ),
            ),
          ],
          if ((score.overallProgress - score.rawOverallProgress).abs() > 0.02) ...[
            const SizedBox(height: 4),
            Text(
              'Сырое значение: ${(score.rawOverallProgress * 100).round()}% (сглаживание снижает скачки от дня к дню).',
              textAlign: TextAlign.center,
              style: GoogleFonts.alegreyaSans(
                fontSize: 11,
                color: AppColors.textDark.withValues(alpha: 0.55),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              _heroPill(
                score.brickDelta7d >= 0
                    ? '+${score.brickDelta7d} кирпичей за 7 дней'
                    : '${score.brickDelta7d} кирпичей за 7 дней',
                score.brickDelta7d >= 0 ? AppColors.lightGreen : const Color(0xFFFFE4E4),
              ),
              _heroPill(
                score.riskCracks == 0
                    ? 'без трещин'
                    : (score.riskCracks == 1 ? '1 трещина риска' : '2 трещины риска'),
                score.riskCracks == 0 ? AppColors.lightBlue : const Color(0xFFFFF3E0),
              ),
            ],
          ),
          if (score.riskCracks > 0 && score.riskCracksExplanation != null) ...[
            const SizedBox(height: 6),
            Text(
              score.riskCracksExplanation!,
              textAlign: TextAlign.center,
              style: GoogleFonts.alegreyaSans(
                fontSize: 11,
                color: AppColors.textDark.withValues(alpha: 0.65),
              ),
            ),
          ],
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              const brickH = 10.0;
              const gap = 2.0;
              return Column(
                children: rows.map((count) {
                  final totalGap = count > 1 ? (count - 1) * gap : 0.0;
                  final brickW =
                      ((constraints.maxWidth - totalGap) / count).clamp(5.0, 16.0);
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(count, (i) {
                        final isFilled = filledLeft > 0;
                        if (isFilled) filledLeft--;
                        return Padding(
                          padding: EdgeInsets.only(left: i == 0 ? 0 : gap),
                          child: Container(
                            width: brickW,
                            height: brickH,
                            decoration: BoxDecoration(
                              color: isFilled
                                  ? AppColors.orange
                                  : AppColors.greyMuted.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        );
                      }),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 10),
          Text(
            score.dataSourcesSummary,
            textAlign: TextAlign.center,
            style: GoogleFonts.alegreyaSans(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            score.userHint,
            textAlign: TextAlign.center,
            style: GoogleFonts.alegreyaSans(
              fontSize: 12,
              color: AppColors.textDark.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPill(String text, Color color) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 280),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.alegreyaSans(
          fontSize: 11,
          color: AppColors.textDark.withValues(alpha: 0.82),
        ),
      ),
    );
  }
}

class _SphereTile extends StatelessWidget {
  const _SphereTile({required this.sphere});
  final FoundationSphereScore sphere;

  @override
  Widget build(BuildContext context) {
    final progress = sphere.progress.clamp(0.0, 1.0);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            sphere.label,
            style: GoogleFonts.alegreyaSans(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            color: AppColors.orange,
            backgroundColor: AppColors.greyMuted.withValues(alpha: 0.35),
            minHeight: 8,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text(
            '${(progress * 100).round()}% за сегодня · ${sphere.detailLine}',
            style: GoogleFonts.alegreyaSans(
              fontSize: 12,
              height: 1.35,
              color: AppColors.textDark.withValues(alpha: 0.68),
            ),
          ),
        ],
      ),
    );
  }
}

class _HistoryStrip extends StatelessWidget {
  const _HistoryStrip({
    required this.score,
    required this.onBarTap,
  });

  final FoundationScore score;
  final void Function(FoundationHistoryDayDetail d) onBarTap;

  @override
  Widget build(BuildContext context) {
    final history = score.history30d;
    if (history.isEmpty) return const SizedBox.shrink();
    final maxVal = history.reduce((a, b) => a > b ? a : b).toDouble().clamp(
          1.0,
          FoundationService.totalBricks.toDouble(),
        );
    final details = score.historyDayDetails;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'История фундамента (${FoundationService.historyDays} дней)',
            style: GoogleFonts.alegreyaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          Text(
            'Нажмите на столбик — что вошло в окно.',
            style: GoogleFonts.alegreyaSans(
              fontSize: 11,
              color: AppColors.textDark.withValues(alpha: 0.55),
            ),
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 28,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(history.length, (i) {
                final v = history[i];
                final detail = i < details.length ? details[i] : null;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 0.5),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: detail == null ? null : () => onBarTap(detail),
                      child: Container(
                        height: ((v / maxVal) * 26).clamp(2.0, 26.0),
                        decoration: BoxDecoration(
                          color: AppColors.orange.withValues(alpha: 0.75),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
