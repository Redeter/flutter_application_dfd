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
    this.dailyDosage,
    this.reminder,
    required this.schedule,
    this.seriesId,
    List<DateTime?>? takenAtPerDose,
    List<bool>? skippedPerDose,
  })  : takenAtPerDose = takenAtPerDose ??
            Medication._normalizeTakenAtPerDose(
              schedule,
              null,
            ),
        skippedPerDose = Medication._normalizeSkippedPerDose(schedule, skippedPerDose);

  final String name;
  final String dosage; // "200мг"
  final String? dailyDosage;
  final List<MedicationDose> schedule;
  /// Общий id серии ежедневных приёмов (для пакетного создания с одной формы).
  final String? reminder;
  final String? seriesId;
  /// Отметка «принято» по каждому слоту [schedule] (тот же индекс).
  final List<DateTime?> takenAtPerDose;
  /// «Пропущено» по каждому слоту (не сохраняется, если уже принято).
  final List<bool> skippedPerDose;

  static List<DateTime?> _normalizeTakenAtPerDose(
    List<MedicationDose> schedule,
    List<DateTime?>? raw,
  ) {
    final n = schedule.length;
    if (n == 0) return [];
    if (raw != null && raw.length >= n) {
      return List<DateTime?>.generate(n, (i) => raw[i]);
    }
    if (raw != null && raw.isNotEmpty) {
      return List<DateTime?>.generate(n, (i) => i < raw.length ? raw[i] : null);
    }
    return List<DateTime?>.filled(n, null);
  }

  static List<bool> _normalizeSkippedPerDose(
    List<MedicationDose> schedule,
    List<bool>? raw,
  ) {
    final n = schedule.length;
    if (n == 0) return [];
    if (raw != null && raw.length >= n) {
      return List<bool>.generate(n, (i) => raw[i]);
    }
    if (raw != null && raw.isNotEmpty) {
      return List<bool>.generate(n, (i) => i < raw.length ? raw[i] : false);
    }
    return List<bool>.filled(n, false);
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'medication',
        'id': id,
        'date': DateTime(date.year, date.month, date.day).toIso8601String(),
        'hour': time.hour,
        'minute': time.minute,
        'name': name,
        'dosage': dosage,
        'dailyDosage': dailyDosage,
        if (reminder != null) 'reminder': reminder,
        'schedule': schedule.map((e) => e.toJson()).toList(),
        if (seriesId != null) 'seriesId': seriesId,
        'takenAtPerDose': takenAtPerDose.map((e) => e?.toIso8601String()).toList(),
        'skippedPerDose': skippedPerDose,
      };

  static Medication fromJson(Map<String, dynamic> json) {
    final schedule = (json['schedule'] as List<dynamic>?)
            ?.map((e) => MedicationDose.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final legacyTaken =
        json['takenAt'] != null ? DateTime.tryParse(json['takenAt'] as String) : null;
    final rawList = json['takenAtPerDose'] as List<dynamic>?;
    List<DateTime?>? parsed;
    if (rawList != null) {
      parsed = rawList
          .map((e) => e == null ? null : DateTime.tryParse(e as String))
          .toList();
    } else if (legacyTaken != null && schedule.isNotEmpty) {
      parsed = List<DateTime?>.filled(schedule.length, legacyTaken);
    }

    final rawSkipped = json['skippedPerDose'] as List<dynamic>?;
    List<bool>? parsedSkipped;
    if (rawSkipped != null) {
      parsedSkipped = rawSkipped.map((e) => e == true).toList();
    }

    return Medication(
      id: json['id'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime.now(),
      time: TimeOfDay(
        hour: (json['hour'] as num?)?.toInt() ?? 8,
        minute: (json['minute'] as num?)?.toInt() ?? 0,
      ),
      name: json['name'] as String? ?? '',
      dosage: json['dosage'] as String? ?? '',
      dailyDosage: json['dailyDosage'] as String?,
      schedule: schedule,
      seriesId: json['seriesId'] as String?,
      takenAtPerDose: _normalizeTakenAtPerDose(schedule, parsed),
      skippedPerDose: _normalizeSkippedPerDose(schedule, parsedSkipped),
    );
  }

  Medication copyWith({
    String? id,
    DateTime? date,
    TimeOfDay? time,
    String? name,
    String? dosage,
    String? dailyDosage,
    String? reminder,
    List<MedicationDose>? schedule,
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
      dailyDosage: dailyDosage ?? this.dailyDosage,
      reminder: reminder ?? this.reminder,
      schedule: nextSchedule,
      seriesId: seriesId ?? this.seriesId,
      takenAtPerDose: nextTaken,
      skippedPerDose: nextSkipped,
    );
  }
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
