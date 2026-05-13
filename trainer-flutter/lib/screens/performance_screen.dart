import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/client.dart';
import '../models/performance.dart';
import '../services/api_service.dart';
import '../config/api_config.dart';
import '../config/app_colors.dart';

class PerformanceScreen extends StatefulWidget {
  final Client client;
  const PerformanceScreen({super.key, required this.client});

  @override
  State<PerformanceScreen> createState() => _PerformanceScreenState();
}

class _PerformanceScreenState extends State<PerformanceScreen>
    with SingleTickerProviderStateMixin {
  final _apiService = ApiService();
  late TabController _tabCtrl;

  bool _perfLoading = true;
  bool _metricLoading = true;
  String? _perfError;
  String? _metricError;
  List<Performance> _performances = [];
  List<Metric> _metrics = [];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _loadPerformances();
    _loadMetrics();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadPerformances() async {
    setState(() { _perfLoading = true; _perfError = null; });
    try {
      final resp = await _apiService.get(
        ApiConfig.performance,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      List<dynamic> list = resp is List
          ? resp
          : (resp is Map && resp['data'] is List ? resp['data'] as List : []);
      _performances = list
          .map((e) => Performance.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          if (a.recordedAt == null) return 1;
          if (b.recordedAt == null) return -1;
          return b.recordedAt!.compareTo(a.recordedAt!);
        });
    } on ApiException catch (e) {
      _perfError = e.message;
    } catch (_) {
      _perfError = 'Fehler beim Laden';
    } finally {
      if (mounted) setState(() => _perfLoading = false);
    }
  }

  Future<void> _loadMetrics() async {
    setState(() { _metricLoading = true; _metricError = null; });
    try {
      final resp = await _apiService.get(
        ApiConfig.metric,
        queryParams: {'client_id': widget.client.id.toString()},
      );
      List<dynamic> list = resp is List
          ? resp
          : (resp is Map && resp['data'] is List ? resp['data'] as List : []);
      _metrics = list
          .map((e) => Metric.fromJson(e as Map<String, dynamic>))
          .toList()
        ..sort((a, b) {
          if (a.recordedAt == null) return 1;
          if (b.recordedAt == null) return -1;
          return b.recordedAt!.compareTo(a.recordedAt!);
        });
    } on ApiException catch (e) {
      _metricError = e.message;
    } catch (_) {
      _metricError = 'Fehler beim Laden';
    } finally {
      if (mounted) setState(() => _metricLoading = false);
    }
  }

  Future<void> _addMetric() async {
    final result = await showDialog<Map<String, String>>(
      context: context, builder: (_) => _AddMetricDialog(),
    );
    if (result == null) return;
    try {
      await _apiService.post(ApiConfig.metric, body: {'client_id': widget.client.id, ...result});
      _loadMetrics();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
      );
    }
  }

  Future<void> _addPerformance() async {
    final result = await showDialog<Map<String, String>>(
      context: context, builder: (_) => _AddPerformanceDialog(),
    );
    if (result == null) return;
    try {
      await _apiService.post(ApiConfig.performance, body: {'client_id': widget.client.id, ...result});
      _loadPerformances();
    } on ApiException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message), backgroundColor: AppColors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Leistung & Messwerte'),
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(icon: Icon(Icons.fitness_center, size: 18), text: 'Leistungstest'),
            Tab(icon: Icon(Icons.monitor_weight_outlined, size: 18), text: 'Körperwerte'),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _tabCtrl.index == 0 ? _addPerformance() : _addMetric(),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: TabBarView(
            controller: _tabCtrl,
            children: [_buildPerformanceTab(), _buildMetricsTab()],
          ),
        ),
      ),
    );
  }

  // ── Performance Tab ────────────────────────────────────────────────────────
  Widget _buildPerformanceTab() {
    if (_perfLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_perfError != null) return _buildError(_perfError!, _loadPerformances);
    if (_performances.isEmpty) return _buildEmpty('Noch keine Leistungstests', Icons.fitness_center);

    // Build per-field history for trend charts
    final fieldHistory = <String, List<_FieldPoint>>{};
    for (int i = _performances.length - 1; i >= 0; i--) {
      final p = _performances[i];
      void add(String k, double? v) {
        if (v != null) {
          fieldHistory.putIfAbsent(k, () => []);
          fieldHistory[k]!.add(_FieldPoint(p.recordedAt, v));
        }
      }
      add('points', p.points); add('hamstrings', p.hamstrings); add('calfs', p.calfs);
      add('adductors', p.adductors); add('pullups', p.pullups); add('pushups', p.pushups);
      add('trunkBending', p.trunkBending); add('forearmSupport', p.forearmSupport);
      add('sideSupport', p.sideSupport); add('squatOnWall', p.squatOnWall);
      add('sensomotoric', p.sensomotoric); add('symmetry', p.symmetry);
      add('reaction', p.reaction); add('counterMovementJump', p.counterMovementJump);
      add('tapping', p.tapping); add('sprint10', p.sprint10);
      add('sprint20', p.sprint20); add('sprint30', p.sprint30);
    }

    return RefreshIndicator(
      onRefresh: _loadPerformances,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _performances.length,
        itemBuilder: (_, i) {
          final perf = _performances[i];
          final prev = i + 1 < _performances.length ? _performances[i + 1] : null;
          return _PerformanceSectionTile(
            perf: perf,
            prev: prev,
            fieldHistory: fieldHistory,
          );
        },
      ),
    );
  }

  // ── Metrics Tab ────────────────────────────────────────────────────────────
  Widget _buildMetricsTab() {
    if (_metricLoading) return const Center(child: CircularProgressIndicator(color: AppColors.primary));
    if (_metricError != null) return _buildError(_metricError!, _loadMetrics);
    if (_metrics.isEmpty) return _buildEmpty('Noch keine Körperwerte', Icons.monitor_weight_outlined);

    final fieldHistory = <String, List<_FieldPoint>>{};
    for (int i = _metrics.length - 1; i >= 0; i--) {
      final m = _metrics[i];
      void add(String k, double? v) {
        if (v != null) { fieldHistory.putIfAbsent(k, () => []); fieldHistory[k]!.add(_FieldPoint(m.recordedAt, v)); }
      }
      add('weight', m.weight); add('sys', m.sys); add('dia', m.dia);
      add('calmPulse', m.calmPulse); add('bodyFatKg', m.bodyFatKg);
      add('bodyFatPerc', m.bodyFatPerc); add('waistCircumference', m.waistCircumference);
      add('bcm', m.bcm);
    }

    return RefreshIndicator(
      onRefresh: _loadMetrics,
      color: AppColors.primary,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
        itemCount: _metrics.length,
        itemBuilder: (_, i) {
          final metric = _metrics[i];
          final prev = i + 1 < _metrics.length ? _metrics[i + 1] : null;
          return _MetricSectionTile(metric: metric, prev: prev, fieldHistory: fieldHistory);
        },
      ),
    );
  }

  Widget _buildError(String msg, VoidCallback retry) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.error_outline, color: AppColors.red, size: 48),
      const SizedBox(height: 12),
      Text(msg, style: const TextStyle(color: AppColors.muted)),
      const SizedBox(height: 16),
      TextButton(onPressed: retry, child: const Text('Nochmal versuchen')),
    ]),
  );

  Widget _buildEmpty(String msg, IconData icon) => Center(
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Icon(icon, color: AppColors.muted, size: 56),
      const SizedBox(height: 16),
      Text(msg, style: const TextStyle(color: AppColors.muted, fontSize: 15)),
      const SizedBox(height: 8),
      const Text('Tippe + um einen Eintrag hinzuzufügen',
          style: TextStyle(color: AppColors.muted, fontSize: 13)),
    ]),
  );
}

