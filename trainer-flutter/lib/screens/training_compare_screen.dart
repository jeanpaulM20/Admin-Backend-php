import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/review.dart';
import '../models/client.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

const _lineColors = [
  Color(0xFFEF5350),
  Color(0xFF42A5F5),
  Color(0xFF66BB6A),
  Color(0xFFFF7043),
  Color(0xFFAB47BC),
  Color(0xFF26C6DA),
  Color(0xFFFFCA28),
  Color(0xFF78909C),
];

/// Compare heart-rate curves of multiple training recordings side by side.
class TrainingCompareScreen extends StatefulWidget {
  final List<Review> reviews;
  final Client client;

  const TrainingCompareScreen({
    super.key,
    required this.reviews,
    required this.client,
  });

  @override
  State<TrainingCompareScreen> createState() => _TrainingCompareScreenState();
}

class _TrainingCompareScreenState extends State<TrainingCompareScreen> {
  final ApiService _api = ApiService();
  final Map<int, List<HeartRatePoint>> _tsCache = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAllTimeseries();
  }

  Future<void> _loadAllTimeseries() async {
    setState(() => _loading = true);
    await Future.wait(widget.reviews.map((r) async {
      // Use embedded timeseries if available
      if (r.timeseries.isNotEmpty) {
        _tsCache[r.id] = r.timeseries;
        return;
      }
      // Otherwise load from API
      try {
        final data = await _api.get('${ApiConfig.review}/${r.id}/timeseries');
        if (data is List) {
          _tsCache[r.id] = data
              .map((e) => HeartRatePoint.fromJson(e as Map<String, dynamic>))
              .toList();
        }
      } catch (_) {
        _tsCache[r.id] = [];
      }
    }));
    if (mounted) setState(() => _loading = false);
  }

  String _formatDate(Review r) {
    final d = r.trainingDate;
    if (d == null) return '–';
    try {
      final date = DateTime.parse(d);
      return DateFormat('dd.MM.yyyy').format(date);
    } catch (_) {
      return d;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              color: AppColors.text, size: 18),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Trainingsvergleich',
            style: TextStyle(
                color: AppColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w700)),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(color: AppColors.border, height: 1),
        ),
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : _buildContent(),
    );
  }

  Widget _buildContent() {
    // Filter to only reviews with valid HR data
    final withChart = widget.reviews.where((r) {
      final pts = _tsCache[r.id] ?? [];
      final valid = pts.where((p) => p.value != null && p.value! > 0).toList();
      return valid.length >= 2;
    }).toList();

    if (withChart.isEmpty) {
      return const Center(
        child: Text('Keine Herzfrequenz-Daten zum Vergleichen vorhanden',
            style: TextStyle(color: AppColors.muted)),
      );
    }

    return ListView(
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
              final pts = _tsCache[r.id] ?? [];
              final validPts =
                  pts.where((p) => p.value != null && p.value! > 0);
              final maxHr = validPts.isNotEmpty
                  ? validPts
                      .map((p) => p.value!)
                      .reduce((a, b) => a > b ? a : b)
                      .round()
                  : null;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 24,
                      height: 3,
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(r.trainingTypeLabel,
                          style: const TextStyle(
                              color: AppColors.text,
                              fontSize: 13,
                              fontWeight: FontWeight.w600)),
                    ),
                    Text(_formatDate(r),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 11)),
                    if (maxHr != null) ...[
                      const SizedBox(width: 8),
                      Text('$maxHr bpm',
                          style: TextStyle(
                              color: color,
                              fontSize: 11,
                              fontWeight: FontWeight.w700)),
                    ],
                  ],
                ),
              );
            }).toList(),
          ),
        ),

        const SizedBox(height: 16),

        // HR overlay chart
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
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 4),
                child: Text('Herzfrequenz-Verlauf (bpm)',
                    style: TextStyle(
                        color: AppColors.text,
                        fontSize: 14,
                        fontWeight: FontWeight.w700)),
              ),
              const Padding(
                padding: EdgeInsets.only(left: 8, bottom: 14),
                child: Text('X-Achse: Trainingsverlauf in %',
                    style: TextStyle(color: AppColors.muted, fontSize: 10)),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppColors.border)),
                ),
                child: const Row(
                  children: [
                    Expanded(
                        flex: 3,
                        child: Text('Training',
                            style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600))),
                    Expanded(
                        flex: 2,
                        child: Text('Max HF',
                            style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text('Avg HF',
                            style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center)),
                    Expanded(
                        flex: 2,
                        child: Text('TRIMP',
                            style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                                fontWeight: FontWeight.w600),
                            textAlign: TextAlign.center)),
                  ],
                ),
              ),
              ...withChart.asMap().entries.map((e) {
                final color = _lineColors[e.key % _lineColors.length];
                final r = e.value;
                final pts = (_tsCache[r.id] ?? [])
                    .where((p) => p.value != null && p.value! > 0)
                    .toList();
                final maxHr = pts.isNotEmpty
                    ? pts
                        .map((p) => p.value!)
                        .reduce((a, b) => a > b ? a : b)
                        .round()
                    : null;
                final avgHr = pts.isNotEmpty
                    ? (pts.fold<double>(0, (s, p) => s + p.value!) /
                            pts.length)
                        .round()
                    : null;
                final trimp = Review.edwardsTrimp(
                    _tsCache[r.id] ?? [],
                    widget.client.maxHeartRate ?? 220,
                    r.duration);
                final isLast = e.key == withChart.length - 1;
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: e.key.isEven
                        ? Colors.transparent
                        : AppColors.surface2.withAlpha(100),
                    border: isLast
                        ? null
                        : const Border(
                            bottom: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        flex: 3,
                        child: Row(
                          children: [
                            Container(
                                width: 10,
                                height: 10,
                                decoration: BoxDecoration(
                                    color: color, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Expanded(
                                child: Text(_formatDate(r),
                                    style: const TextStyle(
                                        color: AppColors.text,
                                        fontSize: 12))),
                          ],
                        ),
                      ),
                      Expanded(
                          flex: 2,
                          child: Text(
                              maxHr != null ? '$maxHr' : '–',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center)),
                      Expanded(
                          flex: 2,
                          child: Text(
                              avgHr != null ? '$avgHr' : '–',
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center)),
                      Expanded(
                          flex: 2,
                          child: Text(
                              trimp != null ? trimp.round().toString() : '–',
                              style: const TextStyle(
                                  color: AppColors.text,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700),
                              textAlign: TextAlign.center)),
                    ],
                  ),
                );
              }),
            ],
          ),
        ),

        const SizedBox(height: 32),
      ],
    );
  }

  LineChartData _buildChartData(List<Review> withChart) {
    double globalMin = double.infinity;
    double globalMax = double.negativeInfinity;

    // Prepare normalized data for each review
    final allLines = <_LineData>[];
    for (final r in withChart) {
      final pts = (_tsCache[r.id] ?? [])
          .where((p) => p.value != null && p.value! > 0)
          .toList()
        ..sort((a, b) => a.sort.compareTo(b.sort));

      if (pts.length < 2) continue;

      for (final p in pts) {
        if (p.value! < globalMin) globalMin = p.value!;
        if (p.value! > globalMax) globalMax = p.value!;
      }
      allLines.add(_LineData(reviewId: r.id, points: pts));
    }

    // Client's HR zone lines
    final clientMaxHr = widget.client.maxHeartRate?.toDouble();
    final clientMinHr = widget.client.minHeartRate?.toDouble();

    return LineChartData(
      minX: 0,
      maxX: 100,
      minY: (globalMin - 5).clamp(40, 300),
      maxY: globalMax + 5,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        getDrawingHorizontalLine: (_) =>
            const FlLine(color: AppColors.border, strokeWidth: 1, dashArray: [4, 4]),
      ),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 36,
          getTitlesWidget: (v, _) => Text('${v.toInt()}',
              style: const TextStyle(color: AppColors.muted, fontSize: 10)),
        )),
        bottomTitles: AxisTitles(
            sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 24,
          getTitlesWidget: (v, _) {
            if (v == 0 || v == 50 || v == 100) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${v.toInt()}%',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 9)),
              );
            }
            return const SizedBox.shrink();
          },
        )),
        topTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      ),
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          if (clientMaxHr != null)
            HorizontalLine(
              y: clientMaxHr,
              color: const Color(0xFFC2234D),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                style:
                    const TextStyle(color: Color(0xFFC2234D), fontSize: 10),
                labelResolver: (_) => 'Max',
              ),
            ),
          if (clientMinHr != null)
            HorizontalLine(
              y: clientMinHr,
              color: const Color(0xFF03A4B6),
              strokeWidth: 1,
              dashArray: [4, 4],
              label: HorizontalLineLabel(
                show: true,
                alignment: Alignment.topLeft,
                style:
                    const TextStyle(color: Color(0xFF03A4B6), fontSize: 10),
                labelResolver: (_) => 'Min',
              ),
            ),
        ],
      ),
      lineBarsData: allLines.asMap().entries.map((e) {
        final color = _lineColors[e.key % _lineColors.length];
        final pts = e.value.points;
        final n = pts.length;
        return LineChartBarData(
          spots: pts
              .asMap()
              .entries
              .map((p) => FlSpot(p.key / (n - 1) * 100, p.value.value!))
              .toList(),
          isCurved: true,
          curveSmoothness: 0.2,
          color: color,
          barWidth: 2,
          isStrokeCapRound: true,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        );
      }).toList(),
    );
  }
}

class _LineData {
  final int reviewId;
  final List<HeartRatePoint> points;
  const _LineData({required this.reviewId, required this.points});
}
