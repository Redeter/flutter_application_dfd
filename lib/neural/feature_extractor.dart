import '../models/aggregated_data.dart';
import '../models/state_entries.dart';
import 'text_analyzer.dart';

/// Извлекает числовые признаки из агрегированных данных для подачи в нейросеть.
/// Включает: понимание текста, динамику (тренды), контекст (связи сон↔настроение).
/// Признаки нормализованы в диапазон [0, 1] где применимо.
class FeatureExtractor {
  FeatureExtractor._();

  static const int featureCount = 33;

  /// Слова эмоциональной окраски для базового подсчёта.
  static const _emotionWords = {
    'хорошо', 'плохо', 'грустно', 'радость', 'рад', 'счастлив', 'счастье',
    'усталость', 'устал', 'устала', 'энергия', 'спокойствие', 'тревога',
    'страх', 'злость', 'раздражение', 'волнение', 'напряжение', 'сон',
    'бессонница', 'отдых', 'вымотан', 'мотивация', 'лень', 'апатия',
    'стресс', 'расслабление', 'медитация', 'спорт', 'прогулка',
  };

  /// Преобразует агрегированные данные в вектор признаков.
  static List<double> extract(AggregatedData data) {
    double? avgMood;
    double? avgSleep;
    double? avgEnergy;
    int moodCount = 0, sleepCount = 0, energyCount = 0;
    double moodSum = 0, sleepSum = 0, energySum = 0;
    final emotions = <String>[];
    int nutritionCount = 0;
    int totalSnacks = 0;
    int moodWeekdayLow = 0;
    int sleepMoodLink = 0;

    final moodByDate = <DateTime, int>{};
    final sleepByDate = <DateTime, int>{};
    final energyByDate = <DateTime, int>{};
    final entryTimes = <DateTime>[];

    for (final e in data.stateEntries) {
      switch (e) {
        case MoodEntry(:final value, :final createdAt):
          moodSum += value;
          moodCount++;
          moodByDate[_day(createdAt)] = value;
          entryTimes.add(createdAt);
        case EmotionsEntry(emotions: final ems):
          emotions.addAll(ems);
        case SleepEntry(:final quality, :final createdAt):
          sleepSum += quality;
          sleepCount++;
          sleepByDate[_day(createdAt)] = quality;
          entryTimes.add(createdAt);
        case EnergyEntry(:final level, :final createdAt):
          energySum += level;
          energyCount++;
          energyByDate[_day(createdAt)] = level;
          entryTimes.add(createdAt);
        case NutritionEntry(:final snackCount):
          nutritionCount++;
          totalSnacks += snackCount;
        default:
          break;
      }
    }

    if (moodCount > 0) avgMood = moodSum / moodCount;
    if (sleepCount > 0) avgSleep = sleepSum / sleepCount;
    if (energyCount > 0) avgEnergy = energySum / energyCount;

    final moodByWeekday = <int, List<int>>{};
    final sleepQualities = <double>[];
    final moodSameDay = <double>[];

    for (final e in data.stateEntries) {
      switch (e) {
        case MoodEntry(:final value, :final createdAt):
          moodByWeekday.putIfAbsent(createdAt.weekday, () => []).add(value);
        case SleepEntry(:final quality, :final createdAt):
          final day = _day(createdAt);
          for (final m in data.stateEntries) {
            if (m is MoodEntry) {
              if (_day(m.createdAt) == day) {
                sleepQualities.add(quality.toDouble());
                moodSameDay.add(m.value.toDouble());
                break;
              }
            }
          }
        default:
          break;
      }
    }

    if (moodByWeekday.isNotEmpty) {
      final weekdayAvgs = <int, double>{};
      for (final e in moodByWeekday.entries) {
        weekdayAvgs[e.key] = e.value.reduce((a, b) => a + b) / e.value.length;
      }
      final allMoods = moodByWeekday.values.expand((l) => l).toList();
      final overallAvg = allMoods.reduce((a, b) => a + b) / allMoods.length;
      final lowDays = weekdayAvgs.entries.where((e) => e.value < overallAvg - 0.5);
      if (lowDays.isNotEmpty) moodWeekdayLow = 1;
    }

    if (sleepQualities.length >= 3 && moodSameDay.length == sleepQualities.length) {
      var lowBoth = 0;
      for (var i = 0; i < sleepQualities.length; i++) {
        if (sleepQualities[i] < 6 && moodSameDay[i] < 6) lowBoth++;
      }
      if (lowBoth >= sleepQualities.length ~/ 2) sleepMoodLink = 1;
    }

    final allText = StringBuffer();
    for (final n in data.notes) {
      allText.writeln('${n.title} ${n.preview} ${n.tags.join(' ')}');
    }
    final textStr = allText.toString();
    final words = RegExp(r'[а-яёa-z]+', caseSensitive: false)
        .allMatches(textStr)
        .map((m) => m.group(0)!.toLowerCase())
        .toList();
    final totalWords = words.length;
    final emotionWordsInNotes = words.where((w) => _emotionWords.contains(w)).length;
    final emotionDensity = totalWords > 0 ? emotionWordsInNotes / totalWords : 0.0;

    final textFeatures = TextAnalyzer.analyze(textStr);

    final (moodSlope, sleepSlope, moodVolatility, improvingTrend) =
        _computeDynamics(moodByDate, sleepByDate, energyByDate);

    final (moodSleepInteraction, moodEnergyInteraction, daysBothLow) =
        _computeContext(avgMood, avgSleep, avgEnergy, sleepQualities, moodSameDay);

    final (
      mood7,
      mood14,
      mood30,
      sleep7,
      sleep14,
      sleep30,
      energy7,
      energy14,
      energy30,
    ) = _windowedAverages(data);

    final (morningRatio, eveningRatio, weekdayVariance, cadenceScore, gapScore) =
        _recordingPatternFeatures(entryTimes, data.notes);
    final sequenceQuality = _sequenceConsistency(moodByDate, sleepByDate, energyByDate);
    final baselineShift = _baselineShift(moodByDate);

    final now = DateTime.now();
    DateTime? earliest;
    for (final e in data.stateEntries) {
      final d = e.createdAt;
      if (earliest == null || d.isBefore(earliest)) earliest = d;
    }
    for (final n in data.notes) {
      if (earliest == null || n.date.isBefore(earliest)) earliest = n.date;
    }
    final daysOfData = earliest != null
        ? (now.difference(earliest).inDays + 1).clamp(0, 60) / 60.0
        : 0.0;

    final hasUpcoming = data.appointments.any((a) =>
        a.meetingDate != null && a.meetingDate!.isAfter(now));

    return [
      (avgMood ?? 5) / 10,
      (avgSleep ?? 5) / 10,
      (avgEnergy ?? 5) / 10,
      (moodCount / 30).clamp(0.0, 1.0),
      (sleepCount / 30).clamp(0.0, 1.0),
      (energyCount / 30).clamp(0.0, 1.0),
      (emotions.length / 20).clamp(0.0, 1.0),
      (data.notes.length / 20).clamp(0.0, 1.0),
      data.medications.isNotEmpty ? 1.0 : 0.0,
      hasUpcoming ? 1.0 : 0.0,
      moodWeekdayLow.toDouble(),
      sleepMoodLink.toDouble(),
      (totalSnacks / 10).clamp(0.0, 1.0),
      (nutritionCount / 15).clamp(0.0, 1.0),
      (textStr.length / 1000).clamp(0.0, 1.0),
      emotionDensity.clamp(0.0, 1.0),
      daysOfData,
      mood7,
      sleep7,
      energy7,
      emotions.isNotEmpty ? 1.0 : 0.0,
      data.notes.isEmpty && data.stateEntries.isEmpty ? 1.0 : 0.0,
      textFeatures[0],
      textFeatures[1],
      textFeatures[2],
      textFeatures[3],
      ((moodSlope + mood14 + mood30) / 3).clamp(0.0, 1.0),
      ((sleepSlope + sleep14 + sleep30) / 3).clamp(0.0, 1.0),
      ((moodVolatility + weekdayVariance) / 2).clamp(0.0, 1.0),
      ((improvingTrend + energy14 + energy30) / 3).clamp(0.0, 1.0),
      ((moodSleepInteraction + sequenceQuality) / 2).clamp(0.0, 1.0),
      ((moodEnergyInteraction + baselineShift) / 2).clamp(0.0, 1.0),
      ((daysBothLow + cadenceScore + gapScore + morningRatio + eveningRatio) / 5)
          .clamp(0.0, 1.0),
    ];
  }

