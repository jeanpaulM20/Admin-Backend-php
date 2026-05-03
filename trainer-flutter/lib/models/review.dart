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
  static double? edwardsTrimp(List<HeartRatePoint> ts, int hrMax) {
    if (ts.length < 2 || hrMax <= 0) return null;

    // Sort by timestamp to compute intervals
    final sorted = List<HeartRatePoint>.from(ts)
      ..sort((a, b) => (a.sort).compareTo(b.sort));

    double trimp = 0;
    for (int i = 0; i < sorted.length - 1; i++) {
      final hr = sorted[i].value;
      if (hr == null || hr <= 0) continue;

      // Interval in minutes between consecutive data points
      double intervalMin;
      final t1 = sorted[i].timestamp;
      final t2 = sorted[i + 1].timestamp;
      if (t1 != null && t2 != null) {
        try {
          final dt1 = DateTime.parse(t1);
          final dt2 = DateTime.parse(t2);
          intervalMin = dt2.difference(dt1).inSeconds / 60.0;
          if (intervalMin <= 0 || intervalMin > 10) continue; // skip bad gaps
        } catch (_) {
          continue;
        }
      } else {
        continue;
      }

      // Determine HR zone (percentage of HRmax)
      final pct = hr / hrMax;
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

  /// Banister's TRIMP — exponential HR reserve model.
  /// More scientifically accurate than Edwards.
  /// gender: 'm' for male, 'f' for female.
  static double? banisterTrimp(
    List<HeartRatePoint> ts, int hrMax, int hrRest, String gender,
  ) {
    if (ts.length < 2 || hrMax <= hrRest || hrMax <= 0) return null;

    final sorted = List<HeartRatePoint>.from(ts)
      ..sort((a, b) => (a.sort).compareTo(b.sort));

    // Calculate total duration in minutes and average HR
    double totalMinutes = 0;
    double hrSum = 0;
    int hrCount = 0;

    for (int i = 0; i < sorted.length - 1; i++) {
      final hr = sorted[i].value;
      if (hr == null || hr <= 0) continue;

      final t1 = sorted[i].timestamp;
      final t2 = sorted[i + 1].timestamp;
      if (t1 == null || t2 == null) continue;

      try {
        final dt1 = DateTime.parse(t1);
        final dt2 = DateTime.parse(t2);
        final intervalMin = dt2.difference(dt1).inSeconds / 60.0;
        if (intervalMin <= 0 || intervalMin > 10) continue;
        totalMinutes += intervalMin;
        hrSum += hr * intervalMin;
        hrCount++;
      } catch (_) {
        continue;
      }
    }

    if (totalMinutes <= 0 || hrCount == 0) return null;

    final avgHr = hrSum / totalMinutes;
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
