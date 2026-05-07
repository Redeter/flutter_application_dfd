enum MentalCondition {
  bipolar,
  depression,
  anxiety,
  bpd,
  ed,
  ptsd,
  asd,
}

class UserProfile {
  const UserProfile({
    this.name = '',
    this.doctorName = '',
    this.conditions = const [],
  });

  final String name;
  final String doctorName;
  final List<MentalCondition> conditions;

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
