class ExerciseGroup {
  final int id;
  final String name;

  const ExerciseGroup({required this.id, required this.name});

  factory ExerciseGroup.fromJson(Map<String, dynamic> json) => ExerciseGroup(
        id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
        name: json['name']?.toString() ?? '',
      );
}

class Exercise {
  final int id;
  final String name;
  final int? groupId;
  final int? subgroupId;
  final String? bodyRegion;
  final String? primaryMuscleGroup;
  final String? targetJoint;
  final String? movementPattern;
  final ExerciseGroup? group;
  final String? subgroupName;

  const Exercise({
    required this.id,
    required this.name,
    this.groupId,
    this.subgroupId,
    this.bodyRegion,
    this.primaryMuscleGroup,
    this.targetJoint,
    this.movementPattern,
    this.group,
    this.subgroupName,
  });

  factory Exercise.fromJson(Map<String, dynamic> json) {
    ExerciseGroup? group;
    if (json['group'] is Map<String, dynamic>) {
      group = ExerciseGroup.fromJson(json['group'] as Map<String, dynamic>);
    }
    String? subName;
    if (json['subgroup'] is Map<String, dynamic>) {
      subName = (json['subgroup'] as Map<String, dynamic>)['name']?.toString();
    }

    return Exercise(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '') ?? 0,
      name: json['name']?.toString() ?? '',
      groupId: json['group_id'] is int ? json['group_id'] : json['groupId'] is int ? json['groupId'] : null,
      subgroupId: json['subgroup_id'] is int ? json['subgroup_id'] : json['subgroupId'] is int ? json['subgroupId'] : null,
      bodyRegion: json['body_region']?.toString() ?? json['bodyRegion']?.toString(),
      primaryMuscleGroup: json['primary_muscle_group']?.toString() ?? json['primaryMuscleGroup']?.toString(),
      targetJoint: json['target_joint']?.toString() ?? json['targetJoint']?.toString(),
      movementPattern: json['movement_pattern']?.toString() ?? json['movementPattern']?.toString(),
      group: group,
      subgroupName: subName,
    );
  }

  Map<String, dynamic> toJson() => {
        'name': name,
        if (groupId != null) 'groupId': groupId,
        if (subgroupId != null) 'subgroupId': subgroupId,
        if (bodyRegion != null) 'body_region': bodyRegion,
        if (primaryMuscleGroup != null) 'primary_muscle_group': primaryMuscleGroup,
        if (targetJoint != null) 'target_joint': targetJoint,
        if (movementPattern != null) 'movement_pattern': movementPattern,
      };

  /// Localized label for body region.
  String get bodyRegionLabel => bodyRegionLabels[bodyRegion] ?? bodyRegion ?? '';

  static const bodyRegionLabels = {
    'UpperBody': 'Oberkörper',
    'LowerBody': 'Unterkörper',
    'Core': 'Core',
    'FullBody': 'Ganzkörper',
    'Foot': 'Fuß',
  };

  static const bodyRegions = ['UpperBody', 'LowerBody', 'Core', 'FullBody', 'Foot'];

  static const movementPatterns = [
    'Push', 'Pull', 'Squat', 'Hinge', 'Carry',
    'Rotation', 'Static', 'Plyo', 'Sprint', 'Agility',
  ];
}
