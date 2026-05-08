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
import '../neural/neural_insights_service.dart';
import '../services/auth_service.dart';
import '../services/user_profile_service.dart';
import 'auth_gate_screen.dart';
import 'condition_details_screen.dart';
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
  PriorityStateFocus _priorityFocus = PriorityStateFocus.mood;
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
      _priorityFocus = profile.priorityFocus;
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
        priorityFocus: _priorityFocus,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль сохранен')),
    );
    Navigator.pop(context);
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Для продолжения нужно будет снова войти или зарегистрироваться.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService.instance.logout();
    await NeuralInsightsService.instance.reloadForActiveUser();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AuthGateScreen()),
      (route) => false,
    );
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
    final lastSession = _lastAppointmentInRange(data, from, to);

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
          if (lastSession != null) ...[
            pw.SizedBox(height: 6),
            pw.Text(
              'Последний сеанс в периоде:',
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
            pw.Text(
              '- ${_fmtDate(lastSession.date)} ${_fmtTime(lastSession.time)}: ${lastSession.title}'
              '${lastSession.note?.isNotEmpty == true ? ' (${lastSession.note})' : ''}',
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
                  DropdownButtonFormField<PriorityStateFocus>(
                    value: _priorityFocus,
                    decoration: InputDecoration(
                      labelText: 'Приоритет наблюдения',
                      filled: true,
                      fillColor: AppColors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    items: PriorityStateFocus.values
                        .map(
                          (e) => DropdownMenuItem(
                            value: e,
                            child: Text(e.label),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _priorityFocus = v);
                      }
                    },
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
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1F8A70),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _buildCompactAppointments(upcoming: true),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Прошедшие',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9A4D00),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _buildCompactAppointments(upcoming: false),
                        ),
                        if (_pastAppointments().length > 5) ...[
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: _openAllPastAppointments,
                            child: const Text('Показать все прошедшие'),
                          ),
                        ],
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
                          return Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  value: selected,
                                  activeColor: AppColors.orange,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
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
                                ),
                              ),
                              IconButton(
                                tooltip: 'О заболевании',
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => ConditionDetailsScreen(
                                        condition: c,
                                      ),
                                    ),
                                  );
                                },
                                icon: const Icon(
                                  Icons.info_outline,
                                  color: AppColors.orange,
                                ),
                              ),
                            ],
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
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _logout,
                    icon: const Icon(Icons.logout),
                    label: const Text('Выйти из аккаунта'),
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

  List<Widget> _buildCompactAppointments({required bool upcoming}) {
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
      return const [];
    }
    final visible = upcoming ? items : items.take(5).toList();
    return visible
        .map(
          (a) => Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: upcoming
                  ? const Color(0xFFEAF9F3)
                  : const Color(0xFFFFF4EA),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: upcoming
                    ? const Color(0xFF77C8A9)
                    : const Color(0xFFF0B07D),
              ),
            ),
            child: Text(
              '${upcoming ? 'Предст.' : 'Прош.'} ${_fmtDate(a.date)} ${_fmtTime(a.time)} · ${a.title}',
              style: GoogleFonts.alegreyaSans(
                fontSize: 13,
                color: AppColors.textDark,
              ),
            ),
          ),
        )
        .toList();
  }

  List<Appointment> _pastAppointments() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = _appointments.where((a) {
      final date = DateTime(a.date.year, a.date.month, a.date.day);
      return date.isBefore(today);
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  void _openAllPastAppointments() {
    final items = _pastAppointments();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.45,
        builder: (context, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Все прошедшие посещения',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.builder(
                  controller: controller,
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final a = items[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(a.title),
                      subtitle: Text('${_fmtDate(a.date)} ${_fmtTime(a.time)}'),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Appointment? _lastAppointmentInRange(
    AggregatedData data,
    DateTime from,
    DateTime to,
  ) {
    final items = data.appointments.where((a) {
      final date = DateTime(a.date.year, a.date.month, a.date.day);
      return !date.isBefore(from) && !date.isAfter(to);
    }).toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    if (items.isEmpty) return null;
    return items.last;
  }
}
