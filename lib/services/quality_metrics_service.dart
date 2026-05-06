import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregated_data.dart';
import '../models/insight_result.dart';
import '../models/local_quality_metrics.dart';
import '../models/state_entries.dart';

class QualityMetricsService {
  QualityMetricsService._();
  static final QualityMetricsService instance = QualityMetricsService._();

  static const _keyInsightEvents = 'qm_insight_events_v1';
  static const _keyRecFeedback = 'qm_rec_feedback_v1';
  static const _keyOfflineValidation = 'qm_offline_validation_v1';

  Future<void> registerInsightShown(InsightResult insight, AggregatedData data) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await _loadListMap(prefs, _keyInsightEvents);
    events.add({
      'ts': DateTime.now().toIso8601String(),
      'confidence': insight.confidence,
      'insufficientData': insight.insufficientData,
      'recommendations': insight.recommendations,
      'avgMood': _avgMood(data),
      'avgSleep': _avgSleep(data),
      'avgEnergy': _avgEnergy(data),
      'stateSummary': insight.stateSummary,
    });
    await _saveTrimmed(prefs, _keyInsightEvents, events, 120);
  }

  Future<void> registerRecommendationFeedback({
    required String recommendation,
    required bool helpful,
    required bool accepted,
    String? recommendationVariantKey,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final fb = await _loadListMap(prefs, _keyRecFeedback);
    fb.add({
      'ts': DateTime.now().toIso8601String(),
      'recommendation': recommendation,
      'helpful': helpful,
      'accepted': accepted,
      if (recommendationVariantKey != null && recommendationVariantKey.isNotEmpty)
        'variantKey': recommendationVariantKey,
    });
    await _saveTrimmed(prefs, _keyRecFeedback, fb, 300);
  }

  /// Смещение выбора варианта формулировки: положительное — чаще помечали «полезно».
  Future<double> recommendationVariantBias(String variantKey) async {
    final prefs = await SharedPreferences.getInstance();
    final fb = await _loadListMap(prefs, _keyRecFeedback);
    final subset = fb.where((e) => '${e['variantKey']}' == variantKey).toList();
    if (subset.length < 2) return 0.0;
    final helpful = subset.where((e) => e['helpful'] == true).length / subset.length;
    return ((helpful - 0.5) * 0.45).clamp(-0.22, 0.22);
  }

  Future<LocalQualityMetrics> getMetrics() async {
    final prefs = await SharedPreferences.getInstance();
    final events = await _loadListMap(prefs, _keyInsightEvents);
    final fb = await _loadListMap(prefs, _keyRecFeedback);
    if (events.isEmpty) return const LocalQualityMetrics();

    final helpful = fb.where((e) => e['helpful'] == true).length;
    final accepted = fb.where((e) => e['accepted'] == true).length;
    final precisionAtK = fb.isEmpty ? 0.0 : helpful / fb.length;
    final acceptanceRate = fb.isEmpty ? 0.0 : accepted / fb.length;
    final followThroughRate = _computeFollowThrough(events, fb);
    final delta7d = _computeOutcomeDelta7d(events);
    final calibrationError = _computeCalibrationError(events, fb);
    final insightStability = _computeInsightStability(events);
    final coverage = _computeCoverage(events);

    final offlineRaw = prefs.getString(_keyOfflineValidation);
    double offlineScore = 0;
    int offlineCases = 0;
    if (offlineRaw != null) {
      try {
        final m = Map<String, dynamic>.from(jsonDecode(offlineRaw) as Map);
        offlineScore = _num(m['score']);
        offlineCases = (m['cases'] as num?)?.toInt() ?? 0;
      } catch (_) {}
    }

    return LocalQualityMetrics(
      precisionAtK: precisionAtK.clamp(0.0, 1.0),
      acceptanceRate: acceptanceRate.clamp(0.0, 1.0),
      followThroughRate: followThroughRate.clamp(0.0, 1.0),
      outcomeDelta7d: delta7d.clamp(-1.0, 1.0),
      calibrationError: calibrationError.clamp(0.0, 1.0),
      insightStability: insightStability.clamp(0.0, 1.0),
      coverage: coverage.clamp(0.0, 1.0),
      totalRated: fb.length,
      offlineValidationScore: offlineScore,
      offlineValidationCases: offlineCases,
    );
  }

  Future<void> saveOfflineValidation({
    required double score,
    required int cases,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyOfflineValidation, jsonEncode({
      'score': score,
      'cases': cases,
      'ts': DateTime.now().toIso8601String(),
    }));
  }

  /// Множитель ранга совета по истории helpful/accepted для похожих текстов (без роста сети).
  Future<double> recommendationScoreMultiplier(String recommendation) async {
    final prefs = await SharedPreferences.getInstance();
    final fb = await _loadListMap(prefs, _keyRecFeedback);
    if (fb.length < 6) return 1.0;
    final needle = recommendation.length > 18 ? recommendation.substring(0, 18) : recommendation;
    if (needle.length < 8) return 1.0;
    final similar = fb.where((e) {
      final t = '${e['recommendation']}';
      return t.startsWith(needle.substring(0, 8));
    }).toList();
    if (similar.length < 3) return 1.0;
    final helpful = similar.where((e) => e['helpful'] == true).length;
    final accepted = similar.where((e) => e['accepted'] == true).length;
    final n = similar.length.toDouble();
    final rate = (0.55 * (helpful / n) + 0.45 * (accepted / n)).clamp(0.0, 1.0);
    return (0.86 + 0.28 * rate).clamp(0.82, 1.18);
  }

  Future<double> calibrateConfidence(double rawConfidence) async {
    final prefs = await SharedPreferences.getInstance();
    final fb = await _loadListMap(prefs, _keyRecFeedback);
    if (fb.length < 8) return rawConfidence;

    final helpfulRate = fb.where((f) => f['helpful'] == true).length / fb.length;
    // Temperature-like shrink/expand toward empirical helpfulness.
    final temperature = helpfulRate >= 0.5 ? 0.9 : 1.15;
    final centered = (rawConfidence - 0.5) / temperature + 0.5;
    final blended = 0.7 * centered + 0.3 * helpfulRate;
    return blended.clamp(0.0, 1.0);
  }

  Future<List<Map<String, dynamic>>> _loadListMap(
    SharedPreferences prefs,
    String key,
  ) async {
    final raw = prefs.getString(key);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = (jsonDecode(raw) as List<dynamic>);
      return list.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _saveTrimmed(
    SharedPreferences prefs,
    String key,
    List<Map<String, dynamic>> values,
    int keepLast,
  ) async {
    final trimmed = values.length <= keepLast
        ? values
        : values.sublist(values.length - keepLast);
    await prefs.setString(key, jsonEncode(trimmed));
  }

  double _avgMood(AggregatedData d) {
    final m = d.stateEntries.whereType<MoodEntry>().map((e) => e.value).toList();
    if (m.isEmpty) return 5;
    return m.reduce((a, b) => a + b) / m.length;
  }

  double _avgSleep(AggregatedData d) {
    final m = d.stateEntries.whereType<SleepEntry>().map((e) => e.quality).toList();
    if (m.isEmpty) return 5;
    return m.reduce((a, b) => a + b) / m.length;
  }

  double _avgEnergy(AggregatedData d) {
    final m = d.stateEntries.whereType<EnergyEntry>().map((e) => e.level).toList();
    if (m.isEmpty) return 5;
    return m.reduce((a, b) => a + b) / m.length;
  }

  double _computeOutcomeDelta7d(List<Map<String, dynamic>> events) {
    if (events.length < 2) return 0;
    final now = DateTime.now();
    final recent = events.where((e) {
      final ts = DateTime.tryParse('${e['ts']}');
      return ts != null && now.difference(ts).inDays <= 7;
    }).toList();
    if (recent.length < 2) return 0;
    final first = recent.first;
    final last = recent.last;
    final firstScore = ((_num(first['avgMood']) + _num(first['avgSleep']) + _num(first['avgEnergy'])) / 3) / 10;
    final lastScore = ((_num(last['avgMood']) + _num(last['avgSleep']) + _num(last['avgEnergy'])) / 3) / 10;
    return lastScore - firstScore;
  }

  double _computeCalibrationError(
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> feedback,
  ) {
    if (events.isEmpty || feedback.isEmpty) return 0.5;
    final conf = events.map((e) => _num(e['confidence'])).reduce((a, b) => a + b) / events.length;
    final helpfulRate = feedback.where((f) => f['helpful'] == true).length / feedback.length;
    return (conf - helpfulRate).abs();
  }

  double _computeInsightStability(List<Map<String, dynamic>> events) {
    if (events.length < 3) return 1;
    final tail = events.length > 12 ? events.sublist(events.length - 12) : events;
    var changes = 0;
    for (var i = 1; i < tail.length; i++) {
      final prev = '${tail[i - 1]['stateSummary']}';
      final next = '${tail[i]['stateSummary']}';
      if (prev != next) changes++;
    }
    return (1 - changes / (tail.length - 1)).clamp(0.0, 1.0);
  }

  double _computeCoverage(List<Map<String, dynamic>> events) {
    if (events.isEmpty) return 0;
    final meaningful = events.where((e) => e['insufficientData'] != true).length;
    return meaningful / events.length;
  }

  double _computeFollowThrough(
    List<Map<String, dynamic>> events,
    List<Map<String, dynamic>> feedback,
  ) {
    final accepted = feedback.where((f) => f['accepted'] == true).toList();
    if (accepted.isEmpty || events.length < 2) return 0;
    var improved = 0;
    for (final f in accepted) {
      final ts = DateTime.tryParse('${f['ts']}');
      if (ts == null) continue;
      final before = _nearestEvent(events, ts.subtract(const Duration(hours: 6)));
      final after = _nearestEvent(events, ts.add(const Duration(days: 2)));
      if (before == null || after == null) continue;
      final beforeScore = ((_num(before['avgMood']) + _num(before['avgSleep']) + _num(before['avgEnergy'])) / 3);
      final afterScore = ((_num(after['avgMood']) + _num(after['avgSleep']) + _num(after['avgEnergy'])) / 3);
      if (afterScore >= beforeScore + 0.2) improved++;
    }
    return improved / accepted.length;
  }

  Map<String, dynamic>? _nearestEvent(List<Map<String, dynamic>> events, DateTime ts) {
    Map<String, dynamic>? best;
    var bestDiff = 1 << 30;
    for (final e in events) {
      final t = DateTime.tryParse('${e['ts']}');
      if (t == null) continue;
      final diff = t.difference(ts).inMinutes.abs();
      if (diff < bestDiff) {
        bestDiff = diff;
        best = e;
      }
    }
    return best;
  }

  double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
}
