import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../models/aggregated_data.dart';
import '../models/calendar_entry.dart';
import '../constants/privacy_copy.dart';
import '../models/foundation_sphere.dart';
import '../models/user_profile.dart';
import '../services/calendar_storage.dart';
import '../services/foundation_service.dart';
import '../services/insights_service.dart';
import '../neural/neural_insights_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../services/pin_lock_service.dart';
import '../services/user_profile_service.dart';
import 'auth_gate_screen.dart';
import 'condition_details_screen.dart';
import 'pin_lock_screen.dart';
import '../theme/app_colors.dart';
import '../theme/app_typography.dart';
import '../utils/stats_helpers.dart';
import '../widgets/laconic_tap.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _emailReadOnlyController = TextEditingController();
  final _nameController = TextEditingController();
  final _selected = <MentalCondition>{};
  PriorityStateFocus _priorityFocus = PriorityStateFocus.mood;
  FoundationSpherePriorities _spherePriorities =
      const FoundationSpherePriorities();
  List<Medication> _medications = const [];
  List<Appointment> _appointments = const [];
  DateTime _reportFrom = DateTime.now().subtract(const Duration(days: 30));
  DateTime _reportTo = DateTime.now();
  bool _loading = true;
  bool _eveningReminderEnabled = false;
  TimeOfDay _eveningReminderTime = const TimeOfDay(hour: 20, minute: 30);
  bool _pinEnabled = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final email = await AuthService.instance.userEmail() ?? '';
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
      final key = medicationUniqueNameKey(medication);
      if (key.isEmpty) continue;
      activeMap.putIfAbsent(key, () => medication);
    }

    final reminderOn =
        await FoundationService.instance.isQuestEveningReminderEnabled();
    final (rh, rm) =
        await FoundationService.instance.getQuestEveningReminderClock();
    final pinEnabled = await PinLockService.instance.isEnabled();

    if (!mounted) return;
    setState(() {
      _emailReadOnlyController.text = email;
      _nameController.text = profile.name;
      _selected
        ..clear()
        ..addAll(profile.conditions);
      _priorityFocus = profile.priorityFocus;
      _spherePriorities = profile.spherePriorities;
      _medications = activeMap.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
      _appointments = appointments;
      _eveningReminderEnabled = reminderOn;
      _eveningReminderTime = TimeOfDay(hour: rh, minute: rm);
      _pinEnabled = pinEnabled;
      _loading = false;
    });
  }

  Future<void> _pickEveningReminderTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _eveningReminderTime,
      builder: (ctx, child) {
        return Theme(
          data: Theme.of(ctx).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.dialogPrimary,
            ),
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
    if (picked == null || !mounted) return;
    await FoundationService.instance
        .setQuestEveningReminderClock(picked.hour, picked.minute);
    setState(() => _eveningReminderTime = picked);
    await NotificationService.instance.rescheduleCalendarNotifications();
  }

  Future<void> _save() async {
    await UserProfileService.instance.save(
      UserProfile(
        name: _nameController.text.trim(),
        conditions: _selected.toList(),
        priorityFocus: _priorityFocus,
        spherePriorities: _spherePriorities,
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Профиль сохранен')),
    );
    Navigator.pop(context);
  }

  Future<void> _showPrivacyDetails() async {
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Конфиденциальность',
          style: GoogleFonts.alegreyaSans(fontWeight: FontWeight.w800),
        ),
        content: SingleChildScrollView(
          child: Text(
            PrivacyCopy.profileSectionBody,
            style: GoogleFonts.alegreyaSans(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textDark.withValues(alpha: 0.85),
            ),
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(ctx),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dialogPrimary,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Понятно'),
          ),
        ],
      ),
    );
  }

  Future<void> _setupPin() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PinLockScreen(
          flow: PinLockFlow.create,
          onSuccess: () => Navigator.pop(context),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _disablePin() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PinLockScreen(
          flow: PinLockFlow.verifyToDisable,
          onSuccess: () => Navigator.pop(context),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
  }

  Future<void> _changePin() async {
    await Navigator.of(context, rootNavigator: true).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => PinLockScreen(
          flow: PinLockFlow.change,
          onSuccess: () => Navigator.pop(context),
          onCancel: () => Navigator.pop(context),
        ),
      ),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('PIN-код изменён')),
    );
  }

  Future<void> _onPinToggle(bool? value) async {
    if (value == true) {
      await _setupPin();
    } else if (_pinEnabled) {
      await _disablePin();
    }
    if (!mounted) return;
    final enabled = await PinLockService.instance.isEnabled();
    if (!mounted) return;
    setState(() => _pinEnabled = enabled);
    if (value == true && enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN-код включён')),
      );
    } else if (value == false && !enabled) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('PIN-код отключён')),
      );
    }
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
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.dialogPrimary,
              foregroundColor: AppColors.white,
            ),
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const AuthGateScreen()),
      (_) => false,
    );

    unawaited(Future<void>(() async {
      try {
        await NeuralInsightsService.instance.reloadForActiveUser();
      } catch (_) {}
      try {
        await NotificationService.instance.rescheduleCalendarNotifications();
      } catch (_) {}
    }));
  }

  Future<void> _deleteAccount() async {
    final pwd = await showDialog<String>(
      context: context,
      builder: (ctx) => const _DeleteAccountPasswordDialog(),
    );
    if (!mounted) return;
    if (pwd == null || pwd.isEmpty) return;

    final ok = await AuthService.instance.deleteAccount(password: pwd);
    if (!mounted) return;
    if (!ok) {
      // После успешного удаления сессия уже сброшена — повторный ввод даёт false до проверки пароля.
      final session = await AuthService.instance.sessionUserId();
      if (!mounted) return;
      if (session == null) {
        Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
          MaterialPageRoute<void>(builder: (_) => const AuthGateScreen()),
          (_) => false,
        );
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Неверный пароль')),
      );
      return;
    }

    // Сразу уходим на экран входа: перепланирование уведомлений / нейросеть
    // не должны блокировать навигацию (в release там возможны исключения).
    Navigator.of(context, rootNavigator: true).pushAndRemoveUntil<void>(
      MaterialPageRoute<void>(builder: (_) => const AuthGateScreen()),
      (_) => false,
    );

    unawaited(Future<void>(() async {
      try {
        await NeuralInsightsService.instance.reloadForActiveUser();
      } catch (_) {}
      try {
        await NotificationService.instance.rescheduleCalendarNotifications();
      } catch (_) {}
    }));
  }

  @override
  void dispose() {
    _emailReadOnlyController.dispose();
    _nameController.dispose();
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
          ...foundation.spheres.map(
            (s) => pw.Text('${s.label}: ${s.detailLine}'),
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
                  const SizedBox(height: 20),
                  Text('Почта', style: AppTypography.fieldLabel),
                  const SizedBox(height: 10),
                  TextField(
                    readOnly: true,
                    enableInteractiveSelection: true,
                    style: AppTypography.formField,
                    controller: _emailReadOnlyController,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.greyMuted.withValues(alpha: 0.35),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Используется для входа, изменить нельзя',
                      style: AppTypography.fieldHelper,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text('Имя', style: AppTypography.fieldLabel),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _nameController,
                    style: AppTypography.formField,
                    textCapitalization: TextCapitalization.none,
                    keyboardType: TextInputType.name,
                    autocorrect: false,
                    maxLength: 200,
                    buildCounter: (
                      context, {
                      required currentLength,
                      required isFocused,
                      maxLength,
                    }) =>
                        null,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.white,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Text(
                      'Любые буквы и символы',
                      style: AppTypography.fieldHelper,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Приоритеты сфер (сон, настроение, энергия, питание, препараты) настраиваются на вкладке «Цели».',
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 13,
                      height: 1.35,
                      color: AppColors.textDark.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 12),
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
                          'Вкладка «Цели»',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Локальное напоминание на этом устройстве (не веб). '
                          'После смены времени при необходимости разрешите уведомления в системе.',
                          style: GoogleFonts.alegreyaSans(
                            fontSize: 12,
                            height: 1.35,
                            color: AppColors.textDark.withValues(alpha: 0.65),
                          ),
                        ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            'Вечернее напоминание о шаге',
                            style: GoogleFonts.alegreyaSans(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Text(
                            'Напомнит заглянуть в «Цели» и отметить шаг.',
                            style: GoogleFonts.alegreyaSans(
                              fontSize: 12,
                              color: AppColors.textDark.withValues(alpha: 0.62),
                            ),
                          ),
                          value: _eveningReminderEnabled,
                          activeColor: AppColors.orange,
                          onChanged: (v) async {
                            setState(() => _eveningReminderEnabled = v);
                            await FoundationService.instance
                                .setQuestEveningReminderEnabled(v);
                            await NotificationService.instance
                                .rescheduleCalendarNotifications();
                          },
                        ),
                        if (_eveningReminderEnabled)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              'Время',
                              style: GoogleFonts.alegreyaSans(fontSize: 14),
                            ),
                            trailing: Text(
                              _eveningReminderTime.format(context),
                              style: GoogleFonts.alegreyaSans(
                                fontWeight: FontWeight.w700,
                                fontSize: 15,
                                color: AppColors.dialogPrimary,
                              ),
                            ),
                            onTap: _pickEveningReminderTime,
                          ),
                      ],
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
                                  activeColor: AppCheckboxStyle.activeColor,
                                  checkColor: AppCheckboxStyle.checkColor,
                                  side: AppCheckboxStyle.side,
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(
                                    c.label,
                                    style: AppTypography.checkboxTileTitle(),
                                  ),
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
                  _sectionCard(
                    title: 'Конфиденциальность',
                    child: OutlinedButton(
                      onPressed: _showPrivacyDetails,
                      child: const Text('Как хранятся данные'),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _sectionCard(
                    title: 'PIN-код',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          value: _pinEnabled,
                          onChanged: _onPinToggle,
                          activeColor: AppColors.orange,
                          title: Text(
                            'Запрашивать PIN при входе',
                            style: AppTypography.checkboxTileTitle(),
                          ),
                        ),
                        if (_pinEnabled)
                          OutlinedButton(
                            onPressed: _changePin,
                            child: const Text('Изменить PIN-код'),
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
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _deleteAccount,
                    icon: const Icon(Icons.delete_forever_outlined, color: Color(0xFFB71C1C)),
                    label: Text(
                      'Удалить аккаунт',
                      style: GoogleFonts.alegreyaSans(
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFB71C1C),
                      ),
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

/// Диалог с паролем: контроллер живёт в State маршрута и корректно dispose-ится
/// после снятия [TextField] с дерева (избегает `_dependents.isEmpty` при удалении аккаунта).
class _DeleteAccountPasswordDialog extends StatefulWidget {
  const _DeleteAccountPasswordDialog();

  @override
  State<_DeleteAccountPasswordDialog> createState() =>
      _DeleteAccountPasswordDialogState();
}

class _DeleteAccountPasswordDialogState extends State<_DeleteAccountPasswordDialog> {
  late final TextEditingController _passwordController;

  @override
  void initState() {
    super.initState();
    _passwordController = TextEditingController();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _dismissKeyboardAndPop([String? password]) {
    FocusManager.instance.primaryFocus?.unfocus();
    Navigator.pop(context, password);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Удалить аккаунт?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            PrivacyCopy.deleteAccountWarning,
            style: GoogleFonts.alegreyaSans(fontSize: 14),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _passwordController,
            obscureText: true,
            autocorrect: false,
            decoration: const InputDecoration(
              labelText: 'Пароль',
              border: OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => _dismissKeyboardAndPop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFC62828)),
          onPressed: () => _dismissKeyboardAndPop(_passwordController.text),
          child: const Text('Удалить аккаунт'),
        ),
      ],
    );
  }
}
