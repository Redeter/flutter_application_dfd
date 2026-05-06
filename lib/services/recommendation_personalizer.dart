import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/aggregated_data.dart';
import '../models/user_profile.dart';
import '../neural/recommendation_evidence.dart';
import 'quality_metrics_service.dart';

/// Слоты и персонализированные формулировки советов (локально, без LLM).
class RecommendationPersonalizer {
  RecommendationPersonalizer._();
  static final RecommendationPersonalizer instance = RecommendationPersonalizer._();

  static const _keyLastVariants = 'rec_personalizer_last_variants_v1';

  /// Стабильный id шаблона + индекс варианта (для метрик и анти-повтора).
  static String variantKey(String templateId, int variantIndex) => '$templateId:v$variantIndex';

  Future<PersonalizedRecommendation> render(
    String canonicalOrRewrittenRec,
    AggregatedData data,
    UserProfile profile,
  ) async {
    final stats = RecommendationSlotStats.compute(data);
    final id = _templateIdForText(canonicalOrRewrittenRec);
    if (id == null) {
      return PersonalizedRecommendation(
        text: canonicalOrRewrittenRec,
        variantKey: 'raw:${canonicalOrRewrittenRec.hashCode}',
        templateId: 'raw',
      );
    }

    final prefs = await SharedPreferences.getInstance();
    final nVariants = _variantCount(id);
    final basePick = await _selectVariantWithFeedback(id, stats, profile, nVariants);
    final adjusted = await _antiRepeatPick(prefs, id, basePick, nVariants);
    final key = variantKey(id, adjusted);

    final text = _buildText(id, adjusted, stats, profile, canonicalOrRewrittenRec);
    await _rememberShown(prefs, id, adjusted);

    return PersonalizedRecommendation(text: text, variantKey: key, templateId: id);
  }

  int _variantCount(String id) {
    return switch (id) {
      'sleep' => 4,
      'energy' => 4,
      'mood_notes' => 3,
      'mood' => 3,
      'meds' => 3,
      'doctor' => 3,
      'notes_regular' => 3,
      'default' => 2,
      _ => 1,
    };
  }

  Future<int> _selectVariantWithFeedback(
    String id,
    RecommendationSlotStats stats,
    UserProfile profile,
    int nVariants,
  ) async {
    if (nVariants <= 1) return 0;
    var bestI = 0;
    var bestW = -1e9;
    for (var i = 0; i < nVariants; i++) {
      final bias =
          await QualityMetricsService.instance.recommendationVariantBias(variantKey(id, i));
      final h = (Object.hash(
                id,
                stats.lowSleepDays,
                stats.tripleLowDays14,
                i,
                profile.conditions.map((e) => e.index).join(','),
              ) %
              1000) /
          1000.0;
      final w = h + bias;
      if (w > bestW) {
        bestW = w;
        bestI = i;
      }
    }
    return bestI;
  }

  Future<int> _antiRepeatPick(
    SharedPreferences prefs,
    String id,
    int basePick,
    int nVariants,
  ) async {
    if (nVariants <= 1) return 0;
    final last = await _loadLast(prefs);
    var pick = basePick;
    for (var attempt = 0; attempt < nVariants; attempt++) {
      final cand = (basePick + attempt) % nVariants;
      final recentSame = last.where((e) => e.startsWith('$id:v$cand')).length;
      if (recentSame < 2) {
        pick = cand;
        break;
      }
    }
    return pick;
  }

