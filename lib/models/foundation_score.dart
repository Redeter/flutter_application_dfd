import 'foundation_sphere.dart';

class FoundationHistoryDayDetail {
  const FoundationHistoryDayDetail({
    required this.windowEndDay,
    required this.bricks,
    required this.stateCount,
    required this.calendarCount,
    required this.dailyScorePercent,
  });

  final DateTime windowEndDay;
  final int bricks;
  final int stateCount;
  final int calendarCount;

  /// Дневной прогресс по активным сферам, %.
  final int dailyScorePercent;
}

class FoundationScore {
  const FoundationScore({
    required this.totalBricks,
    required this.filledBricks,
    required this.overallProgress,
    required this.rawOverallProgress,
    required this.spheres,
    required this.nextStep,
    required this.nextStepSphereId,
    required this.brickDelta7d,
    required this.riskCracks,
    required this.riskCracksExplanation,
    required this.history30d,
    required this.historyDayDetails,
    required this.confidenceCap,
    required this.userHint,
    required this.dataSourcesSummary,
    required this.missionTitle,
    required this.missionBody,
    required this.weeklyFocusTitle,
    required this.weeklyFocusSubtitle,
    required this.medicationAdherenceRate,
    required this.medicationAdherenceCaption,
    required this.statsPeriodCaption,
  });

  final int totalBricks;
  final int filledBricks;

  /// Отображаемый прогресс (после сглаживания в [FoundationService.applyDisplaySmoothing]).
  final double overallProgress;

  /// Сырой взвешенный прогресс до сглаживания.
  final double rawOverallProgress;

  final List<FoundationSphereScore> spheres;
  final String nextStep;

  /// Сфера подсказки «шаг на сегодня».
  final String nextStepSphereId;

  final int brickDelta7d;
  final int riskCracks;
  final String? riskCracksExplanation;
  final List<int> history30d;
  final List<FoundationHistoryDayDetail> historyDayDetails;
  final bool confidenceCap;
  final String userHint;
  final String dataSourcesSummary;
  final String missionTitle;
  final String missionBody;
  final String weeklyFocusTitle;
  final String weeklyFocusSubtitle;

  /// null — нет ожидаемых приёмов в данных.
  final double? medicationAdherenceRate;
  final String medicationAdherenceCaption;
  final String statsPeriodCaption;

  FoundationScore copyWithSmoothed({
    required double displayOverall,
    required int displayFilledBricks,
  }) {
    return FoundationScore(
      totalBricks: totalBricks,
      filledBricks: displayFilledBricks,
      overallProgress: displayOverall,
      rawOverallProgress: rawOverallProgress,
      spheres: spheres,
      nextStep: nextStep,
      nextStepSphereId: nextStepSphereId,
      brickDelta7d: brickDelta7d,
      riskCracks: riskCracks,
      riskCracksExplanation: riskCracksExplanation,
      history30d: history30d,
      historyDayDetails: historyDayDetails,
      confidenceCap: confidenceCap,
      userHint: userHint,
      dataSourcesSummary: dataSourcesSummary,
      missionTitle: missionTitle,
      missionBody: missionBody,
      weeklyFocusTitle: weeklyFocusTitle,
      weeklyFocusSubtitle: weeklyFocusSubtitle,
      medicationAdherenceRate: medicationAdherenceRate,
      medicationAdherenceCaption: medicationAdherenceCaption,
      statsPeriodCaption: statsPeriodCaption,
    );
  }
}

class FoundationSphereScore {
  const FoundationSphereScore({
    required this.id,
    required this.label,
    required this.target,
    required this.current,
    required this.progress,
    required this.priority,
    required this.brickContribution,
    required this.loggedToday,
    required this.detailLine,
    this.isConfigurable = true,
  });

  final String id;
  final String label;

  /// Целевое значение или число слотов (приёмы пищи / препараты).
  final double target;
  final double current;

  /// Прогресс за сегодня (0–1).
  final double progress;
  final int priority;
  final int brickContribution;
  final bool loggedToday;
  final String detailLine;

  /// false для «Приём препаратов» — цель из календаря.
  final bool isConfigurable;
}

class FoundationGoals {
  const FoundationGoals({
    this.sleepTarget = 7.5,
    this.moodTarget = 7.0,
    this.energyTarget = 7.0,
    this.snackTarget = 1,
    this.priorities = const FoundationSpherePriorities(),
  });

  static const mainMealsTarget = 3;

  final double sleepTarget;
  final double moodTarget;
  final double energyTarget;

  /// Целевое число перекусов в день (основные приёмы всегда 3).
  final int snackTarget;
  final FoundationSpherePriorities priorities;

  FoundationGoals copyWith({
    double? sleepTarget,
    double? moodTarget,
    double? energyTarget,
    int? snackTarget,
    FoundationSpherePriorities? priorities,
  }) {
    return FoundationGoals(
      sleepTarget: sleepTarget ?? this.sleepTarget,
      moodTarget: moodTarget ?? this.moodTarget,
      energyTarget: energyTarget ?? this.energyTarget,
      snackTarget: snackTarget ?? this.snackTarget,
      priorities: priorities ?? this.priorities,
    );
  }
}
