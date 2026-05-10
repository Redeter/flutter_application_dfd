import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/aggregated_data.dart';
import '../models/foundation_score.dart';
import '../models/user_profile.dart';
import '../services/foundation_service.dart';
import '../services/user_profile_service.dart';
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

  /// Не перезаписываем ручные веса из шестерёнки при каждом заходе на вкладку.
  bool _weightsLookUnset(FoundationGoals g) {
    const eps = 0.021;
    return (g.sleepWeight - 1.0).abs() < eps &&
        (g.moodWeight - 1.0).abs() < eps &&
        (g.energyWeight - 1.0).abs() < eps;
  }

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
    if (_weightsLookUnset(goals)) {
      await FoundationService.instance
          .syncGoalsWeightsFromProfilePriority(profile.priorityFocus);
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

  Future<void> _editGoals() async {
    var sleep = _goals.sleepTarget;
    var mood = _goals.moodTarget;
    var energy = _goals.energyTarget;
    var sleepWeight = _goals.sleepWeight;
    var moodWeight = _goals.moodWeight;
    var energyWeight = _goals.energyWeight;
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) {
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

            Widget weightSlider(String label, double value, ValueChanged<double> onChanged) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  Slider(
                    value: value,
                    min: 0.5,
                    max: 2.0,
                    divisions: 15,
                    onChanged: onChanged,
                    activeColor: AppColors.orange,
                  ),
                ],
              );
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                16,
                16,
                16 + MediaQuery.of(context).viewInsets.bottom,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                  slider('Сон', sleep, (v) => setSheetState(() => sleep = v)),
                  slider('Настроение', mood, (v) => setSheetState(() => mood = v)),
                  slider('Энергия', energy, (v) => setSheetState(() => energy = v)),
                  const SizedBox(height: 4),
                  Text(
                    'Важность сфер',
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  weightSlider('Сон', sleepWeight, (v) => setSheetState(() => sleepWeight = v)),
                  weightSlider('Настроение', moodWeight, (v) => setSheetState(() => moodWeight = v)),
                  weightSlider('Энергия', energyWeight, (v) => setSheetState(() => energyWeight = v)),
                  const SizedBox(height: 8),
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
      sleepWeight: sleepWeight,
      moodWeight: moodWeight,
      energyWeight: energyWeight,
    );
    await FoundationService.instance.saveGoals(next);
    await UserProfileService.instance.save(
      UserProfile(
        name: _profile.name,
        conditions: _profile.conditions,
        priorityFocus:
            FoundationService.instance.inferPriorityFocusFromWeights(next),
      ),
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

  void _showPrivacyDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Конфиденциальность',
          style: GoogleFonts.alegreyaSans(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Text(
            'Фундамент и статистика считаются только на этом устройстве. '
            'Данные не отправляются на сервер, если вы сами не экспортируете их.',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              height: 1.35,
              color: AppColors.textDark.withValues(alpha: 0.88),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
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
          'Окно 14 дней, заканчивающееся в этот день: кирпичей ${d.bricks}.\n'
          'В окне: заметок ${d.notesCount}, записей «+» ${d.stateCount}, '
          'записей календаря ${d.calendarCount}.',
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

  Future<void> _pickSpherePriorityManually() async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Что для вас сейчас важнее?',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Мы слегка сдвинем веса сфер; цели по цифрам можно настроить в шестерёнке.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.alegreyaSans(
                    fontSize: 13,
                    color: AppColors.textDark.withValues(alpha: 0.72),
                  ),
                ),
                const SizedBox(height: 16),
                LaconicTap(
                  onTap: () => Navigator.pop(ctx, 'sleep'),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'sleep'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dialogPrimary,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Сон'),
                  ),
                ),
                const SizedBox(height: 8),
                LaconicTap(
                  onTap: () => Navigator.pop(ctx, 'mood'),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'mood'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dialogPrimary,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Настроение'),
                  ),
                ),
                const SizedBox(height: 8),
                LaconicTap(
                  onTap: () => Navigator.pop(ctx, 'energy'),
                  child: FilledButton(
                    onPressed: () => Navigator.pop(ctx, 'energy'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.dialogPrimary,
                      foregroundColor: AppColors.white,
                    ),
                    child: const Text('Энергия'),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ),
        );
      },
    );
    if (pick == null || !mounted) return;
    if (pick != 'sleep' && pick != 'mood' && pick != 'energy') return;
    await UserProfileService.instance.save(
      UserProfile(
        name: _profile.name,
        conditions: _profile.conditions,
        priorityFocus: PriorityStateFocusX.fromCode(pick),
      ),
    );
    await FoundationService.instance.applyPresetWeightsForPrimary(pick);
    final goals = await FoundationService.instance.loadGoals();
    final refreshed = await UserProfileService.instance.load();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _profile = refreshed;
    });
    await _recomputeScore();
  }

  Widget _buildMissionAndLinks() {
    final s = _score!;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                s.missionTitle,
                style: GoogleFonts.alegreyaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              subtitle: Text(
                'Подробнее · что это значит',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 12,
                  color: AppColors.textDark.withValues(alpha: 0.62),
                ),
              ),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Text(
                    s.missionBody,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textDark.withValues(alpha: 0.82),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: _showPrivacyDialog,
              icon: const Icon(Icons.lock_outline, size: 18),
              label: const Text('Конфиденциальность'),
            ),
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
      return 'Шаг на сегодня: стабилизируйте сон и ритм дня, затем коротко отметьте состояние.';
    }
    if (_profile.conditions.contains(MentalCondition.anxiety)) {
      return 'Шаг на сегодня: 3 минуты спокойного дыхания + отметить основной триггер.';
    }
    if (_profile.conditions.contains(MentalCondition.depression)) {
      return 'Шаг на сегодня: один маленький выполнимый шаг и короткая заметка после.';
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
                      ),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _loading ? null : _pickSpherePriorityManually,
                      icon: const Icon(Icons.flag_outlined, size: 20),
                      label: Text(
                        'Приоритет сфер',
                        style: GoogleFonts.alegreyaSans(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.dialogPrimary,
                        side: BorderSide(color: AppColors.orange.withValues(alpha: 0.45)),
                        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 14),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildMissionAndLinks(),
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
                    if (_score!.spheres.any((s) => !s.hasMetricSamples)) ...[
                      const SizedBox(height: 10),
                      FilledButton.tonalIcon(
                        onPressed: () => showStateCategoriesSheet(context),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Добавить запись («+»)'),
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
    const rows = [12, 10, 8, 6, 4];
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.check_rounded, size: 16, color: Colors.green.shade800),
                    const SizedBox(width: 6),
                    Text(
                      'Шаг закрыт записью «+»',
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.green.shade900,
                      ),
                    ),
                  ],
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
                  'Серия отметок: $questStreak ${_foundationPluralDaysRu(questStreak)} подряд',
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
          ...rows.map((count) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(count, (i) {
                  final isFilled = filledLeft > 0;
                  if (isFilled) filledLeft--;
                  return Container(
                    width: 14,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 1.5),
                    decoration: BoxDecoration(
                      color: isFilled ? AppColors.orange : AppColors.greyMuted.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  );
                }),
              ),
            );
          }),
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
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
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
    final progress = (sphere.progress * sphere.confidence).clamp(0.0, 1.0);
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
          Row(
            children: [
              Text(
                sphere.label,
                style: GoogleFonts.alegreyaSans(fontSize: 15, fontWeight: FontWeight.w700),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).round()}% • +${sphere.brickContribution} кирп.',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 13,
                  color: AppColors.textDark.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: progress,
            color: AppColors.orange,
            backgroundColor: AppColors.greyMuted.withValues(alpha: 0.35),
            minHeight: 7,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 6),
          Text(
            !sphere.hasMetricSamples
                ? 'Нет записей этой метрики в «+» — шкала обновится после первых данных. Цель: ${sphere.target.toStringAsFixed(1)}.'
                : 'Текущее: ${sphere.current.toStringAsFixed(1)} / Цель: ${sphere.target.toStringAsFixed(1)}',
            style: GoogleFonts.alegreyaSans(
              fontSize: 12,
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
    final maxVal = history.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, 40.0);
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
            'История фундамента (30 дней)',
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
