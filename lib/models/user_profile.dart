enum MentalCondition {
  bipolar,
  depression,
  anxiety,
  bpd,
  ed,
  ptsd,
  asd,
}

enum PriorityStateFocus {
  sleep,
  mood,
  energy,
  anxiety,
  stress,
  medication,
  doctorVisit,
}

class UserProfile {
  const UserProfile({
    this.name = '',
    this.conditions = const [],
    this.priorityFocus = PriorityStateFocus.mood,
  });

  final String name;
  final List<MentalCondition> conditions;
  final PriorityStateFocus priorityFocus;

  bool get hasConditions => conditions.isNotEmpty;
}

extension MentalConditionX on MentalCondition {
  String get code => switch (this) {
        MentalCondition.bipolar => 'bipolar',
        MentalCondition.depression => 'depression',
        MentalCondition.anxiety => 'anxiety',
        MentalCondition.bpd => 'bpd',
        MentalCondition.ed => 'ed',
        MentalCondition.ptsd => 'ptsd',
        MentalCondition.asd => 'asd',
      };

  String get label => switch (this) {
        MentalCondition.bipolar => 'Биполярное расстройство',
        MentalCondition.depression => 'Депрессия',
        MentalCondition.anxiety => 'Тревожные расстройства',
        MentalCondition.bpd => 'Пограничное расстройство',
        MentalCondition.ed => 'РПП',
        MentalCondition.ptsd => 'ПТСР',
        MentalCondition.asd => 'РАС',
      };

  static MentalCondition? fromCode(String code) {
    for (final c in MentalCondition.values) {
      if (c.code == code) return c;
    }
    return null;
  }
}

extension PriorityStateFocusX on PriorityStateFocus {
  String get code => switch (this) {
        PriorityStateFocus.sleep => 'sleep',
        PriorityStateFocus.mood => 'mood',
        PriorityStateFocus.energy => 'energy',
        PriorityStateFocus.anxiety => 'anxiety',
        PriorityStateFocus.stress => 'stress',
        PriorityStateFocus.medication => 'medication',
        PriorityStateFocus.doctorVisit => 'doctor_visit',
      };

  String get label => switch (this) {
        PriorityStateFocus.sleep => 'Сон',
        PriorityStateFocus.mood => 'Настроение',
        PriorityStateFocus.energy => 'Энергия',
        PriorityStateFocus.anxiety => 'Тревога',
        PriorityStateFocus.stress => 'Стресс',
        PriorityStateFocus.medication => 'Прием препаратов',
        PriorityStateFocus.doctorVisit => 'Посещение врача',
      };

  static PriorityStateFocus fromCode(String? raw) {
    for (final focus in PriorityStateFocus.values) {
      if (focus.code == raw) return focus;
    }
    return PriorityStateFocus.mood;
  }
}
