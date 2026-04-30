class LocalQualityMetrics {
  const LocalQualityMetrics({
    this.precisionAtK = 0,
    this.acceptanceRate = 0,
    this.followThroughRate = 0,
    this.outcomeDelta7d = 0,
    this.calibrationError = 0,
    this.insightStability = 1,
    this.coverage = 0,
    this.totalRated = 0,
    this.offlineValidationScore = 0,
    this.offlineValidationCases = 0,
  });

  final double precisionAtK;
  final double acceptanceRate;
  final double followThroughRate;
  final double outcomeDelta7d;
  final double calibrationError;
  final double insightStability;
  final double coverage;
  final int totalRated;
  final double offlineValidationScore;
  final int offlineValidationCases;
}
