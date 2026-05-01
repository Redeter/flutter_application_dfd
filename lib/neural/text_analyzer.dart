/// Анализ текста заметок: тональность и ключевые фразы.
/// Даёт нейросети понимание смысла, а не только длины текста.
class TextAnalyzer {
  TextAnalyzer._();

  /// Слова с валентностью: положительные +1, отрицательные -1, нейтральные 0.
  static const Map<String, double> _sentimentWords = {
    'хорошо': 0.7,
    'отлично': 0.9,
    'радость': 0.8,
    'рад': 0.7,
    'счастлив': 0.9,
    'счастье': 0.9,
    'энергия': 0.6,
    'спокойствие': 0.6,
    'расслабление': 0.5,
    'медитация': 0.4,
    'спорт': 0.5,
    'прогулка': 0.4,
    'отдых': 0.5,
    'отдохнул': 0.6,
    'благодарность': 0.7,
    'любовь': 0.8,
    'надежда': 0.6,
    'интерес': 0.5,
    //
    'плохо': -0.8,
    'ужасно': -0.9,
    'грустно': -0.7,
    'усталость': -0.6,
    'устал': -0.6,
    'устала': -0.6,
    'вымотан': -0.8,
    'тревога': -0.7,
    'тревожность': -0.7,
    'страх': -0.8,
    'злость': -0.7,
    'раздражение': -0.6,
    'волнение': -0.5,
    'напряжение': -0.6,
    'напряжён': -0.6,
    'бессонница': -0.8,
    'не спал': -0.7,
    'мотивация': -0.3,
    'лень': -0.5,
    'апатия': -0.7,
    'скука': -0.5,
    'разочарование': -0.7,
    'обида': -0.6,
    'одиночество': -0.7,
    'стресс': -0.7,
  };

  /// Ключевые фразы (биграммы) — контекст состояния.
  static const List<String> _keyPhrases = [
    'плохо спал',
    'не спал',
    'не выспался',
    'плохо спалось',
    'устал очень',
    'очень устал',
    'нет энергии',
    'нет сил',
    'плохое настроение',
    'настроение плохое',
    'грустно сегодня',
    'тревожно',
    'не могу уснуть',
    'бессонница',
    'хорошо выспался',
    'выспался хорошо',
    'бодрый',
    'много энергии',
    'отдохнул хорошо',
  ];

  /// Возвращает [sentiment (-1..1 в 0..1), negRatio, keyPhraseCount, textRichness].
  static List<double> analyze(String text) {
    final lower = text.toLowerCase();
    final words = RegExp(r'[а-яёa-z]+', caseSensitive: false)
        .allMatches(lower)
        .map((m) => m.group(0)!)
        .toList();

    var sentimentSum = 0.0;
    var negCount = 0;
    var posCount = 0;
    final seenWords = <String>{};

    for (final w in words) {
      final val = _sentimentWords[w];
      if (val != null) {
        sentimentSum += val;
        seenWords.add(w);
        if (val < 0) {
          negCount++;
        } else if (val > 0) {
          posCount++;
        }
      }
    }

    var phraseCount = 0;
    for (final phrase in _keyPhrases) {
      if (lower.contains(phrase)) phraseCount++;
    }

    final totalSentimentWords = posCount + negCount;
    final sentimentNorm = totalSentimentWords > 0
        ? (sentimentSum / totalSentimentWords + 1) / 2
        : 0.5;
    final negRatio = totalSentimentWords > 0
        ? negCount / totalSentimentWords
        : 0.0;
    final phraseNorm = (phraseCount / 5).clamp(0.0, 1.0);
    final richness = words.isNotEmpty
        ? (seenWords.length / words.length).clamp(0.0, 1.0)
        : 0.0;

    return [sentimentNorm, negRatio, phraseNorm, richness];
  }
}
