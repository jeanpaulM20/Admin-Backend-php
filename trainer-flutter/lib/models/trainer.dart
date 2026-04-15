class Trainer {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? photo;
  final String? description;
  final String? passcode;

  const Trainer({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photo,
    this.description,
    this.passcode,
  });

  factory Trainer.fromJson(Map<String, dynamic> json) {
    return Trainer(
      id: _parseInt(json['id'] ?? json['trainer_id'] ?? 0),
      name: _parseString(json['name'] ?? json['trainer_name'] ?? ''),
      email: json['email']?.toString(),
      phone: json['phone']?.toString() ?? json['mobile']?.toString(),
      photo: json['photo']?.toString() ?? json['image']?.toString(),
      description: json['description']?.toString() ?? json['about']?.toString(),
      passcode: json['passcode']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'photo': photo,
        'description': description,
        'passcode': passcode,
      };

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static String _parseString(dynamic value) {
    if (value == null) return '';
    return value.toString();
  }
}

class AboutUsInfo {
  final String? studioName;
  final String? description;
  final String? address;
  final String? phone;
  final String? email;
  final String? website;
  final String? logoUrl;
  final List<TrainerInfo> trainers;

  const AboutUsInfo({
    this.studioName,
    this.description,
    this.address,
    this.phone,
    this.email,
    this.website,
    this.logoUrl,
    this.trainers = const [],
  });

  factory AboutUsInfo.fromJson(dynamic json) {
    if (json == null) return const AboutUsInfo();

    List<TrainerInfo> trainers = [];
    if (json is List) {
      trainers = json
          .map((e) => TrainerInfo.fromJson(e as Map<String, dynamic>))
          .toList();
      return AboutUsInfo(trainers: trainers);
    }

    if (json is Map<String, dynamic>) {
      final trainersList = json['trainers'];
      if (trainersList is List) {
        trainers = trainersList
            .map((e) => TrainerInfo.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return AboutUsInfo(
        studioName: json['studio_name']?.toString() ?? json['name']?.toString(),
        description:
            json['description']?.toString() ?? json['about']?.toString(),
        address: json['address']?.toString(),
        phone: json['phone']?.toString(),
        email: json['email']?.toString(),
        website: json['website']?.toString(),
        logoUrl: json['logo']?.toString() ?? json['logo_url']?.toString(),
        trainers: trainers,
      );
    }

    return const AboutUsInfo();
  }
}

class TrainerInfo {
  final int id;
  final String name;
  final String? photo;
  final String? description;
  final String? specialization;

  const TrainerInfo({
    required this.id,
    required this.name,
    this.photo,
    this.description,
    this.specialization,
  });

  factory TrainerInfo.fromJson(Map<String, dynamic> json) {
    return TrainerInfo(
      id: int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? json['trainer_name']?.toString() ?? '',
      photo: json['photo']?.toString() ?? json['image']?.toString(),
      description:
          json['description']?.toString() ?? json['about']?.toString(),
      specialization: json['specialization']?.toString(),
    );
  }
}
