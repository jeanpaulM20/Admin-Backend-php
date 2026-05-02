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
  final double? hrv;
  final List<HrPoint> chart;

  const TrainingReview({
    required this.id,
    required this.date,
    required this.trainingType,
    this.duration,
    this.hrMax,
    this.hrAvg,
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
      hrv: json['hrv'] != null ? double.tryParse(json['hrv'].toString()) : null,
      chart: chart,
    );
  }
}
