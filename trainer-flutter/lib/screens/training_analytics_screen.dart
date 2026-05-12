import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/training.dart';
import '../config/app_colors.dart';

/// Analytics dashboard for trainer business overview.
/// Shows weekly load, cancellation rate, client distribution, monthly trend.
class TrainingAnalytics extends StatelessWidget {
  final List<Training> trainings;

  const TrainingAnalytics({super.key, required this.trainings});

  @override
  Widget build(BuildContext context) {
    if (trainings.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bar_chart_outlined, color: AppColors.muted, size: 48),
            SizedBox(height: 12),
            Text('Keine Trainingsdaten vorhanden',
                style: TextStyle(color: AppColors.muted, fontSize: 15)),
          ],
        ),
      );
    }

    final stats = _TrainingStats(trainings);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      children: [
        // ── KPI Row ──────────────────────────────────────────────
        _buildKpiRow(stats),
        const SizedBox(height: 20),

        // ── Weekly workload bar chart (last 8 weeks) ─────────────
        _SectionCard(
          title: 'Wöchentliche Auslastung',
          subtitle: 'Letzte 8 Wochen',
          child: SizedBox(
            height: 200,
            child: _WeeklyBarChart(stats: stats),
          ),
        ),
        const SizedBox(height: 16),

        // ── Monthly trend line chart ─────────────────────────────
        _SectionCard(
          title: 'Monatlicher Trend',
          subtitle: 'Trainings pro Monat',
          child: SizedBox(
            height: 200,
            child: _MonthlyLineChart(stats: stats),
          ),
        ),
        const SizedBox(height: 16),

        // ── Cancellation pie + status breakdown ──────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _SectionCard(
                title: 'Status',
                subtitle: 'Alle Trainings',
                child: SizedBox(
                  height: 180,
                  child: _StatusPieChart(stats: stats),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _SectionCard(
                title: 'Top Kunden',
                subtitle: 'Nach Trainings',
                child: SizedBox(
                  height: 180,
                  child: _TopClientsList(stats: stats),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Weekday heatmap ──────────────────────────────────────
        _SectionCard(
          title: 'Beliebteste Tage',
          subtitle: 'Verteilung nach Wochentag',
          child: SizedBox(
            height: 160,
            child: _WeekdayChart(stats: stats),
          ),
        ),
        const SizedBox(height: 16),

        // ── Peak hours ───────────────────────────────────────────
        _SectionCard(
          title: 'Stoßzeiten',
          subtitle: 'Trainings nach Uhrzeit',
          child: SizedBox(
            height: 160,
            child: _HourlyChart(stats: stats),
          ),
        ),
      ],
    );
  }

  Widget _buildKpiRow(_TrainingStats stats) {
    return Row(
      children: [
        _KpiTile(
          icon: Icons.fitness_center,
          label: 'Gesamt',
          value: '${stats.total}',
          color: AppColors.primary,
        ),
        const SizedBox(width: 10),
        _KpiTile(
          icon: Icons.check_circle_outline,
          label: 'Durchgeführt',
          value: '${stats.completed}',
          color: AppColors.green,
        ),
        const SizedBox(width: 10),
        _KpiTile(
          icon: Icons.cancel_outlined,
          label: 'Abgesagt',
          value: '${stats.cancelled}',
          color: AppColors.red,
          subtitle: '${stats.cancelRate.toStringAsFixed(0)}%',
        ),
        const SizedBox(width: 10),
        _KpiTile(
          icon: Icons.people_outline,
          label: 'Kunden',
          value: '${stats.uniqueClients}',
          color: AppColors.blue,
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Stats engine — pre-computes all analytics from raw training list
// ═══════════════════════════════════════════════════════════════════════════

class _TrainingStats {
  final List<Training> all;
  late final int total;
  late final int cancelled;
  late final int completed;
  late final double cancelRate;
  late final int uniqueClients;
  late final Map<String, int> weeklyLoad;    // "2024-W03" → count
  late final Map<String, int> monthlyTotal;  // "2024-01" → count
  late final Map<String, int> monthlyCancelled;
  late final Map<int, int> byWeekday;        // 1=Mon → count
  late final Map<int, int> byHour;           // 7..21 → count
  late final Map<String, int> clientCounts;  // name → count

  _TrainingStats(this.all) {
    total = all.length;
    cancelled = all.where((t) => t.isCancelled).length;
    completed = total - cancelled;
    cancelRate = total > 0 ? (cancelled / total) * 100 : 0;
    uniqueClients = all.map((t) => t.clientId ?? t.clientName ?? '').toSet().length;

    // ── Weekly load (last 8 weeks) ───────────────────────────────
    weeklyLoad = {};
    final now = DateTime.now();
    for (var i = 7; i >= 0; i--) {
      final weekStart = now.subtract(Duration(days: now.weekday - 1 + i * 7));
      final key = _weekKey(weekStart);
      weeklyLoad[key] = 0;
    }
    for (final t in all) {
      if (t.startTime == null || t.isCancelled) continue;
      final key = _weekKey(t.startTime!);
      if (weeklyLoad.containsKey(key)) weeklyLoad[key] = weeklyLoad[key]! + 1;
    }

    // ── Monthly totals ───────────────────────────────────────────
    monthlyTotal = {};
    monthlyCancelled = {};
    for (final t in all) {
      if (t.startTime == null) continue;
      final key = DateFormat('yyyy-MM').format(t.startTime!);
      monthlyTotal[key] = (monthlyTotal[key] ?? 0) + 1;
      if (t.isCancelled) monthlyCancelled[key] = (monthlyCancelled[key] ?? 0) + 1;
    }

    // ── By weekday ───────────────────────────────────────────────
    byWeekday = {for (var i = 1; i <= 7; i++) i: 0};
    for (final t in all) {
      if (t.startTime == null || t.isCancelled) continue;
      byWeekday[t.startTime!.weekday] = byWeekday[t.startTime!.weekday]! + 1;
    }

    // ── By hour ──────────────────────────────────────────────────
    byHour = {for (var h = 6; h <= 21; h++) h: 0};
    for (final t in all) {
      if (t.startTime == null || t.isCancelled) continue;
      final h = t.startTime!.hour;
      if (byHour.containsKey(h)) byHour[h] = byHour[h]! + 1;
    }

    // ── Client distribution ──────────────────────────────────────
    clientCounts = {};
    for (final t in all) {
      if (t.isCancelled) continue;
      final name = t.clientName ?? 'Unbekannt';
      clientCounts[name] = (clientCounts[name] ?? 0) + 1;
    }
  }

  String _weekKey(DateTime d) {
    final monday = d.subtract(Duration(days: d.weekday - 1));
    return DateFormat('dd.MM').format(monday);
  }

  List<MapEntry<String, int>> get sortedMonths {
    final entries = monthlyTotal.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    // Last 6 months
    return entries.length > 6 ? entries.sublist(entries.length - 6) : entries;
  }

  List<MapEntry<String, int>> get topClients {
    final sorted = clientCounts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return sorted.take(5).toList();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Reusable widgets
// ═══════════════════════════════════════════════════════════════════════════

class _KpiTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final String? subtitle;

  const _KpiTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withOpacity(0.25)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 6),
            Text(value,
                style: GoogleFonts.montserrat(
                    color: AppColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
            if (subtitle != null)
              Text(subtitle!,
                  style: GoogleFonts.openSans(color: color, fontSize: 11, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(label,
                style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 10),
                textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.montserrat(
                  color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
          Text(subtitle,
              style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 11)),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Charts
// ═══════════════════════════════════════════════════════════════════════════

class _WeeklyBarChart extends StatelessWidget {
  final _TrainingStats stats;
  const _WeeklyBarChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final entries = stats.weeklyLoad.entries.toList();
    final maxY = entries.fold<int>(0, (m, e) => e.value > m ? e.value : m).toDouble();

    return BarChart(
      BarChartData(
        maxY: (maxY + 2).ceilToDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface2,
            getTooltipItem: (group, gIdx, rod, rIdx) {
              return BarTooltipItem(
                '${rod.toY.toInt()} Trainings',
                GoogleFonts.openSans(color: AppColors.text, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= entries.length) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(entries[idx].key,
                      style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 9)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) {
                if (value == value.roundToDouble() && value >= 0) {
                  return Text('${value.toInt()}',
                      style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 10));
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, 100),
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.5),
            strokeWidth: 0.8,
          ),
        ),
        barGroups: entries.asMap().entries.map((e) {
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: e.value.value.toDouble(),
                color: AppColors.primary,
                width: 22,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: (maxY + 2).ceilToDouble(),
                  color: AppColors.primary.withOpacity(0.06),
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MonthlyLineChart extends StatelessWidget {
  final _TrainingStats stats;
  const _MonthlyLineChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final months = stats.sortedMonths;
    if (months.isEmpty) return const Center(child: Text('Keine Daten', style: TextStyle(color: AppColors.muted)));

    final maxY = months.fold<int>(0, (m, e) => e.value > m ? e.value : m).toDouble();
    final cancelledSpots = <FlSpot>[];
    final totalSpots = <FlSpot>[];

    for (var i = 0; i < months.length; i++) {
      totalSpots.add(FlSpot(i.toDouble(), months[i].value.toDouble()));
      cancelledSpots.add(FlSpot(i.toDouble(),
          (stats.monthlyCancelled[months[i].key] ?? 0).toDouble()));
    }

    return LineChart(
      LineChartData(
        maxY: (maxY + 3).ceilToDouble(),
        minY: 0,
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface2,
            getTooltipItems: (spots) => spots.map((s) {
              final color = s.barIndex == 0 ? AppColors.primary : AppColors.red;
              final label = s.barIndex == 0 ? 'Gesamt' : 'Abgesagt';
              return LineTooltipItem(
                '$label: ${s.y.toInt()}',
                GoogleFonts.openSans(color: color, fontSize: 11, fontWeight: FontWeight.w600),
              );
            }).toList(),
          ),
        ),
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (maxY / 4).ceilToDouble().clamp(1, 100),
          getDrawingHorizontalLine: (value) => FlLine(
            color: AppColors.border.withOpacity(0.5),
            strokeWidth: 0.8,
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 30,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= months.length) return const SizedBox();
                final parts = months[idx].key.split('-');
                final monthNames = ['', 'Jan', 'Feb', 'Mär', 'Apr', 'Mai', 'Jun', 'Jul', 'Aug', 'Sep', 'Okt', 'Nov', 'Dez'];
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(monthNames[int.parse(parts[1])],
                      style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, _) {
                if (value == value.roundToDouble() && value >= 0) {
                  return Text('${value.toInt()}',
                      style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 10));
                }
                return const SizedBox();
              },
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        lineBarsData: [
          LineChartBarData(
            spots: totalSpots,
            isCurved: true,
            color: AppColors.primary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
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
          LineChartBarData(
            spots: cancelledSpots,
            isCurved: true,
            color: AppColors.red,
            barWidth: 2,
            dashArray: [6, 4],
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                radius: 3,
                color: AppColors.red,
                strokeWidth: 2,
                strokeColor: AppColors.surface,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusPieChart extends StatelessWidget {
  final _TrainingStats stats;
  const _StatusPieChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sectionsSpace: 3,
              centerSpaceRadius: 28,
              sections: [
                PieChartSectionData(
                  value: stats.completed.toDouble(),
                  color: AppColors.green,
                  radius: 32,
                  title: '${stats.completed}',
                  titleStyle: GoogleFonts.montserrat(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
                PieChartSectionData(
                  value: stats.cancelled.toDouble(),
                  color: AppColors.red,
                  radius: 28,
                  title: '${stats.cancelled}',
                  titleStyle: GoogleFonts.montserrat(
                      color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _LegendDot(color: AppColors.green, label: 'OK'),
            const SizedBox(width: 12),
            _LegendDot(color: AppColors.red, label: 'Abgesagt'),
          ],
        ),
      ],
    );
  }
}

class _TopClientsList extends StatelessWidget {
  final _TrainingStats stats;
  const _TopClientsList({required this.stats});

  @override
  Widget build(BuildContext context) {
    final top = stats.topClients;
    if (top.isEmpty) {
      return const Center(
        child: Text('Keine Daten', style: TextStyle(color: AppColors.muted, fontSize: 12)),
      );
    }

    return Column(
      children: top.asMap().entries.map((e) {
        final idx = e.key;
        final client = e.value;
        final maxCount = top.first.value;
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: Text('${idx + 1}.',
                    style: GoogleFonts.openSans(
                        color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600)),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(client.key,
                        style: GoogleFonts.openSans(
                            color: AppColors.text, fontSize: 11, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    LinearProgressIndicator(
                      value: maxCount > 0 ? client.value / maxCount : 0,
                      backgroundColor: AppColors.border,
                      color: AppColors.blue.withOpacity(0.7),
                      minHeight: 4,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Text('${client.value}',
                  style: GoogleFonts.montserrat(
                      color: AppColors.blue, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _WeekdayChart extends StatelessWidget {
  final _TrainingStats stats;
  const _WeekdayChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final dayNames = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    final maxVal = stats.byWeekday.values.fold<int>(0, (m, v) => v > m ? v : m);

    return BarChart(
      BarChartData(
        maxY: (maxVal + 2).ceilToDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface2,
            getTooltipItem: (group, gIdx, rod, rIdx) {
              return BarTooltipItem(
                '${dayNames[group.x]} · ${rod.toY.toInt()}',
                GoogleFonts.openSans(color: AppColors.text, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx > 6) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(dayNames[idx],
                      style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 10)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: List.generate(7, (i) {
          final val = stats.byWeekday[i + 1] ?? 0;
          final isWeekend = i >= 5;
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: val.toDouble(),
                color: isWeekend ? AppColors.orange.withOpacity(0.7) : AppColors.blue,
                width: 28,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
              ),
            ],
          );
        }),
      ),
    );
  }
}

class _HourlyChart extends StatelessWidget {
  final _TrainingStats stats;
  const _HourlyChart({required this.stats});

  @override
  Widget build(BuildContext context) {
    final hours = stats.byHour.entries.toList()..sort((a, b) => a.key.compareTo(b.key));
    final maxVal = hours.fold<int>(0, (m, e) => e.value > m ? e.value : m);

    return BarChart(
      BarChartData(
        maxY: (maxVal + 2).ceilToDouble(),
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            getTooltipColor: (_) => AppColors.surface2,
            getTooltipItem: (group, gIdx, rod, rIdx) {
              final hour = hours[group.x].key;
              return BarTooltipItem(
                '$hour:00 · ${rod.toY.toInt()}',
                GoogleFonts.openSans(color: AppColors.text, fontSize: 11),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, _) {
                final idx = value.toInt();
                if (idx < 0 || idx >= hours.length) return const SizedBox();
                final h = hours[idx].key;
                // Only show every 2nd label
                if (h % 2 != 0) return const SizedBox();
                return Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('$h',
                      style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 9)),
                );
              },
            ),
          ),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        barGroups: hours.asMap().entries.map((e) {
          final val = e.value.value;
          return BarChartGroupData(
            x: e.key,
            barRods: [
              BarChartRodData(
                toY: val.toDouble(),
                color: AppColors.primary.withOpacity(val > 0 ? 1.0 : 0.2),
                width: 14,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8, height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.openSans(color: AppColors.muted, fontSize: 10)),
      ],
    );
  }
}
