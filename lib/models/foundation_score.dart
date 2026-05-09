class FoundationHistoryDayDetail {
  const FoundationHistoryDayDetail({
    required this.windowEndDay,
    required this.bricks,
    required this.notesCount,
    required this.stateCount,
    required this.calendarCount,
  });

  /// Конец 14‑дневного окна, по которому посчитан столбик истории.
  final DateTime windowEndDay;
  final int bricks;
  final int notesCount;
  final int stateCount;
  final int calendarCount;
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

  /// Сфера, от которой отталкивается текст [nextStep] (`sleep` / `mood` / `energy`).
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
    required this.confidence,
    required this.weight,
    required this.brickContribution,
    this.hasMetricSamples = true,
  });

  final String id;
  final String label;
  final double target;
  final double current;
  final double progress;
  final double confidence;
  final double weight;
  final int brickContribution;
  final bool hasMetricSamples;
}

class FoundationGoals {
  const FoundationGoals({
    this.sleepTarget = 7.5,
    this.moodTarget = 7.0,
    this.energyTarget = 7.0,
    this.sleepWeight = 1.0,
    this.moodWeight = 1.0,
    this.energyWeight = 1.0,
  });

  final double sleepTarget;
  final double moodTarget;
  final double energyTarget;
  final double sleepWeight;
  final double moodWeight;
  final double energyWeight;

  FoundationGoals copyWith({
    double? sleepTarget,
    double? moodTarget,
    double? energyTarget,
    double? sleepWeight,
    double? moodWeight,
    double? energyWeight,
  }) {
    return FoundationGoals(
      sleepTarget: sleepTarget ?? this.sleepTarget,
      moodTarget: moodTarget ?? this.moodTarget,
      energyTarget: energyTarget ?? this.energyTarget,
      sleepWeight: sleepWeight ?? this.sleepWeight,
      moodWeight: moodWeight ?? this.moodWeight,
      energyWeight: energyWeight ?? this.energyWeight,
    );
  }
}
