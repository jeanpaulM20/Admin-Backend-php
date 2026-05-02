class Trainer {
  final String id;
  final String firstName;
  final String lastName;
  final String shortName;
  final String? picture;
  final String? color;

  Trainer({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.shortName,
    this.picture,
    this.color,
  });

  String get fullName => '$firstName $lastName';

  factory Trainer.fromJson(Map<String, dynamic> json) {
    final first = json['firstname']?.toString() ?? '';
    final last = json['lastname']?.toString() ?? '';
    final shortName = json['shortName']?.toString() ??
        '${first.isNotEmpty ? first[0] : ''}${last.isNotEmpty ? last[0] : ''}';

    return Trainer(
      id: json['id']?.toString() ?? '',
      firstName: first,
      lastName: last,
      shortName: shortName,
      picture: json['picture']?.toString(),
      color: json['color']?.toString(),
    );
  }
}
