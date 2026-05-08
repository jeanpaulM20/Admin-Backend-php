import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/client.dart';
import '../models/review.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';
import 'training_compare_screen.dart';

/// Training recordings (Trainingsaufzeichnungen) with heart-rate chart.
/// Shows all reviews for a given client, each expandable with HR timeseries.
class TrainingRecordingScreen extends StatefulWidget {
  final Client client;

  const TrainingRecordingScreen({super.key, required this.client});

  @override
  State<TrainingRecordingScreen> createState() =>
      _TrainingRecordingScreenState();
}

class _TrainingRecordingScreenState extends State<TrainingRecordingScreen> {
  final ApiService _api = ApiService();
  List<Review> _reviews = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.get(
        ApiConfig.review,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      if (data is List) {
        setState(() {
          _reviews = data
              .map((e) => Review.fromJson(e as Map<String, dynamic>))
              .toList();
          _loading = false;
        });
      } else {
        setState(() {
          _reviews = [];
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Aufzeichnungen — ${widget.client.name}'),
        backgroundColor: AppColors.background,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadReviews,
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(
                  color: AppColors.primary, strokeWidth: 2))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline,
                            color: AppColors.red, size: 48),
                        const SizedBox(height: 12),
                        Text(_error!,
                            style: const TextStyle(color: AppColors.muted),
                            textAlign: TextAlign.center),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadReviews,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary),
                          child: const Text('Erneut versuchen'),
                        ),
                      ],
                    ),
                  ),
                )
              : _reviews.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadReviews,
                      color: AppColors.primary,
                      backgroundColor: AppColors.surface,
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          _buildSummaryRow(),
                          if (_reviews.length >= 2) ...[
                            const SizedBox(height: 12),
                            _buildCompareButton(),
                          ],
                          const SizedBox(height: 16),
                          ..._reviews
                              .map((r) => _ReviewCard(
                                    review: r,
                                    client: widget.client,
                                  ))
                              ,
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
    );
  }

  Widget _buildCompareButton() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: InkWell(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => TrainingCompareScreen(
              reviews: _reviews,
              client: widget.client,
            ),
          ),
        ),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.compare_arrows_rounded,
                  size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text('Trainings vergleichen',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  )),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.monitor_heart_outlined,
              color: AppColors.muted.withAlpha(120), size: 64),
          const SizedBox(height: 16),
          const Text(
            'Keine Aufzeichnungen',
            style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Für diesen Kunden sind noch keine\nTrainingsaufzeichnungen vorhanden.',
            style: TextStyle(color: AppColors.muted, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow() {
    final total = _reviews.length;
    final avgHr = _reviews
        .where((r) => r.heartRate != null && r.heartRate! > 0)
        .toList();
    final avgHeartRate = avgHr.isNotEmpty
        ? (avgHr.fold<double>(0, (s, r) => s + r.heartRate!) / avgHr.length)
            .round()
        : 0;
    return Row(
      children: [
        Expanded(
          child: _MiniStat(
            icon: Icons.fitness_center,
            label: 'Aufzeichnungen',
            value: total.toString(),
            color: AppColors.primary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            icon: Icons.favorite,
            label: 'Ø Herzfrequenz',
            value: avgHeartRate > 0 ? '$avgHeartRate bpm' : '–',
            color: AppColors.red,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MiniStat(
            icon: Icons.trending_up,
            label: 'Training Load',
            value: '–',
            color: const Color(0xFFFFA726),
          ),
        ),
      ],
    );
  }
}

// ─── Mini stat card ─────────────────────────────────────────────────
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border, width: 0.5),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ─── Single review card (expandable with HR chart) ──────────────────
class _ReviewCard extends StatefulWidget {
  final Review review;
  final Client client;

  const _ReviewCard({required this.review, required this.client});

  @override
  State<_ReviewCard> createState() => _ReviewCardState();
}

class _ReviewCardState extends State<_ReviewCard> {
  final ApiService _api = ApiService();
  bool _expanded = false;
  List<HeartRatePoint>? _timeseries;
  bool _loadingTs = false;

  String _formatDate() {
    final d = widget.review.trainingDate;
    final t = widget.review.trainingStarttime;
    if (d == null) return '–';
    try {
      final date = DateTime.parse(d);
      final dateStr = DateFormat('dd.MM.yyyy').format(date);
      if (t != null) {
        return '$dateStr  $t';
      }
      return dateStr;
    } catch (_) {
      return d;
    }
  }

  Future<void> _loadTimeseries() async {
    if (_timeseries != null) return; // already loaded
    setState(() => _loadingTs = true);
    try {
      final data =
          await _api.get('${ApiConfig.review}/${widget.review.id}/timeseries');
      if (data is List) {
        setState(() {
          _timeseries = data
              .map((e) => HeartRatePoint.fromJson(e as Map<String, dynamic>))
              .toList();
        });
      }
    } catch (_) {
      // Silently fail — timeseries may not exist
      setState(() => _timeseries = []);
    } finally {
      setState(() => _loadingTs = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.review;

    return GestureDetector(
      onTap: () {
        setState(() => _expanded = !_expanded);
        if (_expanded) _loadTimeseries();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _expanded
                ? AppColors.primary.withAlpha(100)
                : AppColors.border,
            width: _expanded ? 1 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _typeColor(r.trainingType).withAlpha(30),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: Text(
                      _typeAbbrev(r.trainingType),
                      style: TextStyle(
                        color: _typeColor(r.trainingType),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.trainingTypeLabel,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatDate(),
                        style: const TextStyle(
                            color: AppColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (r.heartRate != null && r.heartRate! > 0) ...[
                  const Icon(Icons.favorite, color: AppColors.red, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    '${r.heartRate!.round()} bpm',
                    style: const TextStyle(color: AppColors.red, fontSize: 13),
                  ),
                ],
                const SizedBox(width: 8),
                Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                  color: AppColors.muted,
                  size: 20,
                ),
              ],
            ),

            // Quick stats row
            const SizedBox(height: 12),
            Row(
              children: [
                _StatChip(
                    icon: Icons.timer_outlined,
                    text: r.durationLabel,
                    color: AppColors.blue),
                if (_timeseries != null && _timeseries!.isNotEmpty) ...[
                  Builder(builder: (_) {
                    final trimp = Review.edwardsTrimp(
                        _timeseries!, widget.client.maxHeartRate ?? 220);
                    if (trimp == null) return const SizedBox.shrink();
                    return Row(children: [
                      const SizedBox(width: 10),
                      _StatChip(
                          icon: Icons.fitness_center,
                          text: 'Load ${trimp.round()}',
                          color: const Color(0xFFFFA726)),
                    ]);
                  }),
                ] else if (r.kcal != null && r.kcal! > 0) ...[
                  const SizedBox(width: 10),
                  _StatChip(
                      icon: Icons.local_fire_department,
                      text: '${r.kcal} kcal',
                      color: const Color(0xFFFFA726)),
                ],
                if (r.distance != null && r.distance! > 0) ...[
                  const SizedBox(width: 10),
                  _StatChip(
                      icon: Icons.straighten,
                      text: '${r.distance!.toStringAsFixed(0)} m',
                      color: AppColors.green),
                ],
                if (r.speed != null && r.speed! > 0) ...[
                  const SizedBox(width: 10),
                  _StatChip(
                      icon: Icons.speed,
                      text: '${r.speed!.toStringAsFixed(1)} km/h',
                      color: AppColors.blue),
                ],
              ],
            ),

            // Expanded details
            if (_expanded) ...[
              const SizedBox(height: 16),
              const Divider(color: AppColors.border, height: 1),
              const SizedBox(height: 16),

              // Feedback section
              if (r.feedbackClient != null &&
                  r.feedbackClient!.isNotEmpty) ...[
                _DetailRow(label: 'Kunden-Feedback', value: r.feedbackClient!),
                const SizedBox(height: 8),
              ],
              if (r.feedbackTrainer != null &&
                  r.feedbackTrainer!.isNotEmpty) ...[
                _DetailRow(
                    label: 'Trainer-Feedback', value: r.feedbackTrainer!),
                const SizedBox(height: 8),
              ],
              if (r.feedbackEmoticon != null &&
                  r.feedbackEmoticon!.isNotEmpty) ...[
                _DetailRow(label: 'Emoticon', value: r.feedbackEmoticon!),
                const SizedBox(height: 8),
              ],
              if (r.type != null) ...[
                _DetailRow(label: 'Intensität', value: _intensityLabel(r.type!)),
                const SizedBox(height: 8),
              ],
              if (r.goal != null && r.goal! > 0) ...[
                _DetailRow(
                    label: 'Ziel',
                    value: '${r.goal} ${r.goalMetric ?? ''}'),
                const SizedBox(height: 8),
              ],
              if (r.result != null && r.result! > 0) ...[
                _DetailRow(label: 'Ergebnis', value: r.result.toString()),
                const SizedBox(height: 8),
              ],

              // Heart rate chart
              const SizedBox(height: 8),
              _buildHeartRateSection(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeartRateSection() {
    if (_loadingTs) {
      return const SizedBox(
        height: 180,
        child: Center(
          child: CircularProgressIndicator(
              color: AppColors.primary, strokeWidth: 2),
        ),
      );
    }

    final pts = _timeseries ?? widget.review.timeseries;
    if (pts.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: const Text(
          'Keine Herzfrequenz-Daten vorhanden',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }

    // Build chart data
    final validPts = pts.where((p) => p.value != null && p.value! > 0).toList();
    if (validPts.isEmpty) {
      return Container(
        height: 80,
        alignment: Alignment.center,
        child: const Text(
          'Keine gültigen Herzfrequenz-Werte',
          style: TextStyle(color: AppColors.muted, fontSize: 13),
        ),
      );
    }

    final spots = validPts
        .asMap()
        .entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value!))
        .toList();

    final minHr = validPts.map((p) => p.value!).reduce((a, b) => a < b ? a : b);
    final maxHr = validPts.map((p) => p.value!).reduce((a, b) => a > b ? a : b);

    // Heart rate zone lines from client
    final clientMaxHr = widget.client.maxHeartRate?.toDouble();
    final clientMinHr = widget.client.minHeartRate?.toDouble();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.monitor_heart, color: AppColors.red, size: 16),
            const SizedBox(width: 6),
            const Text(
              'Herzfrequenz',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600),
            ),
            const Spacer(),
            Text(
              'Min ${minHr.round()}  /  Max ${maxHr.round()} bpm',
              style: const TextStyle(color: AppColors.muted, fontSize: 11),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 200,
          child: LineChart(
            LineChartData(
              backgroundColor: Colors.transparent,
              minY: (minHr - 10).clamp(40, double.infinity),
              maxY: maxHr + 10,
              gridData: FlGridData(
                show: true,
                drawVerticalLine: false,
                getDrawingHorizontalLine: (_) => const FlLine(
                  color: AppColors.border,
                  strokeWidth: 0.5,
                ),
              ),
              titlesData: FlTitlesData(
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 36,
                    interval: 20,
                    getTitlesWidget: (value, _) => Text(
                      value.toInt().toString(),
                      style:
                          const TextStyle(color: AppColors.muted, fontSize: 10),
                    ),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 22,
                    interval: spots.length > 20
                        ? (spots.length / 6).ceilToDouble()
                        : null,
                    getTitlesWidget: (value, _) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= validPts.length) {
                        return const SizedBox.shrink();
                      }
                      final ts = validPts[idx].timestamp;
                      if (ts == null) return const SizedBox.shrink();
                      try {
                        final dt = DateTime.parse(ts);
                        return Text(
                          DateFormat('HH:mm').format(dt),
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 9),
                        );
                      } catch (_) {
                        return const SizedBox.shrink();
                      }
                    },
                  ),
                ),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              ),
              borderData: FlBorderData(show: false),
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
                        style: const TextStyle(
                            color: Color(0xFFC2234D), fontSize: 10),
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
                        style: const TextStyle(
                            color: Color(0xFF03A4B6), fontSize: 10),
                        labelResolver: (_) => 'Min',
                      ),
                    ),
                ],
              ),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) => AppColors.surface2,
                  getTooltipItems: (spots) {
                    return spots.map((s) {
                      return LineTooltipItem(
                        '${s.y.round()} bpm',
                        const TextStyle(color: Colors.white, fontSize: 12),
                      );
                    }).toList();
                  },
                ),
              ),
              lineBarsData: [
                LineChartBarData(
                  spots: spots,
                  isCurved: true,
                  curveSmoothness: 0.2,
                  preventCurveOverShooting: true,
                  color: AppColors.red,
                  barWidth: 2,
                  isStrokeCapRound: true,
                  dotData: const FlDotData(show: false),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.red.withAlpha(60),
                        AppColors.red.withAlpha(0),
                      ],
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        // Heart rate zone legend
        if (clientMaxHr != null && clientMinHr != null) ...[
          const SizedBox(height: 12),
          _buildZoneLegend(clientMinHr, clientMaxHr),
        ],
      ],
    );
  }

  Widget _buildZoneLegend(double minHr, double maxHr) {
    final step = ((maxHr - minHr) * 0.25).toInt();
    final zones = [
      _ZoneInfo('Maximal', Color(0xFFC2234D), maxHr.round()),
      _ZoneInfo('Intensiv', Color(0xFFD18B37), (maxHr - step).round()),
      _ZoneInfo('Moderat', Color(0xFF839C4D), (maxHr - step * 2).round()),
      _ZoneInfo('Leicht', Color(0xFF03A4B6), (maxHr - step * 3).round()),
      _ZoneInfo('Sehr Leicht', Color(0xFF9E9E9E), (maxHr - step * 4).round()),
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 4,
      children: zones
          .map((z) => Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: z.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${z.label} (${z.bpm}+)',
                    style:
                        const TextStyle(color: AppColors.muted, fontSize: 10),
                  ),
                ],
              ))
          .toList(),
    );
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'running':
        return AppColors.green;
      case 'fitness':
        return AppColors.blue;
      case 'interval':
        return const Color(0xFFFFA726);
      case 'cardio':
        return AppColors.red;
      case 'endurance':
        return const Color(0xFF26A69A);
      case 'strenght':
        return const Color(0xFF9C27B0);
      default:
        return AppColors.primary;
    }
  }

  String _typeAbbrev(String? type) {
    switch (type) {
      case 'running':
        return 'R';
      case 'fitness':
        return 'FL';
      case 'interval':
        return 'IT';
      case 'cardio':
        return 'C';
      case 'endurance':
        return 'A';
      case 'strenght':
        return 'K';
      case 'speed':
        return 'S';
      case 'coordination':
        return 'KO';
      case 'free':
        return 'F';
      default:
        return 'PT';
    }
  }

  String _intensityLabel(String type) {
    const labels = {
      'maximum': 'Maximal',
      'hard': 'Intensiv',
      'moderate': 'Moderat',
      'light': 'Leicht',
      'very_light': 'Sehr Leicht',
    };
    return labels[type] ?? type;
  }
}

class _ZoneInfo {
  final String label;
  final Color color;
  final int bpm;
  const _ZoneInfo(this.label, this.color, this.bpm);
}

// ─── Small stat chip ────────────────────────────────────────────────
class _StatChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _StatChip({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(color: color, fontSize: 12),
        ),
      ],
    );
  }
}

// ─── Detail row (label: value) ──────────────────────────────────────
class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Text(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 13),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.text, fontSize: 13),
          ),
        ),
      ],
    );
  }
}
