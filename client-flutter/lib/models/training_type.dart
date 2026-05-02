class TrainingType {
  final String id;
  final String name;
  final int duration; // seconds

  TrainingType({
    required this.id,
    required this.name,
    required this.duration,
  });

  int get durationMinutes => duration ~/ 60;

  factory TrainingType.fromJson(Map<String, dynamic> json) {
    return TrainingType(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      duration: int.tryParse(json['duration']?.toString() ?? '3600') ?? 3600,
    );
  }
}