// ── Data helpers ──────────────────────────────────────────────────────────────
class _FieldPoint {
  final DateTime? date;
  final double value;
  const _FieldPoint(this.date, this.value);
}

String _fmt(double? v, {String? unit}) {
  if (v == null || v == 0.0) return '–';
  final s = v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(2);
  return unit != null ? '$s $unit' : s;
}

// Returns null if value is 0 or null (not measured)
double? _nonZero(double? v) => (v == null || v == 0.0) ? null : v;

// ── Performance Section Tile ──────────────────────────────────────────────────
class _PerformanceSectionTile extends StatelessWidget {
  final Performance perf;
  final Performance? prev;
  final Map<String, List<_FieldPoint>> fieldHistory;

  const _PerformanceSectionTile({
    required this.perf,
    required this.prev,
    required this.fieldHistory,
  });

  List<_RowData> get _rows {
    final rows = <_RowData>[];
    void add(String label, String key, double? cur, double? pre, {String? unit}) {
      final c = _nonZero(cur);
      if (c != null) rows.add(_RowData(label: label, key: key,
          value: _fmt(c, unit: unit),
          prevValue: _fmt(_nonZero(pre), unit: unit),
          change: _change(c, _nonZero(pre))));
    }
    add('Stabilität',         'points',             perf.points,             prev?.points);
    add('Nackenmuskulatur',   'hamstrings',         perf.hamstrings,         prev?.hamstrings);
    add('Wadenmuskulatur',    'calfs',              perf.calfs,              prev?.calfs);
    add('Rückenstrecker',     'adductors',          perf.adductors,          prev?.adductors);
    add('Klimmzug',           'pullups',            perf.pullups,            prev?.pullups);
    add('Liegestütze',        'pushups',            perf.pushups,            prev?.pushups);
    add('Rumpfbeugen',        'trunkBending',       perf.trunkBending,       prev?.trunkBending);
    add('Unterarmstützen',    'forearmSupport',     perf.forearmSupport,     prev?.forearmSupport);
    add('Seitestützen',       'sideSupport',        perf.sideSupport,        prev?.sideSupport);
    add('Hocke an Wand',      'squatOnWall',        perf.squatOnWall,        prev?.squatOnWall);
    add('Sensomotorik',       'sensomotoric',       perf.sensomotoric,       prev?.sensomotoric);
    add('Symmetrie',          'symmetry',           perf.symmetry,           prev?.symmetry);
    add('Reaktion',           'reaction',           perf.reaction,           prev?.reaction);
    add('CMJ',                'counterMovementJump',perf.counterMovementJump,prev?.counterMovementJump);
    add('Tapping',            'tapping',            perf.tapping,            prev?.tapping);
    add('10m Sprint',         'sprint10',           perf.sprint10,           prev?.sprint10,  unit: 's');
    add('20m Sprint',         'sprint20',           perf.sprint20,           prev?.sprint20,  unit: 's');
    add('30m Sprint',         'sprint30',           perf.sprint30,           prev?.sprint30,  unit: 's');
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.fitness_center, color: AppColors.primary, size: 20),
          ),
          title: Text(perf.displayDate,
              style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
          subtitle: Text('${rows.length} Messwert${rows.length != 1 ? 'e' : ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          iconColor: AppColors.muted,
          collapsedIconColor: AppColors.muted,
          children: [
            const Divider(color: AppColors.border, height: 1),
            // Header row
            _headerRow(),
            ...rows.asMap().entries.map((e) => _ItemRow(
              data: e.value,
              isLast: e.key == rows.length - 1,
              isEven: e.key.isEven,
              onTap: () => _openChart(context, e.value),
            )),
          ],
        ),
      ),
    );
  }

  void _openChart(BuildContext context, _RowData row) {
    final history = fieldHistory[row.key] ?? [];
    if (history.isEmpty) return;
    final h = MediaQuery.of(context).size.height * 0.65;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(height: h, child: _ChartSheet(label: row.label, history: history)),
    );
  }

  Widget _headerRow() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.surface2.withOpacity(0.5),
    child: Row(children: const [
      Expanded(flex: 3, child: Text('Übung', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600))),
      Expanded(flex: 2, child: Text('Aktuell', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
      Expanded(flex: 2, child: Text('Vorher', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
      SizedBox(width: 40),
    ]),
  );
}

// ── Metric Section Tile ───────────────────────────────────────────────────────
class _MetricSectionTile extends StatelessWidget {
  final Metric metric;
  final Metric? prev;
  final Map<String, List<_FieldPoint>> fieldHistory;

  const _MetricSectionTile({required this.metric, required this.prev, required this.fieldHistory});

  List<_RowData> get _rows {
    final rows = <_RowData>[];
    void add(String label, String key, double? cur, double? pre, {String? unit}) {
      final c = _nonZero(cur);
      if (c != null) rows.add(_RowData(label: label, key: key,
          value: _fmt(c, unit: unit),
          prevValue: _fmt(_nonZero(pre), unit: unit),
          change: _change(c, _nonZero(pre))));
    }
    add('Gewicht',           'weight',             metric.weight,             prev?.weight,             unit: 'kg');
    add('Blutdruck sys',     'sys',                metric.sys,                prev?.sys,                unit: 'mmHg');
    add('Blutdruck dia',     'dia',                metric.dia,                prev?.dia,                unit: 'mmHg');
    add('Ruhepuls',          'calmPulse',          metric.calmPulse,          prev?.calmPulse,          unit: 'bpm');
    add('Körperfett (kg)',   'bodyFatKg',          metric.bodyFatKg,          prev?.bodyFatKg,          unit: 'kg');
    add('Körperfett (%)',    'bodyFatPerc',        metric.bodyFatPerc,        prev?.bodyFatPerc,        unit: '%');
    add('Taillenumfang',     'waistCircumference', metric.waistCircumference, prev?.waistCircumference, unit: 'cm');
    add('Body Cell Mass',    'bcm',                metric.bcm,                prev?.bcm,                unit: 'kg');
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          childrenPadding: EdgeInsets.zero,
          leading: Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              color: AppColors.blue.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.monitor_weight_outlined, color: AppColors.blue, size: 20),
          ),
          title: Text(metric.displayDate,
              style: const TextStyle(color: AppColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
          subtitle: Text('${rows.length} Messwert${rows.length != 1 ? 'e' : ''}',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          iconColor: AppColors.muted,
          collapsedIconColor: AppColors.muted,
          children: [
            const Divider(color: AppColors.border, height: 1),
            _headerRow(),
            ...rows.asMap().entries.map((e) => _ItemRow(
              data: e.value,
              isLast: e.key == rows.length - 1,
              isEven: e.key.isEven,
              onTap: () => _openChart(context, e.value),
            )),
          ],
        ),
      ),
    );
  }

  void _openChart(BuildContext context, _RowData row) {
    final history = fieldHistory[row.key] ?? [];
    if (history.isEmpty) return;
    final h = MediaQuery.of(context).size.height * 0.65;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => SizedBox(height: h, child: _ChartSheet(label: row.label, history: history)),
    );
  }

  Widget _headerRow() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    color: AppColors.surface2.withOpacity(0.5),
    child: Row(children: const [
      Expanded(flex: 3, child: Text('Messung', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600))),
      Expanded(flex: 2, child: Text('Aktuell', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
      Expanded(flex: 2, child: Text('Vorher', style: TextStyle(color: AppColors.muted, fontSize: 11, fontWeight: FontWeight.w600), textAlign: TextAlign.center)),
      SizedBox(width: 40),
    ]),
  );
}

