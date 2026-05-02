import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../config/app_colors.dart';
import '../models/training_review.dart';

const _lineColors = [
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFFF7043),
  Color(0xFFAB47BC),
];

class TrainingCompareScreen extends StatelessWidget {
  final List<TrainingReview> reviews;

  const TrainingCompareScreen({super.key, required this.reviews});

  String _formatDate(DateTime dt) {
    const months = ['Jan','Feb','MÃ¤r','Apr','Mai','Jun','Jul','Aug','Sep','Okt','Nov','Dez'];
    return '${dt.day}. ${months[dt.month - 1]} ${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Only include reviews that have chart data
    final withChart = reviews.where((r) => r.chart.length >= 2).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.text, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Vergleich',
            style: GoogleFonts.montserrat(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.border, height: 1),
        ),
      ),
      body: withChart.isEmpty
          ? const Center(child: Text('Keine Kurvendaten vorhanden', style: TextStyle(color: AppColors.muted)))
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                // Legend
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: withChart.asMap().entries.map((e) {
                      final color = _lineColors[e.key % _lineColors.length];
                      final r = e.value;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 24, height: 3,
                              decoration: BoxDecoration(
                                color: color,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(r.trainingType,
                                  style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                            ),
                            Text(_formatDate(r.date),
                                style: const TextStyle(color: AppColors.muted, fontSize: 11)),
                            if (r.hrMax != null) ...[
                              const SizedBox(width: 8),
                              Text('${r.hrMax} bpm',
                                  style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const SizedBox(height: 16),

                // Chart
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
                        padding: const EdgeInsets.only(left: 8, bottom: 4),
                        child: Text('Herzfrequenz-Verlauf (bpm)',
                            style: GoogleFonts.montserrat(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 8, bottom: 14),
                        child: Text('X-Achse: Trainingsverlauf in %',
                            style: const TextStyle(color: AppColors.muted, fontSize: 10)),
                      ),
                      SizedBox(
                        height: 260,
                        child: LineChart(_buildChartData(withChart)),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Stats comparison table
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: AppColors.border)),
                        ),
                        child: Row(
                          children: const [
                            Expanded(flex: 3, child: Text('Training', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600))),
                            Expanded(flex: 2, child: Text('Max HF', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('Avg HF', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                            Expanded(flex: 2, child: Text('HRR', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
                          ],
                        ),
                      ),
                      ...withChart.asMap().entries.map((e) {
                        final color = _lineColors[e.key % _lineColors.length];
                        final r = e.value;
                        final isLast = e.key == withChart.length - 1;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: e.key.isEven ? Colors.transparent : AppColors.surface2.withOpacity(0.4),
                            border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: Row(
                                  children: [
                                    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                                    const SizedBox(width: 6),
                                    Expanded(child: Text(_formatDate(r.date),
                                        style: const TextStyle(color: AppColors.text, fontSize: 12))),
                                  ],
                                ),
                              ),
                              Expanded(flex: 2, child: Text(r.hrMax != null ? '${r.hrMax}' : 'â€“',
                                  style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text(r.hrAvg != null ? '${r.hrAvg}' : 'â€“',
                                  style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                              Expanded(flex: 2, child: Text(r.hrr != null ? '${r.hrr}' : 'â€“',
                                  style: const TextStyle(color: AppColors.text, fontSize: 13, fontWeight: FontWeight.w700), textAlign: TextAlign.center)),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),

                const SizedBox(height: 32),
              ],
            ),
    );
  }

  LineChartData _buildChartData(List<TrainingReview> withChart) {
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;

    for (final r in withChart) {
      for (final p in r.chart) {
        if (p.value < globalMin) globalMin = p.value;
        if (p.value > globalMax) globalMax = p.value;
      }
    }

    return LineChartData(
      minX: 0, maxX: 100,
      minY: (globalMin - 5).clamp(0, 300),
      maxY: globalMax + 5,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) => FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 36,
          getTitlesWidget: (v, _) => Text('${v.toInt()}', style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        )),
        bottomTitles: AxisTitles(sideTitles: SideTitles(
          showTitles: true, reservedSize: 24,
          getTitlesWidget: (v, _) {
            if (v == 0 || v == 50 || v == 100) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${v.toInt()}%', style: const TextStyle(color: AppColors.muted, fontSize: 9)),
              );
            }
            return const SizedBox.shrink();
          },
        )),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      lineBarsData: withChart.asMap().entries.map((e) {
        final color = _lineColors[e.key % _lineColors.length];
        final pts = e.value.chart;
        final n = pts.length;
        return LineChartBarData(
          // Normalize x to 0â€“100%
          spots: pts.asMap().entries.map((p) =>
              FlSpot(p.key / (n - 1) * 100, p.value.value)).toList(),
          isCurved: true, curveSmoothness: 0.2,
          color: color, barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        );
      }).toList(),
    );
  }
}