  static (double, double, double, double, double, double, double, double, double)
      _windowedAverages(AggregatedData data) {
    final now = DateTime.now();
    double avgWindow<T extends StateEntryBase>(
      int days,
      bool Function(StateEntryBase e) test,
      int Function(StateEntryBase e) valueOf,
    ) {
      final from = now.subtract(Duration(days: days));
      final vals = data.stateEntries
          .where((e) => test(e) && !e.createdAt.isBefore(from))
          .map(valueOf)
          .toList();
      if (vals.isEmpty) return 0.5;
      return ((vals.reduce((a, b) => a + b) / vals.length) / 10).clamp(0.0, 1.0);
    }

    return (
      avgWindow(7, (e) => e is MoodEntry, (e) => (e as MoodEntry).value),
      avgWindow(14, (e) => e is MoodEntry, (e) => (e as MoodEntry).value),
      avgWindow(30, (e) => e is MoodEntry, (e) => (e as MoodEntry).value),
      avgWindow(7, (e) => e is SleepEntry, (e) => (e as SleepEntry).quality),
      avgWindow(14, (e) => e is SleepEntry, (e) => (e as SleepEntry).quality),
      avgWindow(30, (e) => e is SleepEntry, (e) => (e as SleepEntry).quality),
      avgWindow(7, (e) => e is EnergyEntry, (e) => (e as EnergyEntry).level),
      avgWindow(14, (e) => e is EnergyEntry, (e) => (e as EnergyEntry).level),
      avgWindow(30, (e) => e is EnergyEntry, (e) => (e as EnergyEntry).level),
    );
  }