// ── Shared Item Row ───────────────────────────────────────────────────────────
class _RowData {
  final String label;
  final String key;
  final String value;
  final String prevValue;
  final int change; // 1=up, -1=down, 0=same
  const _RowData({required this.label, required this.key, required this.value,
    required this.prevValue, required this.change});
}

int _change(double? cur, double? prev) {
  if (cur == null || prev == null) return 0;
  if (cur > prev) return 1;
  if (cur < prev) return -1;
  return 0;
}

class _ItemRow extends StatelessWidget {
  final _RowData data;
  final bool isLast;
  final bool isEven;
  final VoidCallback? onTap;

  const _ItemRow({required this.data, this.isLast = false, this.isEven = true, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: isLast
          ? const BorderRadius.vertical(bottom: Radius.circular(13))
          : BorderRadius.zero,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isEven ? Colors.transparent : AppColors.surface2.withOpacity(0.4),
          border: isLast ? null : const Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(flex: 3, child: Text(data.label,
              style: const TextStyle(color: AppColors.muted, fontSize: 13))),
          Expanded(flex: 2, child: Text(data.value,
              style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
              textAlign: TextAlign.center)),
          Expanded(flex: 2, child: Text(data.prevValue,
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
              textAlign: TextAlign.center)),
          SizedBox(width: 40, child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (data.change == 1)
                const Icon(Icons.arrow_upward_rounded, size: 14, color: AppColors.green)
              else if (data.change == -1)
                const Icon(Icons.arrow_downward_rounded, size: 14, color: AppColors.red),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.border),
            ],
          )),
        ]),
      ),
    );
  }
}

