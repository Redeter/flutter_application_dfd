import 'package:flutter/material.dart';

/// Запись в календаре: препарат или приём.
sealed class CalendarEntry {
  CalendarEntry({
    required this.id,
    required this.date,
    required this.time,
  });

  final String id;
  final DateTime date;
  final TimeOfDay time;

  Map<String, dynamic> toJson();
}

/// Расписание приёма препарата.
class MedicationDose {
  const MedicationDose({
    required this.time,
    required this.amount,
  });

  final TimeOfDay time;
  final String amount; // "1 таблетка", "1/2 таблетки"

  Map<String, dynamic> toJson() => {
        'hour': time.hour,
        'minute': time.minute,
        'amount': amount,
      };

  static MedicationDose fromJson(Map<String, dynamic> json) {
    return MedicationDose(
      time: TimeOfDay(
        hour: (json['hour'] as num?)?.toInt() ?? 8,
        minute: (json['minute'] as num?)?.toInt() ?? 0,
      ),
      amount: json['amount'] as String? ?? '1 таблетка',
    );
  }
}

/// Препарат.
class Medication extends CalendarEntry {
  Medication({
    required super.id,
    required super.date,
    required super.time,
    required this.name,
    required this.dosage,
    this.frequency = 'Ежедневно',
    this.dailyDosage,
    this.reminder,
    required this.schedule,
    this.takenAt,
  });

  final String name;
  final String dosage; // "200мг"
  final String frequency;
  final String? dailyDosage;
  /// «За 15 мин» / «За 1 час» / «За день» / «Не напоминать» — доп. напоминание до приёма.
  final String? reminder;
  final List<MedicationDose> schedule;
  final DateTime? takenAt;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'medication',
        'id': id,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'hour': time.hour,
        'minute': time.minute,
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'dailyDosage': dailyDosage,
        if (reminder != null) 'reminder': reminder,
        'schedule': schedule.map((e) => e.toJson()).toList(),
        'takenAt': takenAt?.toIso8601String(),
      };

  static Medication fromJson(Map<String, dynamic> json) {
    return Medication(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      time: TimeOfDay(
        hour: (json['hour'] as num?)?.toInt() ?? 8,
        minute: (json['minute'] as num?)?.toInt() ?? 0,
      ),
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      frequency: json['frequency'] as String? ?? 'Ежедневно',
      dailyDosage: json['dailyDosage'] as String?,
<<<<<<< Updated upstream
      schedule: (json['schedule'] as List<dynamic>?)
              ?.map((e) => MedicationDose.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      takenAt: json['takenAt'] != null ? DateTime.tryParse(json['takenAt'] as String) : null,
=======
      reminder: json['reminder'] as String?,
      schedule: schedule,
      seriesId: json['seriesId'] as String?,
      takenAtPerDose: _normalizeTakenAtPerDose(schedule, parsed),
      skippedPerDose: _normalizeSkippedPerDose(schedule, parsedSkipped),
>>>>>>> Stashed changes
    );
  }

  Medication copyWith({
    String? id,
    DateTime? date,
    TimeOfDay? time,
    String? name,
    String? dosage,
    String? frequency,
    String? dailyDosage,
    String? reminder,
    List<MedicationDose>? schedule,
<<<<<<< Updated upstream
    DateTime? takenAt,
  }) =>
      Medication(
        id: id ?? this.id,
        date: date ?? this.date,
        time: time ?? this.time,
        name: name ?? this.name,
        dosage: dosage ?? this.dosage,
        frequency: frequency ?? this.frequency,
        dailyDosage: dailyDosage ?? this.dailyDosage,
        schedule: schedule ?? this.schedule,
        takenAt: takenAt ?? this.takenAt,
      );
=======
    String? seriesId,
    List<DateTime?>? takenAtPerDose,
    List<bool>? skippedPerDose,
  }) {
    final nextSchedule = schedule ?? this.schedule;
    final nextTaken = takenAtPerDose ??
        Medication._normalizeTakenAtPerDose(nextSchedule, this.takenAtPerDose);
    final nextSkipped = skippedPerDose ??
        Medication._normalizeSkippedPerDose(nextSchedule, this.skippedPerDose);
    return Medication(
      id: id ?? this.id,
      date: date ?? this.date,
      time: time ?? this.time,
      name: name ?? this.name,
      dosage: dosage ?? this.dosage,
      frequency: frequency ?? this.frequency,
      dailyDosage: dailyDosage ?? this.dailyDosage,
      reminder: reminder ?? this.reminder,
      schedule: nextSchedule,
      seriesId: seriesId ?? this.seriesId,
      takenAtPerDose: nextTaken,
      skippedPerDose: nextSkipped,
    );
  }
>>>>>>> Stashed changes
}

/// Приём (врача и т.д.).
class Appointment extends CalendarEntry {
  Appointment({
    required super.id,
    required super.date,
    required super.time,
    required this.title,
    this.meetingDate,
    this.note,
    this.reminder,
  });

  final String title;
  final DateTime? meetingDate;
  final String? note;
  final String? reminder;

  @override
  Map<String, dynamic> toJson() => {
        'type': 'appointment',
        'id': id,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'hour': time.hour,
        'minute': time.minute,
        'title': title,
        'meetingDate': meetingDate?.toIso8601String(),
        'note': note,
        'reminder': reminder,
      };

  static Appointment fromJson(Map<String, dynamic> json) {
    return Appointment(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      time: TimeOfDay(
        hour: (json['hour'] as num?)?.toInt() ?? 15,
        minute: (json['minute'] as num?)?.toInt() ?? 0,
      ),
      title: json['title'] as String? ?? '',
      meetingDate: json['meetingDate'] != null
          ? DateTime.tryParse(json['meetingDate'] as String)
          : null,
      note: json['note'] as String?,
      reminder: json['reminder'] as String?,
    );
  }

  Appointment copyWith({
    String? id,
    DateTime? date,
    TimeOfDay? time,
    String? title,
    DateTime? meetingDate,
    String? note,
    String? reminder,
  }) =>
      Appointment(
        id: id ?? this.id,
        date: date ?? this.date,
        time: time ?? this.time,
        title: title ?? this.title,
        meetingDate: meetingDate ?? this.meetingDate,
        note: note ?? this.note,
        reminder: reminder ?? this.reminder,
      );
}
