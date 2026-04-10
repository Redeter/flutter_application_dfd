import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/aggregated_data.dart';
import '../models/insight_result.dart';
import '../services/insights_service.dart';
import '../theme/app_colors.dart';
import '../utils/stats_helpers.dart';
import '../widgets/app_bottom_nav.dart';
import 'articles_screen.dart';
import 'calendar_screen.dart';
import 'notes_screen.dart';
import 'state_categories_sheet.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  InsightResult? _insight;
  AggregatedData? _data;
  bool _loading = false;
  DateTime _selectedDate = DateTime.now();
  bool _viewWeek = true; // true = неделя, false = день

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final data = await InsightsService.instance.aggregateData();
      final result = await InsightsService.instance.getInsights(data);
      if (mounted) {
        setState(() {
          _data = data;
          _insight = result;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _insight = InsightResult.fromError('$e');
          _loading = false;
        });
      }
    }
  }

  (DateTime, DateTime) get _range {
    if (_viewWeek) {
      final start = _selectedDate.subtract(Duration(days: _selectedDate.weekday - 1));
      return (start, start.add(const Duration(days: 6)));
    } else {
      return (_selectedDate, _selectedDate);
    }
  }

  LocalStats get _localStats {
    if (_data == null) return const LocalStats();
    final (start, end) = _range;
    return computeLocalStats(_data!, start: start, end: end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.cream,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppColors.orange),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Статистика',
          style: GoogleFonts.alegreyaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: AppColors.textDark,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppColors.orange),
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AppColors.orange))
            : _buildContent(),
      ),
      bottomNavigationBar: AppBottomNavBar(
        activeTab: null,
        onTabSelected: (tab) {
          switch (tab) {
            case BottomNavTab.statistics:
              return;
            case BottomNavTab.notes:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const NotesScreen()),
              );
            case BottomNavTab.calendar:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const CalendarScreen()),
              );
            case BottomNavTab.articles:
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const ArticlesScreen()),
              );
          }
        },
        onCenterTap: () => showStateCategoriesSheet(context),
      ),
    );
  }

  Widget _buildContent() {
    if (_insight == null) return const SizedBox.shrink();
    if (_insight!.hasError) {
      return _buildError(_insight!.error!);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDateStrip(),
          const SizedBox(height: 16),
          if (_data != null && _hasAnyData) _buildDataSummary(),
          if (_localStats.hasAny || _hasAnyData) _buildRingsAndCards(),
          if (_insight!.stateSummary.isNotEmpty ||
              _insight!.overallInsight.isNotEmpty ||
              _insight!.keywords.isNotEmpty)
            _buildAiAnalysisCard(),
          if (_insight!.recommendations.isNotEmpty) _buildAdviceCard(),
          if (!_localStats.hasAny &&
              !_hasAnyData &&
              _insight!.keywords.isEmpty &&
              _insight!.stateSummary.isEmpty &&
              _insight!.overallInsight.isEmpty &&
              _insight!.recommendations.isEmpty)
            _buildEmpty(),
        ],
      ),
    );
  }

  Widget _buildDateStrip() {
    final today = DateTime.now();
    final days = List.generate(
      14,
      (i) => today.subtract(const Duration(days: 6)).add(Duration(days: i)),
    );
    const weekdayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
    return SizedBox(
      height: 72,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (_, i) {
          final d = days[i];
          final isSelected = _viewWeek
              ? _isSameWeek(d, _selectedDate)
              : _isSameDay(d, _selectedDate);
          return GestureDetector(
            onTap: () => setState(() {
              _selectedDate = d;
              _viewWeek = true;
            }),
            child: Container(
              width: 44,
              margin: const EdgeInsets.only(right: 8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekdayNames[d.weekday - 1],
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 12,
                      color: AppColors.textDark.withValues(alpha: 0.6),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? AppColors.orange : Colors.transparent,
                      border: Border.all(
                        color: isSelected ? AppColors.orange : AppColors.greyMuted,
                        width: 1.5,
                      ),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${d.day}',
                      style: GoogleFonts.alegreyaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSelected ? AppColors.white : AppColors.textDark,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
  bool _isSameWeek(DateTime a, DateTime b) {
    final aStart = a.subtract(Duration(days: a.weekday - 1));
    final bStart = b.subtract(Duration(days: b.weekday - 1));
    return _isSameDay(aStart, bStart);
  }

  Widget _buildRingsAndCards() {
    final stats = _localStats;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Сводка за период',
          style: GoogleFonts.alegreyaSans(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: AppColors.orange,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.textDark,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildRing(
                value: stats.avgMood != null ? stats.avgMood! / 10 : 0,
                label: 'Настроение',
                color: AppColors.orange,
              ),
              _buildRing(
                value: stats.avgSleep != null ? stats.avgSleep! / 10 : 0,
                label: 'Сон',
                color: AppColors.lavender,
              ),
              _buildRing(
                value: stats.avgEnergy != null ? stats.avgEnergy! / 10 : 0,
                label: 'Энергия',
                color: AppColors.lightGreen,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        LayoutBuilder(
          builder: (_, c) {
            final cardWidth = (c.maxWidth - 8) / 2;
            return Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (stats.avgMood != null)
                  _buildMetricCard(
                    cardWidth,
                    'Настроение',
                    '${stats.avgMood!.toStringAsFixed(1)}/10',
                    Icons.mood_rounded,
                    const [Color(0xFFFFAB6D), Color(0xFFFF8A65)],
                  ),
                if (stats.avgSleep != null)
                  _buildMetricCard(
                    cardWidth,
                    'Качество сна',
                    '${stats.avgSleep!.toStringAsFixed(1)}/10',
                    Icons.bedtime_rounded,
                    [AppColors.lavender, AppColors.purple],
                  ),
                if (stats.avgEnergy != null)
                  _buildMetricCard(
                    cardWidth,
                    'Энергия',
                    '${stats.avgEnergy!.toStringAsFixed(1)}/10',
                    Icons.bolt_rounded,
                    [AppColors.lightGreen, const Color(0xFF81C784)],
                  ),
                _buildMetricCard(
                  cardWidth,
                  'Заметок',
                  '${stats.notesCount}',
                  Icons.edit_note_rounded,
                  [AppColors.lightBlue, const Color(0xFF64B5F6)],
                ),
              ],
            );
          },
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildRing({
    required double value,
    required String label,
    required Color color,
  }) {
    final progress = value.clamp(0.0, 1.0);
    return Column(
      children: [
        SizedBox(
          width: 56,
          height: 56,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: const Size(56, 56),
                painter: _RingPainter(
                  progress: progress,
                  color: color,
                  backgroundColor: Colors.white.withValues(alpha: 0.2),
                ),
              ),
              Text(
                progress > 0 ? (progress * 10).toStringAsFixed(0) : '—',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.white,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          label,
          style: GoogleFonts.alegreyaSans(
            fontSize: 12,
            color: Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ],
    );
  }

  Widget _buildMetricCard(
    double width,
    String label,
    String value,
    IconData icon,
    List<Color> gradientColors,
  ) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: gradientColors.first.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white.withValues(alpha: 0.9), size: 18),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.alegreyaSans(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.alegreyaSans(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiAnalysisCard() {
    if (_insight!.stateSummary.isEmpty &&
        _insight!.overallInsight.isEmpty &&
        _insight!.keywords.isEmpty) {
      return const SizedBox.shrink();
    }
    final parts = <String>[];
    if (_insight!.stateSummary.isNotEmpty) parts.add(_insight!.stateSummary);
    if (_insight!.overallInsight.isNotEmpty) parts.add(_insight!.overallInsight);
    final text = parts.join('\n\n');
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.psychology_rounded, color: AppColors.orange, size: 24),
              const SizedBox(width: 10),
              Text(
                'Анализ состояния',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.lightGreen.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'на устройстве',
                  style: GoogleFonts.alegreyaSans(fontSize: 11, color: AppColors.textDark.withValues(alpha: 0.8)),
                ),
              ),
            ],
          ),
          if (text.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              text,
              style: GoogleFonts.alegreyaSans(
                fontSize: 15,
                height: 1.5,
                color: AppColors.textDark,
              ),
            ),
          ],
          if (_insight!.keywords.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _insight!.keywords
                  .take(8)
                  .map((k) => Chip(
                        label: Text(k, style: const TextStyle(fontSize: 12)),
                        backgroundColor: AppColors.orange.withValues(alpha: 0.15),
                        side: BorderSide.none,
                        padding: EdgeInsets.zero,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ))
                  .toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildAdviceCard() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.lightGreen.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb_outline_rounded,
                  color: AppColors.lightGreen, size: 24),
              const SizedBox(width: 10),
              Text(
                'Советы',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._insight!.recommendations.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_circle_outline,
                        color: AppColors.orange, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        r,
                        style: GoogleFonts.alegreyaSans(
                          fontSize: 15,
                          height: 1.4,
                          color: AppColors.textDark,
                        ),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  bool get _hasAnyData {
    if (_data == null) return false;
    return _data!.notes.isNotEmpty ||
        _data!.stateEntries.isNotEmpty ||
        _data!.medications.isNotEmpty ||
        _data!.appointments.isNotEmpty;
  }

  Widget _buildDataSummary() {
    final d = _data!;
    final parts = <String>[];
    if (d.notes.isNotEmpty) parts.add('${d.notes.length} ${_plural(d.notes.length, 'заметка', 'заметки', 'заметок')}');
    if (d.stateEntries.isNotEmpty) parts.add('${d.stateEntries.length} ${_plural(d.stateEntries.length, 'запись', 'записи', 'записей')} о состоянии');
    if (d.medications.isNotEmpty) parts.add('${d.medications.length} ${_plural(d.medications.length, 'препарат', 'препарата', 'препаратов')}');
    if (d.appointments.isNotEmpty) parts.add('${d.appointments.length} ${_plural(d.appointments.length, 'визит', 'визита', 'визитов')}');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.orange.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.analytics_outlined, color: AppColors.orange, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'На основе: ${parts.join(', ')}',
                style: GoogleFonts.alegreyaSans(
                  fontSize: 14,
                  color: AppColors.textDark.withValues(alpha: 0.9),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _plural(int n, String one, String few, String many) {
    if (n % 10 == 1 && n % 100 != 11) return one;
    if (n % 10 >= 2 && n % 10 <= 4 && (n % 100 < 10 || n % 100 >= 20)) return few;
    return many;
  }

  Widget _buildEmpty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.insights_rounded,
                size: 64, color: AppColors.orange.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              'Добавьте заметки, записи о состоянии (кнопка +), препараты и визиты. Анализ выполняется локально — чем больше данных, тем точнее выводы',
              textAlign: TextAlign.center,
              style: GoogleFonts.alegreyaSans(
                fontSize: 16,
                color: AppColors.textDark.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String msg) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Text(
          msg,
          textAlign: TextAlign.center,
          style: GoogleFonts.alegreyaSans(
            fontSize: 16,
            color: Colors.red.shade700,
          ),
        ),
      ),
    );
  }

}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  final double progress;
  final Color color;
  final Color backgroundColor;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 4;
    final strokeWidth = 5.0;

    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, bgPaint);

    if (progress > 0) {
      final paint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;
      const startAngle = -3.14159 / 2; // top
      final sweepAngle = 2 * 3.14159 * progress;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) =>
      old.progress != progress || old.color != color;
}
