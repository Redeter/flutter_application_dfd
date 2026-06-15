/// Идентификаторы сфер фундамента (вкладка «Цели»).
abstract final class FoundationSphereIds {
  static const sleep = 'sleep';
  static const mood = 'mood';
  static const energy = 'energy';
  static const nutrition = 'nutrition';
  static const medication = 'medication';

  static const ordered = [
    sleep,
    mood,
    energy,
    nutrition,
    medication,
  ];
}

extension FoundationSphereIdX on String {
  String get foundationLabel => switch (this) {
        FoundationSphereIds.sleep => 'Сон',
        FoundationSphereIds.mood => 'Настроение',
        FoundationSphereIds.energy => 'Энергия',
        FoundationSphereIds.nutrition => 'Питание',
        FoundationSphereIds.medication => 'Приём препаратов',
        _ => this,
      };
}

/// Включение сферы в расчёте фундамента (вкл. / выкл., без весов).
class FoundationSpherePriorities {
  const FoundationSpherePriorities({
    this.sleep = 1,
    this.mood = 1,
    this.energy = 1,
    this.nutrition = 1,
    this.medication = 1,
  });

  final int sleep;
  final int mood;
  final int energy;
  final int nutrition;
  final int medication;

  static const _on = 1;

  int forId(String id) => switch (id) {
        FoundationSphereIds.sleep => sleep,
        FoundationSphereIds.mood => mood,
        FoundationSphereIds.energy => energy,
        FoundationSphereIds.nutrition => nutrition,
        FoundationSphereIds.medication => medication,
        _ => 0,
      };

  bool isActive(String id) => forId(id) > 0;

  FoundationSpherePriorities copyWithId(String id, bool active) {
    final v = active ? _on : 0;
    return switch (id) {
      FoundationSphereIds.sleep => copyWith(sleep: v),
      FoundationSphereIds.mood => copyWith(mood: v),
      FoundationSphereIds.energy => copyWith(energy: v),
      FoundationSphereIds.nutrition => copyWith(nutrition: v),
      FoundationSphereIds.medication => copyWith(medication: v),
      _ => this,
    };
  }

  Iterable<String> get activeIds =>
      FoundationSphereIds.ordered.where(isActive);

  int get activeCount => activeIds.length;

  FoundationSpherePriorities copyWith({
    int? sleep,
    int? mood,
    int? energy,
    int? nutrition,
    int? medication,
  }) {
    return FoundationSpherePriorities(
      sleep: sleep ?? this.sleep,
      mood: mood ?? this.mood,
      energy: energy ?? this.energy,
      nutrition: nutrition ?? this.nutrition,
      medication: medication ?? this.medication,
    );
  }

  Map<String, int> toJson() => {
        FoundationSphereIds.sleep: sleep,
        FoundationSphereIds.mood: mood,
        FoundationSphereIds.energy: energy,
        FoundationSphereIds.nutrition: nutrition,
        FoundationSphereIds.medication: medication,
      };

  static FoundationSpherePriorities fromJson(Map<String, dynamic>? raw) {
    if (raw == null || raw.isEmpty) return const FoundationSpherePriorities();
    int p(String k, int def) {
      final n = (raw[k] as num?)?.toInt() ?? def;
      return n > 0 ? _on : 0;
    }

    return FoundationSpherePriorities(
      sleep: p(FoundationSphereIds.sleep, 1),
      mood: p(FoundationSphereIds.mood, 1),
      energy: p(FoundationSphereIds.energy, 1),
      nutrition: p(FoundationSphereIds.nutrition, 1),
      medication: p(FoundationSphereIds.medication, 1),
    );
  }

  /// Миграция со старого одиночного [PriorityStateFocus] или весов 0.5–2.0.
  static FoundationSpherePriorities migrateFromLegacy({
    String? priorityFocusCode,
    double? sleepWeight,
    double? moodWeight,
    double? energyWeight,
  }) {
    if (sleepWeight != null || moodWeight != null || energyWeight != null) {
      int fromWeight(double w) => w <= 0.6 ? 0 : _on;

      return FoundationSpherePriorities(
        sleep: fromWeight(sleepWeight ?? 1),
        mood: fromWeight(moodWeight ?? 1),
        energy: fromWeight(energyWeight ?? 1),
        nutrition: _on,
        medication: _on,
      );
    }

    return switch (priorityFocusCode) {
      'sleep' => const FoundationSpherePriorities(
          sleep: 1,
          mood: 0,
          energy: 0,
          nutrition: 0,
          medication: 0,
        ),
      'mood' => const FoundationSpherePriorities(
          sleep: 0,
          mood: 1,
          energy: 0,
          nutrition: 0,
          medication: 0,
        ),
      'energy' => const FoundationSpherePriorities(
          sleep: 0,
          mood: 0,
          energy: 1,
          nutrition: 0,
          medication: 0,
        ),
      'medication' => const FoundationSpherePriorities(
          sleep: 0,
          mood: 0,
          energy: 0,
          nutrition: 0,
          medication: 1,
        ),
      _ => const FoundationSpherePriorities(),
    };
  }
}