  static (double, double, double, double, double) _recordingPatternFeatures(
    List<DateTime> entryTimes,
    List<dynamic> notes,
  ) {
    if (entryTimes.isEmpty) return (0.0, 0.0, 0.0, 0.0, 1.0);
    var morning = 0;
    var evening = 0;
    final byWeekday = <int, int>{};
    for (final t in entryTimes) {
      if (t.hour < 12) morning++;
      if (t.hour >= 18) evening++;
      byWeekday[t.weekday] = (byWeekday[t.weekday] ?? 0) + 1;
    }
    final total = entryTimes.length.toDouble();
    final morningRatio = (morning / total).clamp(0.0, 1.0);
    final eveningRatio = (evening / total).clamp(0.0, 1.0);
    final weekdayCounts = List.generate(7, (i) => (byWeekday[i + 1] ?? 0).toDouble());
    final mean = weekdayCounts.reduce((a, b) => a + b) / 7;
    final variance =
        weekdayCounts.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / 7;
    final weekdayVariance = (variance / 6).clamp(0.0, 1.0);

    final daysSet = entryTimes
        .map((t) => DateTime(t.year, t.month, t.day))
        .toSet()
        .toList()
      ..sort();
    final cadenceScore = (daysSet.length / 21).clamp(0.0, 1.0);
    var maxGap = 0;
    for (var i = 1; i < daysSet.length; i++) {
      final gap = daysSet[i].difference(daysSet[i - 1]).inDays;
      if (gap > maxGap) maxGap = gap;
    }
    final gapScore = (1 - (maxGap / 10)).clamp(0.0, 1.0);

    return (morningRatio, eveningRatio, weekdayVariance, cadenceScore, gapScore);
  }

  static double _sequenceConsistency(
    Map<DateTime, int> moodByDate,
    Map<DateTime, int> sleepByDate,
    Map<DateTime, int> energyByDate,
  ) {
    final days = moodByDate.keys.where((d) => sleepByDate.containsKey(d) && energyByDate.containsKey(d)).toList();
    if (days.length < 2) return 0.5;
    var aligned = 0;
    for (final d in days) {
      final mood = moodByDate[d]!;
      final sleep = sleepByDate[d]!;
      final energy = energyByDate[d]!;
      final lowAll = mood < 5 && sleep < 5 && energy < 5;
      final highAll = mood >= 7 && sleep >= 7 && energy >= 7;
      if (lowAll || highAll) aligned++;
    }
    return (aligned / days.length).clamp(0.0, 1.0);
  }

