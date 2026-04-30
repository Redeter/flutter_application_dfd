import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_entry.dart';
import '../models/note_item.dart';
import '../models/state_entries.dart';
import 'calendar_storage.dart';
import 'notes_storage.dart';
import 'secure_kv_service.dart';
import 'state_storage.dart';

class DevDataSeedService {
  DevDataSeedService._();
  static final DevDataSeedService instance = DevDataSeedService._();

  /// Генерация позитивного сценария на 90 дней назад.
  Future<int> generatePositive90Days() async {
    return _generate90Days(positive: true);
  }

  /// Генерация негативного сценария на 90 дней назад.
  Future<int> generateNegative90Days() async {
    return _generate90Days(positive: false);
  }

  /// Генерация смешанного сценария (волны) на 90 дней назад.
  Future<int> generateMixed90Days() async {
    return _generate90DaysMixed();
  }

  Future<int> _generate90Days({required bool positive}) async {
    final random = Random(DateTime.now().microsecondsSinceEpoch);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));
    final end = DateTime(now.year, now.month, now.day);

    var created = 0;

    final existingNotes = await NotesStorage.instance.loadAll();
    final noteKeys = existingNotes
        .map((n) => '${n.date.year}-${n.date.month}-${n.date.day}:${n.title.toLowerCase()}')
        .toSet();
    final generatedNotes = <NoteItem>[...existingNotes];

    final existingStates = await StateStorage.instance.loadAll();
    final stateKeys = existingStates
        .map((s) => '${s.runtimeType}:${s.createdAt.year}-${s.createdAt.month}-${s.createdAt.day}')
        .toSet();

    final existingCalendar = await CalendarStorage.instance.loadAll();
    final calendarKeys = existingCalendar
        .map((c) => '${c.runtimeType}:${c.date.year}-${c.date.month}-${c.date.day}')
        .toSet();

    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final dayShift = random.nextInt(12) - 6;
      final base = positive ? 7 : 4;

      // mood
      final moodKey = 'MoodEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(moodKey)) {
        final mood = max(1, min(10, base + dayShift ~/ 2));
        await StateStorage.instance.save(
          MoodEntry(
            createdAt: d.add(Duration(hours: 9 + random.nextInt(4))),
            value: mood,
            factors: _uniqueFactors(random, mood, positive),
          ),
        );
        stateKeys.add(moodKey);
        created++;
      }

      // sleep
      final sleepKey = 'SleepEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(sleepKey) && random.nextDouble() < 0.92) {
        final sleep = max(1, min(10, base + random.nextInt(4) + (positive ? 0 : -2)));
        await StateStorage.instance.save(
          SleepEntry(
            createdAt: d.add(Duration(hours: 7 + random.nextInt(2))),
            quality: sleep,
            tags: _uniqueSleepTags(random, sleep, positive),
          ),
        );
        stateKeys.add(sleepKey);
        created++;
      }

      // energy
      final energyKey = 'EnergyEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(energyKey) && random.nextDouble() < 0.9) {
        final energy = max(1, min(10, base + random.nextInt(5) + (positive ? 0 : -2)));
        await StateStorage.instance.save(
          EnergyEntry(
            createdAt: d.add(Duration(hours: 14 + random.nextInt(4))),
            level: energy,
            factors: _uniqueEnergyFactors(random, energy, positive),
          ),
        );
        stateKeys.add(energyKey);
        created++;
      }

      // note
      if (random.nextDouble() < 0.8) {
        final title = _uniqueTitle(random, d, positive);
        final noteKey = '${d.year}-${d.month}-${d.day}:${title.toLowerCase()}';
        if (!noteKeys.contains(noteKey)) {
          final lowTone = !positive || random.nextDouble() < 0.2;
          generatedNotes.add(
            NoteItem(
              date: d.add(const Duration(hours: 20)),
              title: title,
              tags: _uniqueNoteTags(random, lowTone, positive),
              preview: _uniquePreview(random, lowTone, positive),
            ),
          );
          noteKeys.add(noteKey);
          created++;
        }
      }

      // calendar events
      if (random.nextDouble() < (positive ? 0.24 : 0.16)) {
        final medKey = 'Medication:${d.year}-${d.month}-${d.day}';
        if (!calendarKeys.contains(medKey)) {
          final id = 'seed-med-${d.millisecondsSinceEpoch}-${random.nextInt(9999)}';
          await CalendarStorage.instance.save(
            Medication(
              id: id,
              date: d,
              time: const TimeOfDay(hour: 8, minute: 0),
              name: positive ? 'Витаминный комплекс ${random.nextInt(7) + 1}' : 'Терапия ${random.nextInt(9) + 1}',
              dosage: positive ? '${random.nextInt(2) + 1} капс' : '${random.nextInt(2) + 1} таб',
              schedule: [
                MedicationDose(time: const TimeOfDay(hour: 8, minute: 0), amount: '${random.nextInt(2) + 1}'),
              ],
            ),
          );
          calendarKeys.add(medKey);
          created++;
        }
      }
      if (random.nextDouble() < (positive ? 0.1 : 0.14)) {
        final appKey = 'Appointment:${d.year}-${d.month}-${d.day}';
        if (!calendarKeys.contains(appKey)) {
          final id = 'seed-app-${d.millisecondsSinceEpoch}-${random.nextInt(9999)}';
          await CalendarStorage.instance.save(
            Appointment(
              id: id,
              date: d,
              time: TimeOfDay(hour: 10 + random.nextInt(8), minute: random.nextBool() ? 0 : 30),
              title: positive ? 'Плановый чек-ап' : 'Контроль состояния',
              meetingDate: d,
              note: positive
                  ? 'Позитивный сценарий для проверки стабильных рекомендаций'
                  : 'Негативный сценарий для проверки адаптивных рекомендаций',
            ),
          );
          calendarKeys.add(appKey);
          created++;
        }
      }
    }

    generatedNotes.sort((a, b) => b.date.compareTo(a.date));
    await NotesStorage.instance.saveAll(generatedNotes);
    return created;
  }

  Future<int> _generate90DaysMixed() async {
    final random = Random(DateTime.now().microsecondsSinceEpoch);
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(const Duration(days: 90));
    final end = DateTime(now.year, now.month, now.day);
    var created = 0;

    final existingNotes = await NotesStorage.instance.loadAll();
    final noteKeys = existingNotes
        .map((n) => '${n.date.year}-${n.date.month}-${n.date.day}:${n.title.toLowerCase()}')
        .toSet();
    final generatedNotes = <NoteItem>[...existingNotes];
    final existingStates = await StateStorage.instance.loadAll();
    final stateKeys = existingStates
        .map((s) => '${s.runtimeType}:${s.createdAt.year}-${s.createdAt.month}-${s.createdAt.day}')
        .toSet();

    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final dayIndex = d.difference(start).inDays;
      final phase = dayIndex % 30;
      final base = phase < 10 ? 7 : (phase < 20 ? 4 : 6);
      final positive = phase < 10 || phase >= 20;

      final moodKey = 'MoodEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(moodKey)) {
        final mood = max(1, min(10, base + random.nextInt(5) - 2));
        await StateStorage.instance.save(
          MoodEntry(
            createdAt: d.add(Duration(hours: 9 + random.nextInt(4))),
            value: mood,
            factors: _uniqueFactors(random, mood, positive),
          ),
        );
        stateKeys.add(moodKey);
        created++;
      }

      final sleepKey = 'SleepEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(sleepKey) && random.nextDouble() < 0.9) {
        final sleep = max(1, min(10, base + random.nextInt(4) - 1));
        await StateStorage.instance.save(
          SleepEntry(
            createdAt: d.add(Duration(hours: 7 + random.nextInt(3))),
            quality: sleep,
            tags: _uniqueSleepTags(random, sleep, positive),
          ),
        );
        stateKeys.add(sleepKey);
        created++;
      }

      final energyKey = 'EnergyEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(energyKey) && random.nextDouble() < 0.88) {
        final energy = max(1, min(10, base + random.nextInt(5) - 1));
        await StateStorage.instance.save(
          EnergyEntry(
            createdAt: d.add(Duration(hours: 13 + random.nextInt(5))),
            level: energy,
            factors: _uniqueEnergyFactors(random, energy, positive),
          ),
        );
        stateKeys.add(energyKey);
        created++;
      }

      if (random.nextDouble() < 0.78) {
        final title = _uniqueTitle(random, d, positive);
        final noteKey = '${d.year}-${d.month}-${d.day}:${title.toLowerCase()}';
        if (!noteKeys.contains(noteKey)) {
          final lowTone = !positive || random.nextDouble() < 0.35;
          generatedNotes.add(
            NoteItem(
              date: d.add(const Duration(hours: 20)),
              title: 'Смешанный: $title',
              tags: _uniqueNoteTags(random, lowTone, positive),
              preview: _uniquePreview(random, lowTone, positive),
            ),
          );
          noteKeys.add(noteKey);
          created++;
        }
      }
    }

    generatedNotes.sort((a, b) => b.date.compareTo(a.date));
    await NotesStorage.instance.saveAll(generatedNotes);
    return created;
  }

  List<String> _uniqueFactors(Random r, int mood, bool positive) {
    final pool = positive
        ? ['прогулка', 'сон', 'спорт', 'общение', 'фокус', 'планирование', 'отдых']
        : ['стресс', 'конфликт', 'перегрузка', 'недосып', 'тревога', 'усталость', 'шум'];
    pool.shuffle(r);
    return [
      if (mood < 5) pool.first else pool[1],
      pool[2],
    ];
  }

  List<String> _uniqueSleepTags(Random r, int sleep, bool positive) {
    final good = ['восстановление', 'глубокий сон', 'ранний отбой', 'без пробуждений'];
    final bad = ['плохо спал', 'частые пробуждения', 'поздний отбой', 'тяжелое утро'];
    final pool = (sleep >= 6 && positive) ? good : bad;
    pool.shuffle(r);
    return pool.take(2).toList();
  }

  List<String> _uniqueEnergyFactors(Random r, int energy, bool positive) {
    final hi = ['активность', 'режим', 'правильное питание', 'прогулка'];
    final lo = ['недосып', 'стресс', 'долгая работа', 'пропуск отдыха'];
    final pool = (energy >= 6 && positive) ? hi : lo;
    pool.shuffle(r);
    return pool.take(2).toList();
  }

  String _uniqueTitle(Random r, DateTime d, bool positive) {
    final templates = positive
        ? ['Стабильный день', 'Позитивный прогресс', 'День в ресурсе', 'Ровное состояние']
        : ['Сложный день', 'Низкий ресурс', 'День с перегрузкой', 'Нестабильное состояние'];
    return '${templates[r.nextInt(templates.length)]} ${d.day}.${d.month}';
  }

  List<String> _uniqueNoteTags(Random r, bool lowTone, bool positive) {
    final pool = lowTone
        ? ['стресс', 'сон', 'энергия', 'фокус', 'тревога']
        : (positive
            ? ['режим', 'прогресс', 'энергия', 'баланс', 'восстановление']
            : ['нагрузка', 'усталость', 'сон', 'эмоции', 'ритм']);
    pool.shuffle(r);
    return pool.take(2).toList();
  }

  String _uniquePreview(Random r, bool lowTone, bool positive) {
    final low = [
      'Сегодня устал, концентрация низкая, нужно восстановление.',
      'Был напряженный день, эмоции колебались, сон под вопросом.',
      'Энергии мало, в течение дня чувствовал перегрузку.',
      'Тревожность выше обычного, вечером сложнее расслабиться.',
    ];
    final high = [
      'День прошел ровно, режим помог удержать стабильное состояние.',
      'Чувствовал ресурс, помогли прогулка и четкий план.',
      'Состояние спокойное, энергия держалась в течение дня.',
      'Хорошо восстановился, заметно легче фокусироваться.',
    ];
    final pool = lowTone ? low : high;
    return pool[r.nextInt(pool.length)];
  }

  /// Полный сброс всех локальных данных, метрик и модели.
  Future<void> wipeAllData() async {
    const keys = <String>[
      'notes',
      'state_entries',
      'calendar_entries',
      'neural_insights_model',
      'neural_insights_trained',
      'neural_insights_version',
      'neural_last_retrain_count',
      'local_insights_patterns',
      'qm_insight_events_v1',
      'qm_rec_feedback_v1',
      'qm_offline_validation_v1',
      'insights_ab_mode',
      'insights_ab_updated_at',
      'insights_ab_manual_mode',
    ];
    final prefs = await SharedPreferences.getInstance();
    for (final key in keys) {
      await SecureKvService.instance.delete(key);
      await prefs.remove(key);
    }
  }
}
