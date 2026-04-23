import 'package:intl/intl.dart';

// ── date helpers ─────────────────────────────────────────────────────────────
DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  final s = raw.toString().trim();
  if (s.isEmpty) return null;
  // ISO: 2012-11-01
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  // PHP d.m.Y H:i:s → 01.11.2012 14:30:00
  try { return DateFormat('dd.MM.yyyy HH:mm:ss').parse(s); } catch (_) {}
  // PHP d.m.Y → 01.11.2012
  try { return DateFormat('dd.MM.yyyy').parse(s); } catch (_) {}
  return null;
}

double? _d(dynamic v) => v == null ? null : double.tryParse(v.toString());
int?    _i(dynamic v) => v == null ? null : int.tryParse(v.toString());

// ── Performance (Leistungstest) ───────────────────────────────────────────────
class Performance {
  final int?    id;
  final int?    clientId;
  final DateTime? recordedAt;

  // Stabilitätsmessungen
  final double? points;
  final double? hamstrings;
  final double? calfs;
  final double? adductors;

  // Kraftmessungen
  final double? pullups;
  final double? pushups;
  final double? trunkBending;
  final double? forearmSupport;
  final double? sideSupport;
  final double? squatOnWall;

  // Motorik / Koordination
  final double? sensomotoric;
  final double? symmetry;
  final double? reaction;
  final double? counterMovementJump;
  final double? tapping;

  // Sprint
  final double? sprint10;
  final double? sprint20;
  final double? sprint30;

  const Performance({
    this.id, this.clientId, this.recordedAt,
    this.points, this.hamstrings, this.calfs, this.adductors,
    this.pullups, this.pushups, this.trunkBending,
    this.forearmSupport, this.sideSupport, this.squatOnWall,
    this.sensomotoric, this.symmetry, this.reaction,
    this.counterMovementJump, this.tapping,
    this.sprint10, this.sprint20, this.sprint30,
  });

  factory Performance.fromJson(Map<String, dynamic> j) => Performance(
    id:               _i(j['id']),
    clientId:         _i(j['client_id']),
    recordedAt:       _parseDate(j['date']),
    points:           _d(j['points']),
    hamstrings:       _d(j['hamstrings']),
    calfs:            _d(j['calfs']),
    adductors:        _d(j['adductors']),
    pullups:          _d(j['pullups']),
    pushups:          _d(j['pushups']),
    trunkBending:     _d(j['trunk_bending']),
    forearmSupport:   _d(j['forearm_support']),
    sideSupport:      _d(j['side_support']),
    squatOnWall:      _d(j['squat_on_wall']),
    sensomotoric:     _d(j['sensomotoric']),
    symmetry:         _d(j['symmetry']),
    reaction:         _d(j['reaction']),
    counterMovementJump: _d(j['counter_movement_jump']),
    tapping:          _d(j['tapping']),
    sprint10:         _d(j['sprint_10']),
    sprint20:         _d(j['sprint_20']),
    sprint30:         _d(j['sprint_30']),
  );

  String get displayDate =>
      recordedAt != null ? DateFormat('dd.MM.yyyy').format(recordedAt!) : '–';

  // Zusammenfassung für die Kartenliste
  String get displaySummary {
    final parts = <String>[];
    if (pushups != null)  parts.add('${pushups!.toStringAsFixed(0)} Liegestütze');
    if (pullups != null)  parts.add('${pullups!.toStringAsFixed(0)} Klimmzüge');
    if (sprint10 != null) parts.add('10m: ${sprint10!.toStringAsFixed(2)}s');
    return parts.isEmpty ? 'Leistungstest' : parts.join(' · ');
  }

