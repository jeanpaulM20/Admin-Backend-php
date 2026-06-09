import 'dart:convert';

/// One exercise row inside a section. Read-only on the client side.
class TrainingPlanRow {
  final String exercise;
  final String device;
  final String position;
  final String weight;
  final String sets; // e.g. "3×12"
  final List<String> dates; // weekly result columns
  final List<int> timers; // saved timer presets (seconds)

  TrainingPlanRow({
    this.exercise = '',
    this.device = '',
    this.position = '',
    this.weight = '',
    this.sets = '',
    List<String>? dates,
    List<int>? timers,
  })  : dates = dates ?? List.filled(8, ''),
        timers = timers ?? [];

  factory TrainingPlanRow.fromJson(Map<String, dynamic> json) {
    return TrainingPlanRow(
      exercise: json['exercise']?.toString() ?? '',
      device: json['device']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      sets: json['sets']?.toString() ?? '',
      dates: json['dates'] is List
          ? List<String>.from(
              (json['dates'] as List).map((e) => e?.toString() ?? ''))
          : List.filled(8, ''),
      timers: _parseTimers(json),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }

  static List<int> _parseTimers(Map<String, dynamic> json) {
    if (json['timers'] is List) {
      return List<int>.from(
        (json['timers'] as List).map((e) => _parseInt(e)).where((v) => v > 0),
      );
    }
    final single = _parseInt(json['timer']);
    return single > 0 ? [single] : [];
  }
}

/// The four sections of a plan plus the shared weekly date headers.
class TrainingPlanValues {
  final List<TrainingPlanRow> sonsomo;
  final List<TrainingPlanRow> main;
  final List<TrainingPlanRow> core;
  final List<TrainingPlanRow> mobility;
  final List<String> dates;

  TrainingPlanValues({
    List<TrainingPlanRow>? sonsomo,
    List<TrainingPlanRow>? main,
    List<TrainingPlanRow>? core,
    List<TrainingPlanRow>? mobility,
    List<String>? dates,
  })  : sonsomo = sonsomo ?? [],
        main = main ?? [],
        core = core ?? [],
        mobility = mobility ?? [],
        dates = dates ?? List.filled(8, '');

  factory TrainingPlanValues.fromJson(Map<String, dynamic> json) {
    List<TrainingPlanRow> parseRows(dynamic list) {
      if (list is List) {
        return list
            .whereType<Map<String, dynamic>>()
            .map(TrainingPlanRow.fromJson)
            .toList();
      }
      return [];
    }

    return TrainingPlanValues(
      sonsomo: parseRows(json['sonsomo']),
      main: parseRows(json['main']),
      core: parseRows(json['core']),
      mobility: parseRows(json['mobility']),
      dates: json['dates'] is List
          ? List<String>.from(
              (json['dates'] as List).map((e) => e?.toString() ?? ''))
          : List.filled(8, ''),
    );
  }
}

/// A training plan as seen by the client. The backend returns either a teaser
/// (locked: metadata + per-section counts, no exercises) or the full plan
/// (with [values]) when the client is entitled (free window or subscription).
class ClientTrainingPlan {
  final int? id;
  final int? clientId;
  final String? name;
  final String? type;
  final String? status;
  final String? publishedAt;
  final bool locked;
  final bool requiresSubscription;

  /// Exercise count per section (always present — for list cards).
  final Map<String, int> sections;

  /// Full content — only present when unlocked.
  final TrainingPlanValues? values;

  /// Client's like/dislike per exercise key (from server, included in full plan).
  final Map<String, String>? clientLikes;

  /// First exercise name — used as cover image key for the plan list card.
  final String? coverExerciseName;

  ClientTrainingPlan({
    this.id,
    this.clientId,
    this.name,
    this.type,
    this.status,
    this.publishedAt,
    this.locked = false,
    this.requiresSubscription = false,
    Map<String, int>? sections,
    this.values,
    this.clientLikes,
    this.coverExerciseName,
  }) : sections = sections ?? {};

  int get totalExercises =>
      sections.values.fold(0, (sum, n) => sum + n);

  factory ClientTrainingPlan.fromJson(Map<String, dynamic> json) {
    // Full plan carries a `values` JSON; teaser does not.
    TrainingPlanValues? values;
    final raw = json['values'];
    if (raw is String && raw.isNotEmpty) {
      try {
        values = TrainingPlanValues.fromJson(
            jsonDecode(raw) as Map<String, dynamic>);
      } catch (_) {}
    } else if (raw is Map<String, dynamic>) {
      values = TrainingPlanValues.fromJson(raw);
    }

    // Sections: from teaser payload, else derived from full values.
    final sections = <String, int>{};
    if (json['sections'] is Map) {
      (json['sections'] as Map).forEach((k, v) {
        final n = v is int ? v : int.tryParse(v.toString()) ?? 0;
        if (n > 0) sections[k.toString()] = n;
      });
    } else if (values != null) {
      if (values.sonsomo.isNotEmpty) sections['sonsomo'] = values.sonsomo.length;
      if (values.main.isNotEmpty) sections['main'] = values.main.length;
      if (values.core.isNotEmpty) sections['core'] = values.core.length;
      if (values.mobility.isNotEmpty) sections['mobility'] = values.mobility.length;
    }

    int? asInt(dynamic v) =>
        v is int ? v : int.tryParse(v?.toString() ?? '');

    return ClientTrainingPlan(
      id: asInt(json['id']),
      clientId: asInt(json['client_id'] ?? json['clientId']),
      name: json['name']?.toString(),
      type: json['type']?.toString(),
      status: json['status']?.toString(),
      publishedAt: (json['publishedAt'] ?? json['published_at'])?.toString(),
      locked: json['locked'] == true,
      requiresSubscription: json['requiresSubscription'] == true,
      sections: sections,
      values: values,
      clientLikes: json['clientLikes'] is Map
          ? Map<String, String>.from(
              (json['clientLikes'] as Map).map((k, v) => MapEntry(k.toString(), v.toString())))
          : null,
      coverExerciseName: json['coverExerciseName']?.toString(),
    );
  }
}
