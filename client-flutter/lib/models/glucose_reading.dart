/// Einzelne CGM-Messung vom FreeStyle Libre Sensor.
/// TrendArrow: 1=steigt stark, 2=steigt, 3=steigt leicht,
/// 4=stabil, 5=fällt leicht, 6=fällt, 7=fällt stark.
class GlucoseReading {
  final double valueMmol;     // mmol/L
  final int valueMgDl;        // mg/dL
  final DateTime timestamp;
  final int trendArrow;       // 1–7
  final bool isHigh;
  final bool isLow;

  const GlucoseReading({
    required this.valueMmol,
    required this.valueMgDl,
    required this.timestamp,
    required this.trendArrow,
    required this.isHigh,
    required this.isLow,
  });

  factory GlucoseReading.fromJson(Map<String, dynamic> json) {
    return GlucoseReading(
      valueMmol: (json['Value'] as num?)?.toDouble() ?? 0.0,
      valueMgDl: (json['ValueInMgPerDl'] as num?)?.toInt() ?? 0,
      timestamp: _parseTimestamp(json['Timestamp'] as String? ?? ''),
      trendArrow: (json['TrendArrow'] as num?)?.toInt() ?? 4,
      isHigh: json['isHigh'] as bool? ?? false,
      isLow: json['isLow'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'Value': valueMmol,
        'ValueInMgPerDl': valueMgDl,
        'Timestamp': timestamp.toIso8601String(),
        'TrendArrow': trendArrow,
        'isHigh': isHigh,
        'isLow': isLow,
      };

  String get trendIcon {
    const icons = ['', '↑↑', '↑', '↗', '→', '↘', '↓', '↓↓'];
    return trendArrow >= 1 && trendArrow <= 7 ? icons[trendArrow] : '→';
  }

  String get displayValue => '${valueMmol.toStringAsFixed(1)} mmol/L';

  static DateTime _parseTimestamp(String raw) {
    try {
      // LibreView liefert: "1/15/2025 10:30:00 AM"
      return DateTime.parse(raw);
    } catch (_) {
      try {
        return DateTimeParser.parse(raw);
      } catch (_) {
        return DateTime.now();
      }
    }
  }
}

/// Hilfklasse für das LibreView-Datumsformat "M/D/YYYY H:MM:SS AM/PM".
class DateTimeParser {
  static DateTime parse(String raw) {
    final parts = raw.trim().split(' ');
    if (parts.length < 2) throw FormatException('Ungültiges Datumsformat: $raw');
    final dateParts = parts[0].split('/');
    final timeParts = parts[1].split(':');
    final isPm = parts.length > 2 && parts[2].toUpperCase() == 'PM';
    int hour = int.parse(timeParts[0]);
    if (isPm && hour != 12) hour += 12;
    if (!isPm && hour == 12) hour = 0;
    return DateTime(
      int.parse(dateParts[2]),
      int.parse(dateParts[0]),
      int.parse(dateParts[1]),
      hour,
      int.parse(timeParts[1]),
      int.parse(timeParts[2]),
    );
  }
}