  // Alle Felder als Liste für die Detail-Ansicht
  List<_TestEntry> get allEntries => [
    if (points != null)              _TestEntry('Stabilität',        points!),
    if (hamstrings != null)          _TestEntry('Nackenmuskulatur',  hamstrings!),
    if (calfs != null)               _TestEntry('Wadenmuskulatur',   calfs!),
    if (adductors != null)           _TestEntry('Rückenstrecker',    adductors!),
    if (pullups != null)             _TestEntry('Klimmzug',          pullups!),
    if (trunkBending != null)        _TestEntry('Rumpfbeugen',       trunkBending!),
    if (pushups != null)             _TestEntry('Liegestütze',       pushups!),
    if (forearmSupport != null)      _TestEntry('Unterarmstützen',   forearmSupport!),
    if (sideSupport != null)         _TestEntry('Seitestützen',      sideSupport!),
    if (squatOnWall != null)         _TestEntry('Hocke an Wand',     squatOnWall!),
    if (sensomotoric != null)        _TestEntry('Sensomotorik',      sensomotoric!),
    if (symmetry != null)            _TestEntry('Symmetrie',         symmetry!),
    if (reaction != null)            _TestEntry('Reaktion',          reaction!),
    if (counterMovementJump != null) _TestEntry('CMJ',               counterMovementJump!),
    if (tapping != null)             _TestEntry('Tapping',           tapping!),
    if (sprint10 != null)            _TestEntry('10m Sprint',        sprint10!, unit: 's'),
    if (sprint20 != null)            _TestEntry('20m Sprint',        sprint20!, unit: 's'),
    if (sprint30 != null)            _TestEntry('30m Sprint',        sprint30!, unit: 's'),
  ];
}

class _TestEntry {
  final String label;
  final double value;
  final String? unit;
  const _TestEntry(this.label, this.value, {this.unit});
  String get display {
    final v = value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(2);
    return unit != null ? '$v $unit' : v;
  }
}

// ── Metric (Körpermessungen) ──────────────────────────────────────────────────
class Metric {
  final int?    id;
  final int?    clientId;
  final DateTime? recordedAt;

  final double? weight;       // Gewicht kg
  final double? sys;          // Blutdruck systolisch
  final double? dia;          // Blutdruck diastolisch
  final double? calmPulse;    // Ruhepuls
  final double? bodyFatKg;    // Körperfett kg
  final double? bodyFatPerc;  // Körperfett %
  final double? waistCircumference; // Taillenumfang cm
  final double? bcm;          // Body Cell Mass kg

  const Metric({
    this.id, this.clientId, this.recordedAt,
    this.weight, this.sys, this.dia, this.calmPulse,
    this.bodyFatKg, this.bodyFatPerc, this.waistCircumference, this.bcm,
  });

  factory Metric.fromJson(Map<String, dynamic> j) => Metric(
    id:                 _i(j['id']),
    clientId:           _i(j['client_id']),
    recordedAt:         _parseDate(j['date']),
    weight:             _d(j['weight']),
    sys:                _d(j['sys']),
    dia:                _d(j['dia']),
    calmPulse:          _d(j['calm_pulse']),
    bodyFatKg:          _d(j['body_fat_kg']),
    bodyFatPerc:        _d(j['body_fat_perc']),
    waistCircumference: _d(j['waist_circumference']),
    bcm:                _d(j['bcm']),
  );

  String get displayDate =>
      recordedAt != null ? DateFormat('dd.MM.yyyy').format(recordedAt!) : '–';

  String get displayWeight =>
      weight != null ? '${weight!.toStringAsFixed(1)} kg' : '–';

  String get displayBloodPressure =>
      (sys != null && dia != null) ? '${sys!.toStringAsFixed(0)}/${dia!.toStringAsFixed(0)}' : '–';

  String get displayBodyFat =>
      bodyFatPerc != null ? '${bodyFatPerc!.toStringAsFixed(1)} %' : '–';

  // Detail-Felder
  List<_MetricEntry> get allEntries => [
    if (weight != null)             _MetricEntry('Gewicht',           weight!, 'kg'),
    if (bodyFatPerc != null)        _MetricEntry('Körperfett',        bodyFatPerc!, '%'),
    if (bodyFatKg != null)          _MetricEntry('Körperfett',        bodyFatKg!, 'kg'),
    if (bcm != null)                _MetricEntry('Body Cell Mass',    bcm!, 'kg'),
    if (waistCircumference != null) _MetricEntry('Taillenumfang',     waistCircumference!, 'cm'),
    if (sys != null && dia != null) _MetricEntry('Blutdruck', sys!, 'mmHg', secondary: '${sys!.toStringAsFixed(0)}/${dia!.toStringAsFixed(0)} mmHg'),
    if (calmPulse != null)          _MetricEntry('Ruhepuls',          calmPulse!, 'bpm'),
  ];
}

class _MetricEntry {
  final String label;
  final double value;
  final String unit;
  final String? secondary;
  const _MetricEntry(this.label, this.value, this.unit, {this.secondary});
  String get display =>
      secondary ?? '${value % 1 == 0 ? value.toInt().toString() : value.toStringAsFixed(1)} $unit';
}
