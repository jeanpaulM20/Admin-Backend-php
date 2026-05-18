import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../models/training_review.dart';

class TrainingReviewDetailScreen extends StatelessWidget {
  final TrainingReview review;

  const TrainingReviewDetailScreen({super.key, required this.review});

  Widget _buildTrainingLoadCard(double? trimp) {
    final value = trimp != null ? trimp.round().toString() : '--';
    final color = trimp != null ? TrainingReview.trimpColor(trimp) : AppColors.muted;
    final rating = trimp != null ? TrainingReview.trimpRating(trimp) : '';
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(children: [
          Text(value,
              style: GoogleFonts.montserrat(color: color, fontSize: 18, fontWeight: FontWeight.w800),
              textAlign: TextAlign.center),
          const Text('Load', style: TextStyle(color: AppColors.muted, fontSize: 10)),
          if (rating.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(rating, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center),
          ] else
            const SizedBox(height: 2),
          const Text('Training Load', style: TextStyle(color: AppColors.muted, fontSize: 10),
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','Mar','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    return '${dt.day}. ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    final chart = review.chart;
    final hasChart = chart.length >= 2;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(review.trainingType,
                style: GoogleFonts.montserrat(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
            Text(_formatDate(review.date),
                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
          ],
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.border, height: 1),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Stat cards - row of 3
          Row(children: [
            _StatCard(label: 'Max HF', value: review.hrMax != null ? '${review.hrMax}' : '-', unit: 'bpm', color: AppColors.red),
            const SizedBox(width: 10),
            _StatCard(label: 'Avg HF', value: review.hrAvg != null ? '${review.hrAvg}' : '-', unit: 'bpm', color: AppColors.primary),
            const SizedBox(width: 10),
            _buildTrainingLoadCard(review.edwardsTrimp),
          ]),

          if (review.duration != null) ...[
            const SizedBox(height: 12),
            Center(child: Text('Dauer: ${review.duration}',
                style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          ],

          const SizedBox(height: 24),

          // HR Chart
          if (hasChart) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(8, 20, 16, 12),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text('Herzfrequenz-Verlauf (bpm)',
                              style: GoogleFonts.montserrat(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                        ),
                        GestureDetector(
                          onTap: () => _openFullscreenChart(context),
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Icon(Icons.fullscreen_rounded, color: AppColors.muted, size: 20),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    height: 220,
                    child: _buildHrChart(chart),
                  ),
                ],
              ),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.border)),
              child: const Center(child: Text('Keine HF-Kurvendaten vorhanden', style: TextStyle(color: AppColors.muted, fontSize: 13))),
            ),
          ],
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _openFullscreenChart(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => _HrChartFullScreen(
          chart: review.chart,
          title: review.trainingType,
          date: _formatDate(review.date),
          hrMax: review.hrMax,
          hrAvg: review.hrAvg,
          duration: review.duration,
        ),
      ),
    );
  }

  static Widget _buildHrChart(List<HrPoint> chart, {bool showTooltip = false, double lineWidth = 2}) {
    final minY = (chart.map((p) => p.value).reduce((a, b) => a < b ? a : b) - 5).clamp(0.0, 300.0);
    final maxY = chart.map((p) => p.value).reduce((a, b) => a > b ? a : b) + 5;

    return LineChart(LineChartData(
      minY: minY,
      maxY: maxY,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
      ),
      borderData: FlBorderData(show: false),
      lineTouchData: showTooltip
          ? LineTouchData(
              enabled: true,
              touchTooltipData: LineTouchTooltipData(
                getTooltipColor: (_) => AppColors.surface,
                tooltipBorder: const BorderSide(color: AppColors.border),
                tooltipRoundedRadius: 8,
                getTooltipItems: (spots) => spots.map((s) {
                  final idx = s.x.toInt();
                  final time = idx < chart.length ? (chart[idx].time ?? '') : '';
                  return LineTooltipItem(
                    '${s.y.toInt()} bpm${time.isNotEmpty ? '\n$time' : ''}',
                    const TextStyle(color: AppColors.red, fontSize: 12, fontWeight: FontWeight.w600),
                  );
                }).toList(),
              ),
              getTouchedSpotIndicator: (_, spots) => spots.map((_) => TouchedSpotIndicatorData(
                FlLine(color: AppColors.red.withOpacity(0.4), strokeWidth: 1, dashArray: [4, 4]),
                FlDotData(show: true, getDotPainter: (_, __, ___, ____) =>
                    FlDotCirclePainter(radius: 4, color: AppColors.red, strokeColor: AppColors.surface, strokeWidth: 2)),
              )).toList(),
            )
          : const LineTouchData(enabled: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 36,
          getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24,
          getTitlesWidget: (v, _) {
            final idx = v.toInt();
            final show = {0, chart.length ~/ 4, chart.length ~/ 2, (chart.length * 3) ~/ 4, chart.length - 1};
            if (!show.contains(idx) || idx >= chart.length) return const SizedBox.shrink();
            return Padding(padding: const EdgeInsets.only(top: 4),
              child: Text(chart[idx].time ?? '', style: const TextStyle(color: AppColors.muted, fontSize: 9)));
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: [
        LineChartBarData(
          spots: chart.asMap().entries.map((e) => FlSpot(e.key.toDouble(), e.value.value)).toList(),
          isCurved: true, curveSmoothness: 0.2,
          color: AppColors.red, barWidth: lineWidth,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: true,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [AppColors.red.withOpacity(0.15), AppColors.red.withOpacity(0.0)])),
        ),
      ],
    ));
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// Fullscreen Landscape HR Chart
// ═══════════════════════════════════════════════════════════════════════════════

class _HrChartFullScreen extends StatefulWidget {
  final List<HrPoint> chart;
  final String title;
  final String date;
  final int? hrMax;
  final int? hrAvg;
  final String? duration;

  const _HrChartFullScreen({
    required this.chart,
    required this.title,
    required this.date,
    this.hrMax,
    this.hrAvg,
    this.duration,
  });

  @override
  State<_HrChartFullScreen> createState() => _HrChartFullScreenState();
}

class _HrChartFullScreenState extends State<_HrChartFullScreen> {
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            children: [
              // Header row
              Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: const Icon(Icons.fullscreen_exit_rounded, color: AppColors.muted, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Herzfrequenz-Verlauf',
                      style: GoogleFonts.montserrat(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                  ),
                  // Stats chips
                  if (widget.hrMax != null)
                    _chipStat('Max', '${widget.hrMax}', AppColors.red),
                  const SizedBox(width: 6),
                  if (widget.hrAvg != null)
                    _chipStat('Avg', '${widget.hrAvg}', AppColors.primary),
                  if (widget.duration != null) ...[
                    const SizedBox(width: 6),
                    _chipStat('Dauer', widget.duration!, AppColors.muted),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // Chart - fills remaining space
              Expanded(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: TrainingReviewDetailScreen._buildHrChart(
                    widget.chart,
                    showTooltip: true,
                    lineWidth: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _chipStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ', style: TextStyle(color: color.withOpacity(0.7), fontSize: 10)),
        Text(value, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label, value, unit;
  final Color color;
  const _StatCard({required this.label, required this.value, required this.unit, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
        child: Column(children: [
          Text(value, style: GoogleFonts.montserrat(color: color, fontSize: 18, fontWeight: FontWeight.w800), textAlign: TextAlign.center),
          Text(unit, style: const TextStyle(color: AppColors.muted, fontSize: 10)),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(color: AppColors.muted, fontSize: 10), textAlign: TextAlign.center),
        ]),
      ),
    );
  }
}
