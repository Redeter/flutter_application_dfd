class FoundationScore {
  const FoundationScore({
    required this.totalBricks,
    required this.filledBricks,
    required this.overallProgress,
    required this.spheres,
    required this.nextStep,
    required this.brickDelta7d,
    required this.riskCracks,
    required this.history30d,
    required this.confidenceCap,
    required this.userHint,
  });

  final int totalBricks;
  final int filledBricks;
  final double overallProgress;
  final List<FoundationSphereScore> spheres;
  final String nextStep;
  final int brickDelta7d;
  final int riskCracks;
  final List<int> history30d;
  final bool confidenceCap;
  final String userHint;
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
  });

  final String id;
  final String label;
  final double target;
  final double current;
  final double progress;
  final double confidence;
  final double weight;
  final int brickContribution;
}

class FoundationGoals {
  const FoundationGoals({
    this.sleepTarget = 7.5,
    this.moodTarget = 7.0,
    this.energyTarget = 7.0,
    this.sleepWeight = 1.0,
    this.moodWeight = 1.0,
    this.energyWeight = 1.0,
    this.consistencyWeight = 0.7,
  });

  final double sleepTarget;
  final double moodTarget;
  final double energyTarget;
  final double sleepWeight;
  final double moodWeight;
  final double energyWeight;
  final double consistencyWeight;
}
