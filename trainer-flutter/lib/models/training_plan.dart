import 'dart:convert';

class TrainingPlanRow {
  String exercise;
  String device;
  String position;
  String weight;
  String sets;        // e.g. "3×12"
  List<String> dates;
  bool liked;
  bool disliked;

  TrainingPlanRow({
    this.exercise = '',
    this.device = '',
    this.position = '',
    this.weight = '',
    this.sets = '',
    List<String>? dates,
    this.liked = false,
    this.disliked = false,
  }) : dates = dates ?? List.filled(8, '');

  factory TrainingPlanRow.fromJson(Map<String, dynamic> json) {
    return TrainingPlanRow(
      exercise: json['exercise']?.toString() ?? '',
      device: json['device']?.toString() ?? '',
      position: json['position']?.toString() ?? '',
      weight: json['weight']?.toString() ?? '',
      sets: json['sets']?.toString() ?? '',
      dates: json['dates'] is List
          ? List<String>.from((json['dates'] as List).map((e) => e?.toString() ?? ''))
          : List.filled(8, ''),
      liked: json['liked'] == true || json['liked'] == 1 || json['liked'] == '1',
      disliked: json['disliked'] == true || json['disliked'] == 1 || json['disliked'] == '1',
    );
  }

  Map<String, dynamic> toJson() => {
        'exercise': exercise,
        'device': device,
        'position': position,
        'weight': weight,
        if (sets.isNotEmpty) 'sets': sets,
        'dates': dates,
        if (liked) 'liked': true,
        if (disliked) 'disliked': true,
      };
}

class TrainingPlanValues {
  List<TrainingPlanRow> sonsomo;
  List<TrainingPlanRow> main;
  List<TrainingPlanRow> core;
  List<TrainingPlanRow> mobility;
  List<String> dates;

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
            .map((e) => TrainingPlanRow.fromJson(e as Map<String, dynamic>))
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
          ? List<String>.from((json['dates'] as List).map((e) => e?.toString() ?? ''))
          : List.filled(8, ''),
    );
  }

  Map<String, dynamic> toJson() => {
        'sonsomo': sonsomo.map((r) => r.toJson()).toList(),
        'main': main.map((r) => r.toJson()).toList(),
        'core': core.map((r) => r.toJson()).toList(),
        'mobility': mobility.map((r) => r.toJson()).toList(),
        'dates': dates,
      };
}

class TrainingPlan {
  final int? id;
  final int? clientId;
  String? name;
  TrainingPlanValues values;
  String? createdAt;

  TrainingPlan({
    this.id,
    this.clientId,
    this.name,
    TrainingPlanValues? values,
    this.createdAt,
  }) : values = values ?? TrainingPlanValues();

  factory TrainingPlan.fromJson(Map<String, dynamic> json) {
    TrainingPlanValues parsedValues;
    final rawValues = json['values'];
    if (rawValues is String && rawValues.isNotEmpty) {
      try {
        final decoded = jsonDecode(rawValues) as Map<String, dynamic>;
        parsedValues = TrainingPlanValues.fromJson(decoded);
      } catch (_) {
        parsedValues = TrainingPlanValues();
      }
    } else if (rawValues is Map<String, dynamic>) {
      parsedValues = TrainingPlanValues.fromJson(rawValues);
    } else {
      parsedValues = TrainingPlanValues();
    }

    return TrainingPlan(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? ''),
      clientId: json['client_id'] is int
          ? json['client_id']
          : int.tryParse(json['client_id']?.toString() ?? ''),
      name: json['name']?.toString(),
      values: parsedValues,
      createdAt: json['created_at']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        if (clientId != null) 'client_id': clientId,
        if (name != null) 'name': name,
        'values': jsonEncode(values.toJson()),
      };
}
