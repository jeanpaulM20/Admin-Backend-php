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