// ── Chart Bottom Sheet ────────────────────────────────────────────────────────
class _ChartSheet extends StatelessWidget {
  final String label;
  final List<_FieldPoint> history;

  const _ChartSheet({required this.label, required this.history});

  @override
  Widget build(BuildContext context) {
    final spots = history.asMap().entries
        .map((e) => FlSpot(e.key.toDouble(), e.value.value))
        .toList();

    final values = history.map((h) => h.value).toList();
    final minVal = values.reduce((a, b) => a < b ? a : b);
    final maxVal = values.reduce((a, b) => a > b ? a : b);
    final minY = minVal == maxVal ? minVal - 1 : minVal * 0.95;
    final maxY = minVal == maxVal ? maxVal + 1 : maxVal * 1.05;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Handle
        Center(child: Container(
          width: 40, height: 4,
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
        )),
        // Title
        Align(
          alignment: Alignment.centerLeft,
          child: Text(label,
              style: const TextStyle(color: AppColors.text, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 4),
        Align(
          alignment: Alignment.centerLeft,
          child: Text('${history.length} Einträge',
              style: const TextStyle(color: AppColors.muted, fontSize: 12)),
        ),
        const SizedBox(height: 20),
        // Chart
        SizedBox(
          height: 180,
          child: LineChart(LineChartData(
            backgroundColor: Colors.transparent,
            minY: minY,
            maxY: maxY,
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 0.5),
            ),
            titlesData: FlTitlesData(
              leftTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                getTitlesWidget: (v, _) => Text(
                  v % 1 == 0 ? v.toInt().toString() : v.toStringAsFixed(1),
                  style: const TextStyle(color: AppColors.muted, fontSize: 10),
                ),
              )),
              bottomTitles: AxisTitles(sideTitles: SideTitles(
                showTitles: true,
                interval: history.length > 6 ? (history.length / 5).ceilToDouble() : 1,
                getTitlesWidget: (v, _) {
                  final i = v.toInt();
                  if (i < 0 || i >= history.length) return const SizedBox();
                  final d = history[i].date;
                  if (d == null) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text('${d.month}/${d.year.toString().substring(2)}',
                        style: const TextStyle(color: AppColors.muted, fontSize: 9)),
                  );
                },
              )),
              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
              topTitles:   const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            ),
            borderData: FlBorderData(show: false),
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                color: AppColors.primary,
                barWidth: 2.5,
                isStrokeCapRound: true,
                dotData: FlDotData(
                  show: spots.length <= 14,
                  getDotPainter: (_, __, ___, ____) => FlDotCirclePainter(
                    radius: 3,
                    color: AppColors.primary,
                    strokeWidth: 0,
                  ),
                ),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: [AppColors.primary.withAlpha(60), AppColors.primary.withAlpha(0)],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ],
          )),
        ),
        const SizedBox(height: 20),
        const Divider(color: AppColors.border),
        const SizedBox(height: 8),
        // Latest values list
        ...history.reversed.take(8).map((h) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 7),
          child: Row(children: [
            Expanded(child: Text(
              h.date != null
                  ? '${h.date!.day.toString().padLeft(2,'0')}.${h.date!.month.toString().padLeft(2,'0')}.${h.date!.year}'
                  : '–',
              style: const TextStyle(color: AppColors.muted, fontSize: 13),
            )),
            Text(
              h.value % 1 == 0 ? h.value.toInt().toString() : h.value.toStringAsFixed(2),
              style: const TextStyle(color: AppColors.text, fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ]),
        )),
      ]),
    );
  }
}

