import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import '../config/app_colors.dart';
import '../models/performance_section.dart';
import '../models/metric_history.dart';

class PerformanceDetailScreen extends StatelessWidget {
  final PerformanceItem item;
  final List<MetricHistoryPoint> history;
  final String? sectionTitle;

  const PerformanceDetailScreen({
    super.key,
    required this.item,
    this.history = const [],
    this.sectionTitle,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.text,
        title: Text(item.name),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Current value card
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Aktueller Wert',
                            style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          item.value,
                          style: const TextStyle(
                            color: AppColors.text,
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                    const Spacer(),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Vorher',
                            style: TextStyle(color: AppColors.muted, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          item.previousValue,
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: _changeColor.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        item.change,
                        style: TextStyle(
                          color: _changeColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // History chart
              if (history.isNotEmpty) ...[
                const Text(
                  'Verlauf',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  height: 240,
                  padding: const EdgeInsets.fromLTRB(8, 20, 16, 8),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: _yInterval,
                        getDrawingHorizontalLine: (value) => FlLine(
                          color: AppColors.border,
                          strokeWidth: 1,
                        ),
                      ),
                      titlesData: FlTitlesData(
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 30,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              if (idx < 0 || idx >= history.length) {
                                return const SizedBox.shrink();
                              }
                              return Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  DateFormat('MMM yy')
                                      .format(history[idx].date),
                                  style: const TextStyle(
                                      color: AppColors.muted, fontSize: 10),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 40,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                value.toStringAsFixed(
                                    value == value.roundToDouble() ? 0 : 1),
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 10),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: List.generate(
                            history.length,
                            (i) => FlSpot(i.toDouble(), history[i].value),
                          ),
                          isCurved: true,
                          color: AppColors.primary,
                          barWidth: 3,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                              radius: 4,
                              color: AppColors.primary,
                              strokeWidth: 2,
                              strokeColor: AppColors.surface,
                            ),
                          ),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppColors.primary.withOpacity(0.1),
                          ),
                        ),
                      ],
                      minY: _minY,
                      maxY: _maxY,
                    ),
                  ),
                ),
              ] else
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Center(
                    child: Text(
                      'Kein Verlauf vorhanden',
                      style: TextStyle(color: AppColors.muted, fontSize: 14),
                    ),
                  ),
                ),

              // History table
              if (history.isNotEmpty) ...[
                const SizedBox(height: 24),
                const Text(
                  'Messwerte',
                  style: TextStyle(
                    color: AppColors.text,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                ...history.reversed.map((p) => Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Row(
                        children: [
                          Text(
                            DateFormat('dd.MM.yyyy').format(p.date),
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13),
                          ),
                          const Spacer(),
                          Text(
                            '${p.value}${p.unit.isNotEmpty ? ' ${p.unit}' : ''}',
                            style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color get _changeColor {
    if (item.change.startsWith('+')) return AppColors.green;
    if (item.change.startsWith('-')) return AppColors.red;
    return AppColors.muted;
  }

  double get _minY {
    if (history.isEmpty) return 0;
    final min = history.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final range = _maxY - min;
    return min - range * 0.1;
  }

  double get _maxY {
    if (history.isEmpty) return 100;
    final max = history.map((p) => p.value).reduce((a, b) => a > b ? a : b);
    final min = history.map((p) => p.value).reduce((a, b) => a < b ? a : b);
    final range = max - min;
    return max + range * 0.1;
  }

  double get _yInterval {
    final range = _maxY - _minY;
    if (range <= 0) return 1;
    if (range <= 5) return 1;
    if (range <= 20) return 5;
    if (range <= 50) return 10;
    return 20;
  }
}
