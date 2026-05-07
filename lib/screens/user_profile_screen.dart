import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../models/user_profile.dart';
import '../services/calendar_storage.dart';
import '../services/foundation_service.dart';
import '../services/insights_service.dart';
import '../services/user_profile_service.dart';
import '../theme/app_colors.dart';
import '../widgets/laconic_tap.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _nameController = TextEditingController();
  final _doctorController = TextEditingController();
  final _selected = <MentalCondition>{};
  List<Medication> _medications = const [];
  List<Appointment> _appointments = const [];
  DateTime _reportFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _reportTo = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await UserProfileService.instance.load();
    final entries = await CalendarStorage.instance.loadAll();
    final medications = entries.whereType<Medication>().toList();
    final appointments = entries.whereType<Appointment>().toList()
      ..sort((a, b) => a.date.compareTo(b.date));

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activeMap = <String, Medication>{};
    for (final medication in medications) {
      final medDate = DateTime(
        medication.date.year,
        medication.date.month,
        medication.date.day,
      );
      if (medDate.isBefore(today)) continue;
      final key = medication.seriesId?.isNotEmpty == true
          ? medication.seriesId!
          : '${medication.name.toLowerCase()}|${medication.dosage}';
      activeMap.putIfAbsent(key, () => medication);
    }

    if (!mounted) return;
    setState(() {
      _nameController.text = profile.name;
      _doctorController.text = profile.doctorName;
      _selected
        ..clear()
        ..addAll(profile.conditions);
      _medications = activeMap.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _appointments = appointments;
      _loading = false;
    });
  }

  Future<void> _save() async {
    await UserProfileService.instance.save(
      UserProfile(
        name: _nameController.text.trim(),
        doctorName: _doctorController.text.trim(),
        conditions: _selected.toList(),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль сохранен')),
    );
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _nameController.dispose();
    _doctorController.dispose();
    super.dispose();
  }

  Future<void> _pickReportDate({required bool isFrom}) async {
    final initial = isFrom ? _reportFrom : _reportTo;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (isFrom) {
        _reportFrom = picked;
        if (_reportTo.isBefore(_reportFrom)) _reportTo = _reportFrom;
      } else {
        _reportTo = picked;
        if (_reportFrom.isAfter(_reportTo)) _reportFrom = _reportTo;
      }
    });
  }

  String _fmtDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}.'
        '${date.month.toString().padLeft(2, '0')}.${date.year}';
  }

  String _fmtTime(TimeOfDay time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  Future<void> _createPdfReport() async {
    final from = DateTime(_reportFrom.year, _reportFrom.month, _reportFrom.day);
    final to = DateTime(_reportTo.year, _reportTo.month, _reportTo.day);
    final data = await InsightsService.instance.aggregateData(
      rangeStart: from,
      rangeEnd: to,
    );
    final insights = await InsightsService.instance.getInsights(data);
    final goals = await FoundationService.instance.loadGoals();
    final foundation = FoundationService.instance.compute(
      data,
      goals,
      statsPeriodCaption: '${_fmtDate(from)} - ${_fmtDate(to)}',
    );

    final doc = pw.Document();
    final baseFont = await PdfGoogleFonts.robotoRegular();
    final boldFont = await PdfGoogleFonts.robotoBold();
    doc.addPage(
      pw.MultiPage(
        theme: pw.ThemeData.withFont(base: baseFont, bold: boldFont),
        build: (_) => [
          pw.Text(
            'Отчет о состоянии',
            style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          pw.Text('Период: ${_fmtDate(from)} - ${_fmtDate(to)}'),
          pw.SizedBox(height: 14),
          pw.Text('Имя: ${_nameController.text.trim().isEmpty ? 'Не указано' : _nameController.text.trim()}'),
          pw.Text(
            'Врач: ${_doctorController.text.trim().isEmpty ? 'Не указано' : _doctorController.text.trim()}',
          ),
          pw.SizedBox(height: 16),
          pw.Text(
            'Нейроанализ состояния',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            insights.stateSummary.isEmpty
                ? 'Недостаточно данных для резюме состояния.'
                : insights.stateSummary,
          ),
          if (insights.overallInsight.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(insights.overallInsight),
          ],
          if (insights.topTriggers.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text('Ключевые триггеры: ${insights.topTriggers.join(', ')}'),
          ],
          if (insights.recommendations.isNotEmpty) ...[
            pw.SizedBox(height: 8),
            pw.Text(
              'Рекомендации нейросети:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ...insights.recommendations.map((r) => pw.Text('- $r')),
          ],
          pw.SizedBox(height: 16),
          pw.Text(
            'Цели и прогресс',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Сон: цель ${goals.sleepTarget.toStringAsFixed(1)}, факт ${foundation.spheres.firstWhere((s) => s.id == 'sleep').current.toStringAsFixed(1)}',
          ),
          pw.Text(
            'Настроение: цель ${goals.moodTarget.toStringAsFixed(1)}, факт ${foundation.spheres.firstWhere((s) => s.id == 'mood').current.toStringAsFixed(1)}',
          ),
          pw.Text(
            'Энергия: цель ${goals.energyTarget.toStringAsFixed(1)}, факт ${foundation.spheres.firstWhere((s) => s.id == 'energy').current.toStringAsFixed(1)}',
          ),
          pw.Text(
            'Общий прогресс: ${(foundation.overallProgress * 100).round()}%',
          ),
          pw.Text('Следующий шаг: ${foundation.nextStep}'),
          pw.SizedBox(height: 16),
          pw.Text(
            'Данные периода',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Записи состояния: ${data.stateEntries.length}, заметки: ${data.notes.length}, препараты: ${data.medications.length}, визиты: ${data.appointments.length}',
          ),
          if (data.appointments.isNotEmpty) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Посещения врача:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            ..._appointmentsInRange(data, from, to).map(
              (a) => pw.Text(
                '- ${_fmtDate(a.date)} ${_fmtTime(a.time)}: ${a.title}${a.note?.isNotEmpty == true ? ' (${a.note})' : ''}',
              ),
            ),
          ],
        ],
      ),
    );

    await Printing.layoutPdf(
      name: 'report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      onLayout: (_) async => doc.save(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Профиль пользователя',
          style: GoogleFonts.alegreyaSans(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Настройте профиль под себя. Поле с состояниями можно оставить пустым.',
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 14,
                      color: AppColors.textDark.withValues(alpha: 0.8),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: 'Имя',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _doctorController,
                    decoration: InputDecoration(
                      labelText: 'Имя врача',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  _sectionCard(
                    title: 'Принимаемые препараты',
                    child: _medications.isEmpty
                        ? const Text('Список пуст')
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: _medications
                                .map(
                                  (m) => Padding(
                                    padding: const EdgeInsets.only(bottom: 6),
                                    child: Text(
                                      '• ${m.name}${m.dailyDosage == null ? '' : ' — ${m.dailyDosage}'}',
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: 'Посещения врача',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Предстоящие',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._buildAppointments(upcoming: true),
                        const SizedBox(height: 10),
                        Text(
                          'Прошедшие',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 6),
                        ..._buildAppointments(upcoming: false),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Особенности состояния (опционально)',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...MentalCondition.values.map((c) {
                          final selected = _selected.contains(c);
                          return CheckboxListTile(
                            value: selected,
                            activeColor: AppColors.orange,
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            title: Text(c.label),
                            onChanged: (v) {
                              setState(() {
                                if (v == true) {
                                  _selected.add(c);
                                } else {
                                  _selected.remove(c);
                                }
                              });
                            },
                          );
                        }),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () => setState(_selected.clear),
                          child: const Text('Оставить без заболевания'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: 'PDF отчет за период',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Отчет формируется на основе нейроанализа состояния и целей за выбранный срок.',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 13,
                            color: AppColors.textDark.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickReportDate(isFrom: true),
                                child: Text('С: ${_fmtDate(_reportFrom)}'),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () => _pickReportDate(isFrom: false),
                                child: Text('По: ${_fmtDate(_reportTo)}'),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: _createPdfReport,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.orange,
                          ),
                          child: const Text('Создать PDF'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  LaconicTap(
                    onTap: _save,
                    child: FilledButton(
                      onPressed: _save,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.orange),
                      child: const Text('Сохранить'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _sectionCard({
    required String title,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.alegreyaSans(
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }

  List<Widget> _buildAppointments({required bool upcoming}) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = _appointments.where((a) {
      final date = DateTime(a.date.year, a.date.month, a.date.day);
      return upcoming ? !date.isBefore(today) : date.isBefore(today);
    }).toList();
    if (upcoming) {
      items.sort((a, b) => a.date.compareTo(b.date));
    } else {
      items.sort((a, b) => b.date.compareTo(a.date));
    }
    if (items.isEmpty) {
      return const [Text('Нет записей')];
    }
    return items
        .map(
          (a) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text('• ${_fmtDate(a.date)} ${_fmtTime(a.time)} — ${a.title}'),
          ),
        )
        .toList();
  }

  List<Appointment> _appointmentsInRange(
    AggregatedData data,
    DateTime from,
    DateTime to,
  ) {
    final items = data.appointments.where((a) {
      final date = DateTime(a.date.year, a.date.month, a.date.day);
      return !date.isBefore(from) && !date.isAfter(to);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return items;
  }
}
