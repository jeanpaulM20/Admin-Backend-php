class MetricHistoryPoint {
  final DateTime date;
  final double value;
  final String unit;

  MetricHistoryPoint({
    required this.date,
    required this.value,
    this.unit = '',
  });

  factory MetricHistoryPoint.fromJson(Map<String, dynamic> json) {
    return MetricHistoryPoint(
      date: DateTime.tryParse(json['date']?.toString() ?? '') ?? DateTime.now(),
      value: double.tryParse(json['value']?.toString() ?? '0') ?? 0,
      unit: json['unit']?.toString() ?? '',
    );
  }
}
