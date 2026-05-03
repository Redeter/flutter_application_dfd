import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/aggregated_data.dart';
import '../models/foundation_score.dart';
import '../models/user_profile.dart';
import '../services/foundation_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/app_bottom_nav.dart';
import 'calendar_screen.dart';
import 'notes_screen.dart';
import 'state_categories_sheet.dart';
import 'statistics_screen.dart';

class FoundationScreen extends StatefulWidget {
  const FoundationScreen({
    super.key,
    required this.data,
    this.embeddedInShell = false,
    this.onNavigateTab,
  });

  final AggregatedData data;
  final bool embeddedInShell;
  final ValueChanged<BottomNavTab>? onNavigateTab;

  @override
  State<FoundationScreen> createState() => _FoundationScreenState();
}

class _FoundationScreenState extends State<FoundationScreen> {
  FoundationGoals _goals = const FoundationGoals();
  UserProfile _profile = const UserProfile();
  FoundationScore? _score;
  bool _loading = true;
  bool _questDone = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final goals = await FoundationService.instance.loadGoals();
    final done = await FoundationService.instance.isQuestDoneToday();
    final profile = await UserProfileService.instance.load();
    if (!mounted) return;
    setState(() {
      _goals = goals;
      _profile = profile;
      _score = FoundationService.instance.compute(widget.data, goals);
      _questDone = done;
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
    var consistencyWeight = _goals.consistencyWeight;
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
                  Text('$label: x${value.toStringAsFixed(1)}'),
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
                  weightSlider('Регулярность', consistencyWeight, (v) => setSheetState(() => consistencyWeight = v)),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                    child: const Text('Сохранить'),
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
      consistencyWeight: consistencyWeight,
    );
    await FoundationService.instance.saveGoals(next);
    if (!mounted) return;
    setState(() {
      _goals = next;
      _score = FoundationService.instance.compute(widget.data, next);
    });
  }

  Future<void> _toggleQuest(bool value) async {
    await FoundationService.instance.setQuestDoneToday(value);
    if (!mounted) return;
    setState(() => _questDone = value);
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
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: !widget.embeddedInShell,
        leading: widget.embeddedInShell
            ? null
            : IconButton(
                icon: const Icon(Icons.arrow_back, color: AppColors.orange),
                onPressed: _goBack,
              ),
        title: Text(
          'Цели',
          style: GoogleFonts.alegreyaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          IconButton(
            onPressed: _loading ? null : _editGoals,
            icon: const Icon(Icons.tune_rounded, color: AppColors.orange),
          ),
        ],
      ),
      body: _loading || _score == null
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      _profile.hasConditions
                          ? 'Режим: ${_profile.conditions.map((e) => e.label).join(', ')}. Фундамент учитывает эти особенности.'
                          : 'Фундамент собирается из сна, настроения, энергии и регулярности. Каждый кирпич — шаг к вашей личной цели.',
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 13,
                        color: AppColors.textDark.withValues(alpha: 0.8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _FoundationHero(score: _score!),
                  const SizedBox(height: 10),
                  _HistoryStrip(history: _score!.history30d),
                  const SizedBox(height: 12),
                  ..._score!.spheres.map((s) => _SphereTile(sphere: s)),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      _profileAdjustedNextStep(_score!.nextStep),
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 14,
                        color: AppColors.textDark.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Checkbox(
                          value: _questDone,
                          onChanged: (v) => _toggleQuest(v ?? false),
                          activeColor: AppColors.orange,
                        ),
                        Expanded(
                          child: Text(
                            _questDone
                                ? 'Квест дня выполнен: +1 мотивационный бонус.'
                                : 'Квест дня: выполните шаг выше, чтобы закрепить фундамент.',
                            style: GoogleFonts.alegreyaSans(
                              fontSize: 13,
                              color: AppColors.textDark.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
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
  const _FoundationHero({required this.score});
  final FoundationScore score;

  @override
  Widget build(BuildContext context) {
    final pct = (score.overallProgress * 100).round();
    const rows = [12, 10, 8, 6, 4];
    var filledLeft = score.filledBricks;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Text(
            'Фундамент благосостояния',
            style: GoogleFonts.alegreyaSans(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            '$pct% к вашей цели',
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              color: AppColors.textDark.withValues(alpha: 0.75),
            ),
          ),
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
          if (score.confidenceCap) ...[
            const SizedBox(height: 8),
            Text(
              score.userHint,
              textAlign: TextAlign.center,
              style: GoogleFonts.alegreyaSans(
                fontSize: 12,
                color: AppColors.textDark.withValues(alpha: 0.65),
              ),
            ),
          ],
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
            sphere.id == 'consistency'
                ? 'Регулярность: ${(sphere.current * 100).round()}% активных дней'
                : 'Текущее: ${sphere.current.toStringAsFixed(1)} / Цель: ${sphere.target.toStringAsFixed(1)} • вес x${sphere.weight.toStringAsFixed(1)}',
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
  const _HistoryStrip({required this.history});
  final List<int> history;

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();
    final maxVal = history.reduce((a, b) => a > b ? a : b).toDouble().clamp(1.0, 40.0);
    return Container(
      padding: const EdgeInsets.all(12),
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
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textDark,
            ),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 34,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: history
                  .map(
                    (v) => Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 0.5),
                        child: Container(
                          height: ((v / maxVal) * 30).clamp(2.0, 30.0),
                          decoration: BoxDecoration(
                            color: AppColors.orange.withValues(alpha: 0.75),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }
}