// ── Add Dialogs ───────────────────────────────────────────────────────────────
class _AddMetricDialog extends StatefulWidget {
  @override
  State<_AddMetricDialog> createState() => _AddMetricDialogState();
}

class _AddMetricDialogState extends State<_AddMetricDialog> {
  final _fields = <String, TextEditingController>{
    'weight':              TextEditingController(),
    'sys':                 TextEditingController(),
    'dia':                 TextEditingController(),
    'calm_pulse':          TextEditingController(),
    'body_fat_kg':         TextEditingController(),
    'body_fat_perc':       TextEditingController(),
    'waist_circumference': TextEditingController(),
    'bcm':                 TextEditingController(),
  };
  final _labels = <String, String>{
    'weight':              'Gewicht (kg)',
    'sys':                 'Blutdruck sys (mmHg)',
    'dia':                 'Blutdruck dia (mmHg)',
    'calm_pulse':          'Ruhepuls (bpm)',
    'body_fat_kg':         'Körperfett (kg)',
    'body_fat_perc':       'Körperfett (%)',
    'waist_circumference': 'Taillenumfang (cm)',
    'bcm':                 'Body Cell Mass (kg)',
  };

  @override
  void dispose() { _fields.values.forEach((c) => c.dispose()); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    title: const Text('Körperwerte erfassen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
      children: _labels.entries.map((e) => _field(_fields[e.key]!, e.value)).toList())),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen', style: TextStyle(color: AppColors.muted))),
      TextButton(onPressed: () {
        final r = <String, String>{};
        _fields.forEach((k, c) { if (c.text.trim().isNotEmpty) r[k] = c.text.trim(); });
        Navigator.pop(context, r);
      }, child: const Text('Speichern', style: TextStyle(color: AppColors.primary))),
    ],
  );

  Widget _field(TextEditingController ctrl, String label) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: const TextStyle(color: Colors.white, fontSize: 14),
      decoration: InputDecoration(
        labelText: label, labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        filled: true, fillColor: AppColors.surface2, isDense: true,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
      ),
    ),
  );
}

