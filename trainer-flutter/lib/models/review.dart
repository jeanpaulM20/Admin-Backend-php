import 'dart:math' show exp;

/// A single training recording (workout result) with heart rate data.
class Review {
  final int id;
  final String? file;
  final String? duration;
  final int? kcal;
  final double? heartRate;
  final String? heartRateTimeseries;
  final int? exercisesetId;
  final int? trainingId;
  final String? trainingType;
  final String? type;
  final int? goal;
  final String? goalMetric;
  final int? bonusGoal;
  final String? bonusGoalMetric;
  final int? trainingplanId;
  final int? result;
  final String? feedbackEmoticon;
  final String? feedbackClient;
  final String? feedbackTrainer;
  final double? speed;
  final double? distance;

  // Joined from training relation
  final String? trainingDate;
  final String? trainingStarttime;

  // Heart rate timeseries data points (loaded separately or via relation)
  final List<HeartRatePoint> timeseries;

  Review({
    required this.id,
    this.file,
    this.duration,
    this.kcal,
    this.heartRate,
    this.heartRateTimeseries,
    this.exercisesetId,
    this.trainingId,
    this.trainingType,
    this.type,
    this.goal,
    this.goalMetric,
    this.bonusGoal,
    this.bonusGoalMetric,
    this.trainingplanId,
    this.result,
    this.feedbackEmoticon,
    this.feedbackClient,
    this.feedbackTrainer,
    this.speed,
    this.distance,
    this.trainingDate,
    this.trainingStarttime,
    this.timeseries = const [],
  });

