import 'metric_history.dart';

class PerformanceItem {
  final String name;
  final String value;
  final String previousValue;
  final String change;
  final String unit;
  final List<MetricHistoryPoint> history;

  PerformanceItem({
    required this.name,
    required this.value,
    required this.previousValue,
    required this.change,
    this.unit = '',
    this.history = const [],
  });

  factory PerformanceItem.fromJson(Map<String, dynamic> json) {
    final unit = json['unit']?.toString() ?? '';
    final rawHistory = json['history'];
    final history = <MetricHistoryPoint>[];
    if (rawHistory is List) {
      for (final h in rawHistory) {
        if (h is Map<String, dynamic>) {
          final date = DateTime.tryParse(h['date']?.toString() ?? '');
          final value = double.tryParse(h['value']?.toString() ?? '');
          if (date != null && value != null) {
            history.add(MetricHistoryPoint(date: date, value: value, unit: unit));
          }
        }
      }
    }
    return PerformanceItem(
      name: json['key']?.toString() ?? '',
      value: json['value']?.toString() ?? '',
      previousValue: json['previousValue']?.toString() ?? '',
      change: json['change']?.toString() ?? '',
      unit: unit,
      history: history,
    );
  }
}

class PerformanceSection {
  final String title;
  final List<PerformanceItem> items;

  PerformanceSection({
    required this.title,
    required this.items,
  });

  factory PerformanceSection.fromJson(Map<String, dynamic> json) {
    List<PerformanceItem> items = [];
    final raw = json['data'];
    if (raw is List) {
      items = raw
          .whereType<Map<String, dynamic>>()
          .map(PerformanceItem.fromJson)
          .toList();
    }

    return PerformanceSection(
      title: json['section']?.toString() ?? '',
      items: items,
    );
  }
}