class _AddPerformanceDialog extends StatefulWidget {
  @override
  State<_AddPerformanceDialog> createState() => _AddPerformanceDialogState();
}

class _AddPerformanceDialogState extends State<_AddPerformanceDialog> {
  final _fields = <String, TextEditingController>{
    'points': TextEditingController(), 'pushups': TextEditingController(),
    'pullups': TextEditingController(), 'forearm_support': TextEditingController(),
    'side_support': TextEditingController(), 'squat_on_wall': TextEditingController(),
    'trunk_bending': TextEditingController(), 'sprint_10': TextEditingController(),
    'sprint_20': TextEditingController(), 'sprint_30': TextEditingController(),
    'sensomotoric': TextEditingController(), 'symmetry': TextEditingController(),
    'reaction': TextEditingController(), 'counter_movement_jump': TextEditingController(),
    'tapping': TextEditingController(),
  };
  final _labels = <String, String>{
    'points': 'Stabilität', 'pushups': 'Liegestütze', 'pullups': 'Klimmzug',
    'forearm_support': 'Unterarmstützen', 'side_support': 'Seitestützen',
    'squat_on_wall': 'Hocke an Wand', 'trunk_bending': 'Rumpfbeugen',
    'sprint_10': '10m Sprint (s)', 'sprint_20': '20m Sprint (s)', 'sprint_30': '30m Sprint (s)',
    'sensomotoric': 'Sensomotorik', 'symmetry': 'Symmetrie', 'reaction': 'Reaktion',
    'counter_movement_jump': 'Counter Movement Jump', 'tapping': 'Tapping',
  };

  @override
  void dispose() { _fields.values.forEach((c) => c.dispose()); super.dispose(); }

  @override
  Widget build(BuildContext context) => AlertDialog(
    backgroundColor: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    title: const Text('Leistungstest erfassen', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min,
      children: _labels.entries.map((e) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: TextField(
          controller: _fields[e.key]!,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            labelText: e.value, labelStyle: const TextStyle(color: AppColors.muted, fontSize: 13),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            filled: true, fillColor: AppColors.surface2, isDense: true,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.border)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
          ),
        ),
      )).toList(),
    )),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen', style: TextStyle(color: AppColors.muted))),
      TextButton(onPressed: () {
        final r = <String, String>{};
        _fields.forEach((k, c) { if (c.text.trim().isNotEmpty) r[k] = c.text.trim(); });
        Navigator.pop(context, r);
      }, child: const Text('Speichern', style: TextStyle(color: AppColors.primary))),
    ],
  );
}