  factory Review.fromJson(Map<String, dynamic> json) {
    // Training relation may be nested
    final training = json['training'] as Map<String, dynamic>?;

    return Review(
      id: json['id'] as int,
      file: json['file'] as String?,
      duration: json['duration'] as String?,
      kcal: _toInt(json['kcal']),
      heartRate: _toDouble(json['heart_rate']),
      heartRateTimeseries: json['heart_rate_timeseries'] as String?,
      exercisesetId: _toInt(json['exerciseset_id']),
      trainingId: _toInt(json['training_id']),
      trainingType: json['training_type'] as String?,
      type: json['type'] as String?,
      goal: _toInt(json['goal']),
      goalMetric: json['goal_metric'] as String?,
      bonusGoal: _toInt(json['bonus_goal']),
      bonusGoalMetric: json['bonus_goal_metric'] as String?,
      trainingplanId: _toInt(json['trainingplan_id']),
      result: _toInt(json['result']),
      feedbackEmoticon: json['feedback_emoticon'] as String?,
      feedbackClient: json['feedback_client'] as String?,
      feedbackTrainer: json['feedback_trainer'] as String?,
      speed: _toDouble(json['speed']),
      distance: _toDouble(json['distance']),
      trainingDate: training?['date'] as String?,
      trainingStarttime: training?['starttime'] as String?,
      timeseries: (json['timeseries'] as List<dynamic>?)
              ?.map((e) => HeartRatePoint.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Pretty display of training type
  String get trainingTypeLabel {
    const labels = {
      'cardio': 'Cardio',
      'endurance': 'Ausdauer',
      'strenght': 'Kraft',
      'speed': 'Schnelligkeit',
      'coordination': 'Koordination',
      'free': 'Freies Training',
      'running': 'Laufen',
      'fitness': 'Fitness Level',
      'interval': 'Intervall',
    };
    return labels[trainingType] ?? trainingType ?? 'Training';
  }

  /// Duration as human readable e.g. "01:23:45" → "1h 23min"
  String get durationLabel {
    if (duration == null) return '–';
    final parts = duration!.split(':');
    if (parts.length >= 2) {
      final h = int.tryParse(parts[0]) ?? 0;
      final m = int.tryParse(parts[1]) ?? 0;
      if (h > 0) return '${h}h ${m}min';
      return '${m}min';
    }
    return duration!;
  }

  static int? _toInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is double) return v.toInt();
    return int.tryParse(v.toString());
  }

  static double? _toDouble(dynamic v) {
    if (v == null) return null;
    if (v is double) return v;
    if (v is int) return v.toDouble();
    return double.tryParse(v.toString());
  }

  /// Edwards' TRIMP — time-in-zone × zone factor.
  /// Requires timeseries data and client's maxHeartRate.
  /// Optionally pass the review duration string (e.g. "00:57:41") to
  /// distribute time evenly across data points when timestamps are null.
  static double? edwardsTrimp(List<HeartRatePoint> ts, int hrMax,
      [String? durationStr]) {
    if (ts.isEmpty || hrMax <= 0) return null;

    // Sort by sort index
    final sorted = List<HeartRatePoint>.from(ts)
      ..sort((a, b) => (a.sort).compareTo(b.sort));

    // Filter valid HR points
    final valid = sorted.where((p) => p.value != null && p.value! > 0).toList();
    if (valid.isEmpty) return null;

    // Determine interval per data point (in minutes)
    double intervalMin = 0;

    // Try timestamps first
    if (valid.length >= 2 &&
        valid.first.timestamp != null &&
        valid.last.timestamp != null) {
      try {
        final dt1 = DateTime.parse(valid.first.timestamp!);
        final dt2 = DateTime.parse(valid.last.timestamp!);
        final totalSec = dt2.difference(dt1).inSeconds;
        if (totalSec > 0) {
          intervalMin = (totalSec / (valid.length - 1)) / 60.0;
        }
      } catch (_) {}
    }

    // Fallback: use duration string or estimate from data point count
    if (intervalMin <= 0) {
      double totalMinutes = 0;
      if (durationStr != null && durationStr.isNotEmpty) {
        final parts = durationStr.split(':');
        if (parts.length >= 2) {
          final h = int.tryParse(parts[0]) ?? 0;
          final m = int.tryParse(parts[1]) ?? 0;
          final s = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
          totalMinutes = h * 60.0 + m + s / 60.0;
        }
      }
      if (totalMinutes <= 0) {
        // Estimate: assume ~1 data point per second (common for HR monitors)
        totalMinutes = valid.length / 60.0;
      }
      intervalMin = totalMinutes / valid.length;
    }

    if (intervalMin <= 0) return null;

    double trimp = 0;
    for (final p in valid) {
      final pct = p.value! / hrMax;
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

  /// Color for TRIMP rating
  static int trimpColorValue(double trimp) {
    if (trimp < 50) return 0xFF4CAF50;   // green
    if (trimp < 100) return 0xFF8BC34A;  // light green
    if (trimp < 150) return 0xFFFFC107;  // amber
    if (trimp < 200) return 0xFFFF9800;  // orange
    if (trimp < 300) return 0xFFFF5722;  // deep orange
    return 0xFFF44336;                    // red
  }

  /// Banister's TRIMP — exponential HR reserve model.
  /// More scientifically accurate than Edwards.
  /// gender: 'm' for male, 'f' for female.
  static double? banisterTrimp(
    List<HeartRatePoint> ts, int hrMax, int hrRest, String gender,
    [String? durationStr]
  ) {
    if (ts.isEmpty || hrMax <= hrRest || hrMax <= 0) return null;

    final valid = ts.where((p) => p.value != null && p.value! > 0).toList();
    if (valid.isEmpty) return null;

    // Calculate weighted average HR
    final avgHr = valid.fold<double>(0, (s, p) => s + p.value!) / valid.length;

    // Determine total duration in minutes
    double totalMinutes = 0;
    if (durationStr != null && durationStr.isNotEmpty) {
      final parts = durationStr.split(':');
      if (parts.length >= 2) {
        final h = int.tryParse(parts[0]) ?? 0;
        final m = int.tryParse(parts[1]) ?? 0;
        final s = parts.length >= 3 ? (int.tryParse(parts[2]) ?? 0) : 0;
        totalMinutes = h * 60.0 + m + s / 60.0;
      }
    }
    if (totalMinutes <= 0) totalMinutes = valid.length / 60.0;

    final hrR = (avgHr - hrRest) / (hrMax - hrRest);
    if (hrR <= 0 || hrR > 1) return null;

    // Gender-specific coefficients
    final double a, b;
    if (gender == 'f') {
      a = 0.86;
      b = 1.67;
    } else {
      a = 0.64;
      b = 1.92;
    }

    // TRIMP = T × HRr × a × e^(b × HRr)
    return totalMinutes * hrR * a * exp(b * hrR);
  }
}

/// Single heart-rate data point in a training recording.
class HeartRatePoint {
  final int id;
  final String? timestamp;
  final double? value;
  final int sort;
  final int reviewId;

  HeartRatePoint({
    required this.id,
    this.timestamp,
    this.value,
    required this.sort,
    required this.reviewId,
  });

  factory HeartRatePoint.fromJson(Map<String, dynamic> json) {
    return HeartRatePoint(
      id: json['id'] as int,
      timestamp: json['timestamp'] as String?,
      value: Review._toDouble(json['value']),
      sort: json['sort'] as int? ?? 0,
      reviewId: json['review_id'] as int? ?? 0,
    );
  }
}