  Future<List<String>> _loadLast(SharedPreferences prefs) async {
    final raw = prefs.getString(_keyLastVariants);
    if (raw == null || raw.isEmpty) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list.map((e) => '$e').toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _rememberShown(SharedPreferences prefs, String id, int variant) async {
    final list = await _loadLast(prefs);
    list.add(variantKey(id, variant));
    final trimmed = list.length <= 24 ? list : list.sublist(list.length - 24);
    await prefs.setString(_keyLastVariants, jsonEncode(trimmed));
  }

  String? _templateIdForText(String rec) {
    final r = rec.toLowerCase();
    if (r.contains('ритм сна') ||
        r.contains('отбоя') ||
        r.contains('режим сна') ||
        r.contains('ложиться') ||
        (r.contains('сна') && (r.contains('время') || r.contains('улучш')))) {
      return 'sleep';
    }
    if (r.contains('энерг') &&
        (r.contains('прогул') || r.contains('перерыв') || r.contains('низк'))) {
      return 'energy';
    }
    if (r.contains('запись мыслей') && r.contains('замет')) return 'mood_notes';
    if (r.contains('настроен') && r.contains('замет')) return 'mood_notes';
    if (r.contains('настроен')) return 'mood';
    if (r.contains('препарат')) return 'meds';
    if (r.contains('врач')) return 'doctor';
    if (r.contains('регулярные заметки') || r.contains('отслеживать динамику')) return 'notes_regular';
    if (r.contains('замет')) return 'notes_regular';
    if (r.contains('продолжайте вести записи') || r.contains('система станет точнее')) return 'default';
    if (r.contains('короткие записи') && r.contains('недел')) return 'default';
    return null;
  }

  String _whenPhrase(RecommendationSlotStats stats) {
    if (stats.morningEntries >= stats.eveningEntries * 1.15 && stats.morningEntries >= 3) {
      return 'утром в первые часы бодрствования';
    }
    if (stats.eveningEntries >= stats.morningEntries * 1.15 && stats.eveningEntries >= 3) {
      return 'вечером, когда день уже отпустил';
    }
    return 'в то время суток, когда вам проще всего на 10–15 минут';
  }

  String _daysRu(int n) {
    if (n % 10 == 1 && n % 100 != 11) return '$n день';
    final m = n % 10;
    if (m >= 2 && m <= 4 && (n % 100 < 12 || n % 100 > 14)) return '$n дня';
    return '$n дней';
  }

  String _buildText(
    String id,
    int v,
    RecommendationSlotStats stats,
    UserProfile profile,
    String fallback,
  ) {
    final when = _whenPhrase(stats);
    final anx = profile.conditions.contains(MentalCondition.anxiety);
    final dep = profile.conditions.contains(MentalCondition.depression);

    String sleepStep(int i) => switch (i) {
          0 => 'зафиксировать одно и то же время отбоя на 3 дня',
          1 => 'сократить экран на час перед сном',
          2 => '10 минут спокойного растяжения перед сном',
          _ => 'мягко сдвинуть отбой на 15–20 минут раньше',
        };

    String energyStep(int i) => switch (i) {
          0 => 'короткую прогулку 8–12 минут',
          1 => 'лёгкую разминку у окна',
          2 => 'один «микро-перерыв» без экрана каждые 90 минут',
          _ => 'один короткий выход на свежий воздух',
        };

    switch (id) {
      case 'sleep':
        final n = stats.lowSleepDays.clamp(0, 14);
        final t = stats.sleepThresholdDisplay;
        final step = sleepStep(v);
        return switch (v % 4) {
          0 =>
            'За последние 14 дней ${_daysRu(n)} со сном ниже $t/10 — попробуйте $step $when. Это не диагноз, а наблюдение по вашим отметкам.',
          1 =>
            'По вашим данным за две недели: ${_daysRu(n)} со сном слабее $t/10. Мягкий шаг — $step; всё хранится только на устройстве.',
          2 =>
            'Сон по отметкам: ${_daysRu(n)} ниже $t/10 за 14 дней. Можно начать с: $step ($when).',
          _ =>
            'За 14 дней видно ${_daysRu(n)} со сном ниже $t/10. Попробуйте $step — это наблюдение, не назначение.',
        };
      case 'energy':
        final n = stats.lowEnergyDays.clamp(0, 14);
        final t = stats.energyThresholdDisplay;
        final step = energyStep(v);
        final extra = anx ? ' Если нарастает тревога, сократите шаг до 5 минут.' : '';
        return switch (v % 4) {
          0 =>
            'За 14 дней ${_daysRu(n)} с энергией ниже $t/10 — попробуйте $when сделать $step.$extra',
          1 =>
            'По вашим записям: ${_daysRu(n)} с низкой энергией (<$t/10). Небольшой шаг — $step.$extra',
          2 =>
            'Энергия по данным: ${_daysRu(n)} «слабых» дня за две недели. Подойдёт $step $when.$extra',
          _ =>
            'За последние две недели ${_daysRu(n)} с энергией ниже $t/10 — мягко введите $step.$extra',
        };
      case 'mood_notes':
        final nm = stats.lowMoodDays.clamp(0, 14);
        final nn = stats.notes14.clamp(0, 30);
        return switch (v % 3) {
          0 =>
            'За 14 дней ${_daysRu(nm)} с настроением ниже ${stats.moodThresholdDisplay}/10; заметок за период — $nn. Короткая запись 3–5 строк в день часто помогает увидеть паттерн — это не терапия.',
          1 =>
            'По отметкам: ${_daysRu(nm)} тяжёлых дня по настроению и $nn заметок за две недели. Попробуйте фиксировать факты без оценок «хорошо/плохо».',
          _ =>
            'Настроение: ${_daysRu(nm)} ниже ${stats.moodThresholdDisplay}/10 за 14 дней; заметок — $nn. Один шаблон в день («событие — ощущение — что помогло») уже даёт пользу.',
        };
      case 'mood':
        final n = stats.lowMoodDays.clamp(0, 14);
        final extra = dep ? ' Маленький шаг важнее масштаба.' : '';
        return switch (v % 3) {
          0 =>
            'За 14 дней ${_daysRu(n)} с настроением ниже ${stats.moodThresholdDisplay}/10 — это наблюдение по вашим данным, не вывод о здоровье.$extra',
          1 =>
            'По вашим отметкам за две недели: ${_daysRu(n)} дней со сниженным настроением — попробуйте один короткий контакт с поддержкой или прогулку $when.$extra',
          _ =>
            'Настроение по дням: ${_daysRu(n)} ниже ${stats.moodThresholdDisplay}/10 за 14 дней. Мягкий фокус — сон, движение и вода; это подсказки дневника.$extra',
        };
      case 'meds':
        return switch (v % 3) {
          0 => 'По календарю есть приём препаратов — отмечайте слоты, чтобы видеть связь с самочувствием (локально, без отправки данных).',
          1 => 'Активные напоминания по препаратам помогают не терять ритм; отметьте приём в приложении, когда сделали.',
          _ => 'Регулярность приёма проще отслеживать из одного места — используйте календарь и отметки «принято».',
        };
      case 'doctor':
        return switch (v % 3) {
          0 => 'В календаре есть визит — хороший повод коротко описать симптомы и сон за последние дни (это не медицинский совет приложения).',
          1 => 'Перед визитом к врачу можно выгрузить из заметок 3–5 фактов: сон, энергия, настроение — как вы их чувствуете.',
          _ => 'Запланированный визит — удобная точка, чтобы согласовать режим и переносимость; приложение лишь напоминает.',
        };
      case 'notes_regular':
        final td = stats.trackedDays.clamp(0, 14);
        return switch (v % 3) {
          0 =>
            'За 14 дней с записями — ${_daysRu(td)}; регулярные короткие отметки делают картину стабильнее. Это не оценка вас, а данные для вас.',
          1 =>
            'Сейчас ${_daysRu(td)} с активностью за две недели — если добавить 1–2 мини-заметки в «пустые» дни, тренды станут яснее.',
          _ =>
            'По охвату дней: ${_daysRu(td)} с записями за 14 дней. Даже одна строка «что было важным» вечером уже улучшает анализ.',
        };
      case 'default':
        return switch (v % 2) {
          0 => 'Продолжайте короткие отметки — по мере накопления дней подсказки станут точнее. Данные остаются на устройстве.',
          _ => 'Чем ровнее неделя записей, тем меньше «шума» в советах. Это дневник с подсказками, не клиника.',
        };
      default:
        return fallback;
    }
  }
}

class PersonalizedRecommendation {
  const PersonalizedRecommendation({
    required this.text,
    required this.variantKey,
    required this.templateId,
  });

  final String text;
  final String variantKey;
  final String templateId;
}
