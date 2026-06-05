import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/calendar_entry.dart';
import '../models/note_item.dart';
import '../models/state_entries.dart';
import 'auth_service.dart';
import 'calendar_storage.dart';
import 'firestore_repository.dart';
import 'notes_storage.dart';
import 'secure_kv_service.dart';
import 'session_data_cache.dart';
import 'state_storage.dart';
import 'user_storage_keys.dart';

/// Генерация тестовых данных прервана (выход из аккаунта или [cancelInFlight]).
class DevDataSeedCancelledException implements Exception {
  const DevDataSeedCancelledException();
}

class DevDataSeedService {
  DevDataSeedService._();
  static final DevDataSeedService instance = DevDataSeedService._();

  bool _cancelRequested = false;

  /// Прервать долгую генерацию (вызывается при [AuthService.logout]).
  void cancelInFlight() => _cancelRequested = true;

  Future<void> _beginGeneration() async {
    _cancelRequested = false;
    await _ensureSessionActive();
  }

  Future<void> _ensureSessionActive() async {
    if (_cancelRequested) throw const DevDataSeedCancelledException();
    final uid = await AuthService.instance.sessionUserId();
    if (uid == null || uid.isEmpty) {
      throw const DevDataSeedCancelledException();
    }
  }

  /// Генерация позитивного сценария на 90 дней назад.
  Future<int> generatePositive90Days() async {
    await _beginGeneration();
    return _generate90Days(positive: true);
  }

  /// Генерация негативного сценария на 90 дней назад.
  Future<int> generateNegative90Days() async {
    await _beginGeneration();
    return _generate90Days(positive: false);
  }