  static double _baselineShift(Map<DateTime, int> moodByDate) {
    if (moodByDate.length < 6) return 0.5;
    final days = moodByDate.keys.toList()..sort();
    final half = days.length ~/ 2;
    final first = days.take(half).map((d) => moodByDate[d]!).toList();
    final second = days.skip(half).map((d) => moodByDate[d]!).toList();
    final fAvg = first.reduce((a, b) => a + b) / first.length;
    final sAvg = second.reduce((a, b) => a + b) / second.length;
    return ((sAvg - fAvg).abs() / 10).clamp(0.0, 1.0);
  }

  static DateTime _day(DateTime d) =>
      DateTime(d.year, d.month, d.day);

  /// Тренды за последние 7 дней: slope (-1..1), volatility (0..1), improving (0..1).
  static (double, double, double, double) _computeDynamics(
    Map<DateTime, int> moodByDate,
    Map<DateTime, int> sleepByDate,
    Map<DateTime, int> energyByDate,
  ) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));

    final moodDays = moodByDate.keys
        .where((d) => !d.isBefore(weekAgo))
        .toList()
      ..sort();
    final sleepDays = sleepByDate.keys
        .where((d) => !d.isBefore(weekAgo))
        .toList()
      ..sort();
    final energyDays = energyByDate.keys
        .where((d) => !d.isBefore(weekAgo))
        .toList()
      ..sort();

    double slope(List<DateTime> days, Map<DateTime, int> values) {
      if (days.length < 2) return 0.0;
      final vals = days.map((d) => values[d]!.toDouble()).toList();
      var sumX = 0.0, sumY = 0.0, sumXY = 0.0, sumX2 = 0.0;
      for (var i = 0; i < vals.length; i++) {
        sumX += i;
        sumY += vals[i];
        sumXY += i * vals[i];
        sumX2 += i * i;
      }
      final n = vals.length.toDouble();
      final denom = n * sumX2 - sumX * sumX;
      if (denom.abs() < 1e-9) return 0.0;
      final s = (n * sumXY - sumX * sumY) / denom;
      return (s / 2).clamp(-1.0, 1.0);
    }

    double volatility(List<DateTime> days, Map<DateTime, int> values) {
      if (days.length < 2) return 0.0;
      final vals = days.map((d) => values[d]!.toDouble()).toList();
      final mean = vals.reduce((a, b) => a + b) / vals.length;
      final variance = vals.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) / vals.length;
      return (variance / 10).clamp(0.0, 1.0);
    }

    final moodSlopeRaw = slope(moodDays, moodByDate);
    final sleepSlopeRaw = slope(sleepDays, sleepByDate);
    final energySlopeRaw = slope(energyDays, energyByDate);
    final moodVol = volatility(moodDays, moodByDate);
    final improving = (moodSlopeRaw + sleepSlopeRaw + energySlopeRaw) / 3;
    final improvingNorm = (improving + 1) / 2;
    final moodSlopeNorm = (moodSlopeRaw + 1) / 2;
    final sleepSlopeNorm = (sleepSlopeRaw + 1) / 2;

    return (moodSlopeNorm, sleepSlopeNorm, moodVol, improvingNorm);
  }

  /// Контекст: связи настроение↔сон, настроение↔энергия, дни с обоими низкими.
  static (double, double, double) _computeContext(
    double? avgMood,
    double? avgSleep,
    double? avgEnergy,
    List<double> sleepQualities,
    List<double> moodSameDay,
  ) {
    final moodSleep = (avgMood != null && avgSleep != null)
        ? (avgMood * avgSleep / 100).clamp(0.0, 1.0)
        : 0.5;
    final moodEnergy = (avgMood != null && avgEnergy != null)
        ? (avgMood * avgEnergy / 100).clamp(0.0, 1.0)
        : 0.5;

    var bothLow = 0;
    if (sleepQualities.length >= 3 && moodSameDay.length == sleepQualities.length) {
      for (var i = 0; i < sleepQualities.length; i++) {
        if (sleepQualities[i] < 5 && moodSameDay[i] < 5) bothLow++;
      }
    }
    final daysBothLow = (bothLow / 7).clamp(0.0, 1.0);

    return (moodSleep, moodEnergy, daysBothLow);
  }
}
