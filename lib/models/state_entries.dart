import 'package:flutter/material.dart';

/// Категории данных о состоянии пользователя.
enum StateCategory { mood, emotions, sleep, nutrition, energy }

/// Базовая запись состояния с датой.
abstract class StateEntryBase {
  StateEntryBase({required this.createdAt});

  final DateTime createdAt;
  StateCategory get category;

  Map<String, dynamic> toJson();
}

/// Запись настроения: 1–10 + факторы влияния.
class MoodEntry extends StateEntryBase {
  MoodEntry({
    required super.createdAt,
    required this.value,
    this.factors = const [],
  });

  final int value;
  final List<String> factors;

  @override
  StateCategory get category => StateCategory.mood;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'mood',
        'createdAt': createdAt.toIso8601String(),
        'value': value,
        'factors': factors,
      };

  static MoodEntry? fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'mood') return null;
    return MoodEntry(
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      value: (json['value'] as num?)?.toInt() ?? 5,
      factors: (json['factors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Запись эмоций: выбранные эмоции.
class EmotionsEntry extends StateEntryBase {
  EmotionsEntry({
    required super.createdAt,
    this.emotions = const [],
  });

  final List<String> emotions;

  @override
  StateCategory get category => StateCategory.emotions;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'emotions',
        'createdAt': createdAt.toIso8601String(),
        'emotions': emotions,
      };

  static EmotionsEntry? fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'emotions') return null;
    return EmotionsEntry(
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      emotions: (json['emotions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Запись сна: время засыпания/пробуждения, качество, теги.
class SleepEntry extends StateEntryBase {
  SleepEntry({
    required super.createdAt,
    this.bedTime,
    this.wakeTime,
    this.quality = 5,
    this.tags = const [],
  });

  final TimeOfDay? bedTime;
  final TimeOfDay? wakeTime;
  final int quality;
  final List<String> tags;

  @override
  StateCategory get category => StateCategory.sleep;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'sleep',
        'createdAt': createdAt.toIso8601String(),
        'bedTime': bedTime != null ? '${bedTime!.hour}:${bedTime!.minute}' : null,
        'wakeTime': wakeTime != null ? '${wakeTime!.hour}:${wakeTime!.minute}' : null,
        'quality': quality,
        'tags': tags,
      };

  static SleepEntry? fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'sleep') return null;
    TimeOfDay? parse(String? s) {
      if (s == null) return null;
      final p = s.split(':');
      if (p.length < 2) return null;
      return TimeOfDay(
        hour: int.tryParse(p[0]) ?? 0,
        minute: int.tryParse(p[1]) ?? 0,
      );
    }
    return SleepEntry(
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      bedTime: parse(json['bedTime'] as String?),
      wakeTime: parse(json['wakeTime'] as String?),
      quality: (json['quality'] as num?)?.toInt() ?? 5,
      tags: (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Запись питания: приёмы пищи, перекусы, ощущения, связь с эмоциями.
class NutritionEntry extends StateEntryBase {
  NutritionEntry({
    required super.createdAt,
    this.meals = const [],
    this.snackCount = 0,
    this.sensations = const [],
    this.emotionalConnection = const [],
  });

  final List<String> meals;
  final int snackCount;
  final List<String> sensations;
  final List<String> emotionalConnection;

  @override
  StateCategory get category => StateCategory.nutrition;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'nutrition',
        'createdAt': createdAt.toIso8601String(),
        'meals': meals,
        'snackCount': snackCount,
        'sensations': sensations,
        'emotionalConnection': emotionalConnection,
      };

  static NutritionEntry? fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'nutrition') return null;
    return NutritionEntry(
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      meals: (json['meals'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      snackCount: (json['snackCount'] as num?)?.toInt() ?? 0,
      sensations: (json['sensations'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      emotionalConnection:
          (json['emotionalConnection'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}

/// Запись энергии: уровень, характер, факторы.
class EnergyEntry extends StateEntryBase {
  EnergyEntry({
    required super.createdAt,
    this.level = 5,
    this.character,
    this.factors = const [],
  });

  final int level;
  final String? character;
  final List<String> factors;

  @override
  StateCategory get category => StateCategory.energy;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'energy',
        'createdAt': createdAt.toIso8601String(),
        'level': level,
        'character': character,
        'factors': factors,
      };

  static EnergyEntry? fromJson(Map<String, dynamic> json) {
    if (json['type'] != 'energy') return null;
    return EnergyEntry(
      createdAt: DateTime.tryParse(json['createdAt'] as String? ?? '') ?? DateTime.now(),
      level: (json['level'] as num?)?.toInt() ?? 5,
      character: json['character'] as String?,
      factors: (json['factors'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }
}
