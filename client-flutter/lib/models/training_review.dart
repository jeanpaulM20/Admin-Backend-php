import 'package:flutter/material.dart';

class HrPoint {
  final String? time;
  final double value;
  const HrPoint({this.time, required this.value});
}

class TrainingReview {
  final String id;
  final DateTime date;
  final String trainingType;
  final String? duration;
  final int? hrMax;
  final int? hrAvg;
  final int? hrr;
  final double? hrv;
  final List<HrPoint> chart;

  const TrainingReview({
    required this.id,
    required this.date,
    required this.trainingType,
    this.duration,
    this.hrMax,
    this.hrAvg,
    this.hrr,
    this.hrv,
    this.chart = const [],
  });

  factory TrainingReview.fromJson(Map<String, dynamic> json) {
    final rawChart = json['chart'];
    final chart = <HrPoint>[];
    if (rawChart is List) {
      for (final p in rawChart) {
        if (p is Map<String, dynamic>) {
          final v = double.tryParse(p['v']?.toString() ?? '');
          if (v != null) chart.add(HrPoint(time: p['t']?.toString(), value: v));
        }
      }
    }
    return TrainingReview(
      id: json['id']?.toString() ?? '',
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      trainingType: json['trainingType']?.toString() ?? '',
      duration: json['duration']?.toString(),
      hrMax: json['hrMax'] != null ? int.tryParse(json['hrMax'].toString()) : null,
      hrAvg: json['hrAvg'] != null ? int.tryParse(json['hrAvg'].toString()) : null,
      hrr: json['hrr'] != null ? int.tryParse(json['hrr'].toString()) : null,
      hrv: json['hrv'] != null ? double.tryParse(json['hrv'].toString()) : null,
      chart: chart,
    );
  }

  /// Edwards' TRIMP — time-in-zone × zone factor.
  /// Uses chart data and hrMax; falls back to duration string for intervals.
  double? get edwardsTrimp {
    if (chart.isEmpty || hrMax == null || hrMax! <= 0) return null;

    final valid = chart.where((p) => p.value > 0).toList();
    if (valid.isEmpty) return null;

    // Determine interval per data point (in minutes)
    double intervalMin = 0;

    // Try timestamps first
    if (valid.length >= 2 &&
        valid.first.time != null &&
        valid.last.time != null) {
      try {
        final dt1 = DateTime.parse(valid.first.time!);
        final dt2 = DateTime.parse(valid.last.time!);
        final totalSec = dt2.difference(dt1).inSeconds;
        if (totalSec > 0) {
          intervalMin = (totalSec / (valid.length - 1)) / 60.0;
        }
      } catch (_) {}
    }

    // Fallback: use duration string or estimate from data point count
    if (intervalMin <= 0) {
      double totalMinutes = 0;
      if (duration != null && duration!.isNotEmpty) {
        final parts = duration!.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final s = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
          totalMinutes = h * 60.0 + m + s / 60.0;
        }
      }
      if (totalMinutes <= 0) {
        // Estimate: assume ~1 data point per second
        totalMinutes = valid.length / 60.0;
      }
      intervalMin = totalMinutes / valid.length;
    }

    if (intervalMin <= 0) return null;

    double trimp = 0;
    for (final p in valid) {
      final pct = p.value / hrMax!;
      int factor;
      if (pct >= 0.9) {
        factor = 5; // Zone 5: 90-100%
      } else if (pct >= 0.8) {
        factor = 4; // Zone 4: 80-90%
      } else if (pct >= 0.7) {
        factor = 3; // Zone 3: 70-80%
      } else if (pct >= 0.6) {
        factor = 2; // Zone 2: 60-70%
      } else if (pct >= 0.5) {
        factor = 1; // Zone 1: 50-60%
      } else {
        factor = 0; // Below Zone 1
      }
      trimp += intervalMin * factor;
    }
    return trimp > 0 ? trimp : null;
  }

  /// Training Load rating text based on Edwards TRIMP value.
  static String trimpRating(double trimp) {
    if (trimp < 50) return 'Leicht';
    if (trimp < 100) return 'Moderat';
    if (trimp < 150) return 'Mittel';
    if (trimp < 200) return 'Hart';
    if (trimp < 300) return 'Sehr Hart';
    return 'Extrem';
  }

  /// Color for TRIMP rating.
  static Color trimpColor(double trimp) {
    if (trimp < 50) return const Color(0xFF4CAF50);   // green
    if (trimp < 100) return const Color(0xFF8BC34A);  // light green
    if (trimp < 150) return const Color(0xFFFFC107);  // amber
    if (trimp < 200) return const Color(0xFFFF9800);  // orange
    if (trimp < 300) return const Color(0xFFFF5722);  // deep orange
    return const Color(0xFFF44336);                    // red
  }
}