  /// Генерация смешанного сценария (волны) на 90 дней назад.
  Future<int> generateMixed90Days() async {
    await _beginGeneration();
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
      await _ensureSessionActive();
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
              meetingDate: _upcomingMeetingDate(random),
              note: positive
                  ? 'Позитивный сценарий для проверки стабильных рекомендаций'
                  : 'Негативный сценарий для проверки адаптивных рекомендаций',
            ),
          );
          calendarKeys.add(appKey);
          created++;
        }
      }

      final emoKey = 'EmotionsEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(emoKey) && random.nextDouble() < 0.12) {
        await StateStorage.instance.save(
          EmotionsEntry(
            createdAt: d.add(Duration(hours: 11 + random.nextInt(8))),
            emotions: positive
                ? ['радость', 'спокойствие', 'интерес']
                : ['тревога', 'усталость', 'напряжение'],
          ),
        );
        stateKeys.add(emoKey);
        created++;
      }

      final nutKey = 'NutritionEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(nutKey) && random.nextDouble() < 0.08) {
        await StateStorage.instance.save(
          NutritionEntry(
            createdAt: d.add(const Duration(hours: 13, minutes: 20)),
            meals: positive ? const ['завтрак', 'обед'] : const ['перекусы'],
            snackCount: positive ? random.nextInt(3) : 2 + random.nextInt(4),
            sensations: positive ? const ['лёгкость'] : const ['тяжесть', 'перегруз'],
            emotionalConnection: positive ? const ['спокойствие'] : const ['тревога'],
          ),
        );
        stateKeys.add(nutKey);
        created++;
      }
    }

    generatedNotes.sort((a, b) => b.date.compareTo(a.date));
    await NotesStorage.instance.saveAll(generatedNotes);
    created += await _seedFutureMedicationsForProfile(random, positive: positive);
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
    final existingCalendar = await CalendarStorage.instance.loadAll();
    final calendarKeys = existingCalendar
        .map((c) => '${c.runtimeType}:${c.date.year}-${c.date.month}-${c.date.day}')
        .toSet();

    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      await _ensureSessionActive();
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

      if (random.nextDouble() < 0.2) {
        final medKey = 'Medication:${d.year}-${d.month}-${d.day}';
        if (!calendarKeys.contains(medKey)) {
          final id = 'seed-mix-med-${d.millisecondsSinceEpoch}-${random.nextInt(9999)}';
          await CalendarStorage.instance.save(
            Medication(
              id: id,
              date: d,
              time: const TimeOfDay(hour: 8, minute: 0),
              name: positive ? 'Поддерживающий препарат' : 'Корректирующая терапия',
              dosage: '${random.nextInt(2) + 1} таб',
              schedule: [
                MedicationDose(time: const TimeOfDay(hour: 8, minute: 0), amount: '1'),
              ],
            ),
          );
          calendarKeys.add(medKey);
          created++;
        }
      }

      if (random.nextDouble() < 0.12) {
        final appKey = 'Appointment:${d.year}-${d.month}-${d.day}';
        if (!calendarKeys.contains(appKey)) {
          final id = 'seed-mix-app-${d.millisecondsSinceEpoch}-${random.nextInt(9999)}';
          await CalendarStorage.instance.save(
            Appointment(
              id: id,
              date: d,
              time: TimeOfDay(hour: 10 + random.nextInt(7), minute: 0),
              title: positive ? 'Контрольный визит' : 'Внеплановый прием',
              meetingDate: _upcomingMeetingDate(random),
              note: 'Смешанный сценарий для теста календарной аналитики',
            ),
          );
          calendarKeys.add(appKey);
          created++;
        }
      }

      final emoKey = 'EmotionsEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(emoKey) && random.nextDouble() < 0.11) {
        await StateStorage.instance.save(
          EmotionsEntry(
            createdAt: d.add(Duration(hours: 10 + random.nextInt(9))),
            emotions: positive
                ? ['радость', 'спокойствие']
                : ['тревога', 'раздражение', 'усталость'],
          ),
        );
        stateKeys.add(emoKey);
        created++;
      }

      final nutKey = 'NutritionEntry:${d.year}-${d.month}-${d.day}';
      if (!stateKeys.contains(nutKey) && random.nextDouble() < 0.07) {
        await StateStorage.instance.save(
          NutritionEntry(
            createdAt: d.add(const Duration(hours: 12, minutes: 45)),
            meals: positive ? const ['обед'] : const ['перекусы', 'кофе'],
            snackCount: positive ? random.nextInt(2) : 3 + random.nextInt(3),
            sensations: const ['сытость'],
            emotionalConnection: positive ? const [] : const ['стресс'],
          ),
        );
        stateKeys.add(nutKey);
        created++;
      }
    }

    generatedNotes.sort((a, b) => b.date.compareTo(a.date));
    await NotesStorage.instance.saveAll(generatedNotes);
    created += await _seedFutureMedicationsForProfile(random, mixed: true);
    return created;
  }

  /// Строки календаря «приём» только в прошлом не видны в профиле и в карточке «Таблетки»
  /// на статистике (там учитываются даты не раньше сегодня). Дублируем типовые препараты
  /// сценария на ближайшие дни, чтобы те же названия попали в эти экраны.
  Future<int> _seedFutureMedicationsForProfile(
    Random random, {
    bool positive = true,
    bool mixed = false,
  }) async {
    final List<({String name, String seriesId, String dosage})> drugs;
    if (mixed) {
      drugs = [
        (
          name: 'Поддерживающий препарат',
          seriesId: 'seed-active-support',
          dosage: '${random.nextInt(2) + 1} таб',
        ),
        (
          name: 'Корректирующая терапия',
          seriesId: 'seed-active-correct',
          dosage: '${random.nextInt(2) + 1} таб',
        ),
      ];
    } else if (positive) {
      drugs = [
        (
          name: 'Витаминный комплекс 1',
          seriesId: 'seed-active-vit1',
          dosage: '${random.nextInt(2) + 1} капс',
        ),
        (
          name: 'Витаминный комплекс 2',
          seriesId: 'seed-active-vit2',
          dosage: '${random.nextInt(2) + 1} капс',
        ),
      ];
    } else {
      drugs = [
        (
          name: 'Терапия 1',
          seriesId: 'seed-active-th1',
          dosage: '${random.nextInt(2) + 1} таб',
        ),
        (
          name: 'Терапия 2',
          seriesId: 'seed-active-th2',
          dosage: '${random.nextInt(2) + 1} таб',
        ),
      ];
    }

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const horizonDays = 21;
    var added = 0;

    for (var dayOffset = 0; dayOffset < horizonDays; dayOffset++) {
      await _ensureSessionActive();
      final d = today.add(Duration(days: dayOffset));
      for (final drug in drugs) {
        final id = 'seed-profile-${drug.seriesId}-${d.year}-${d.month}-${d.day}';
        await CalendarStorage.instance.save(
          Medication(
            id: id,
            seriesId: drug.seriesId,
            date: d,
            time: TimeOfDay(hour: 8 + random.nextInt(3), minute: random.nextBool() ? 0 : 30),
            name: drug.name,
            dosage: drug.dosage,
            schedule: [
              MedicationDose(
                time: const TimeOfDay(hour: 8, minute: 0),
                amount: '1',
              ),
            ],
          ),
        );
        added++;
      }
    }
    return added;
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

  /// Дата визита в будущем — иначе совет «врач» по гейту не срабатывает.
  static DateTime _upcomingMeetingDate(Random random) {
    final t0 = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    return t0.add(Duration(days: 2 + random.nextInt(28)));
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

  /// Удаляет все локальные данные приложения для [userId] (заметки, календарь, профиль, метрики и т.д.).
  /// Не трогает реестр аккаунтов и пароль — это делает [AuthService.deleteAccount].
  Future<void> wipeScopedDataForUser(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    for (final base in UserStorageKeys.allScopedBases) {
      final scoped = UserStorageKeys.forUser(userId, base);
      await SecureKvService.instance.delete(scoped);
      await prefs.remove(scoped);
    }
  }

  /// Полный сброс данных текущей сессии (локально + облако), без удаления аккаунта.
  Future<void> wipeAllData() async {
    final uid = await AuthService.instance.sessionUserId();
    if (uid == null) return;
    await wipeScopedDataForUser(uid);
    SessionDataCache.clear();
    await FirestoreRepository.instance.wipeSyncedContent();
  }
}
