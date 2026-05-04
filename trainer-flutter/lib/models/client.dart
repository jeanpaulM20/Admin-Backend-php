class Client {
  final int id;
  final String name;
  final String? email;
  final String? phone;
  final String? photo;
  final String? address;
  final String? dateOfBirth;
  final String? notes;
  final String? memberSince;
  final int? trainerId;
  final String? trainingType;
  final String? locationName;
  final int? minHeartRate;
  final int? maxHeartRate;
  final bool autoTrainingNotify;

  const Client({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.photo,
    this.address,
    this.dateOfBirth,
    this.notes,
    this.memberSince,
    this.trainerId,
    this.trainingType,
    this.locationName,
    this.minHeartRate,
    this.maxHeartRate,
    this.autoTrainingNotify = false,
  });

  factory Client.fromJson(Map<String, dynamic> json) {
    return Client(
      id: _parseInt(json['id'] ?? json['client_id'] ?? 0),
      name: _buildName(json),
      email: json['email']?.toString(),
      phone: json['phone']?.toString() ??
          json['mobile']?.toString() ??
          json['telephone']?.toString(),
      photo: json['photo']?.toString() ??
          json['picture']?.toString() ??
          json['image']?.toString() ??
          json['avatar']?.toString() ??
          json['foto']?.toString(),
      address: _buildAddress(json),
      dateOfBirth: json['date_of_birth']?.toString() ??
          json['birthday']?.toString() ??
          json['dob']?.toString(),
      notes:
          json['notes']?.toString() ?? json['comment']?.toString(),
      memberSince: json['member_since']?.toString() ??
          json['created_at']?.toString() ??
          json['registration_date']?.toString(),
      trainerId: _parseInt(json['trainer_id']),
      trainingType: json['training_type']?.toString() ??
          json['type']?.toString(),
      locationName: json['location_name']?.toString() ??
          json['location']?.toString(),
      minHeartRate: _parseNullableInt(json['min_heart_rate'] ?? json['minHeartRate']),
      maxHeartRate: _parseNullableInt(json['max_heart_rate'] ?? json['maxHeartRate']),
      autoTrainingNotify: (json['auto_training_notify'] ?? json['autoTrainingNotify'] ?? 0) == 1 ||
          (json['auto_training_notify'] ?? json['autoTrainingNotify'] ?? false) == true,
    );
  }

  static String _buildName(Map<String, dynamic> json) {
    if (json.containsKey('name') && json['name'] != null) {
      final first = json['name'].toString().trim();
      // Combine with surname/last_name if present to build full name
      final surname = (json['surname']?.toString() ??
              json['last_name']?.toString() ??
              json['lastname']?.toString() ??
              '')
          .trim();
      if (surname.isNotEmpty) return '$first $surname';
      return first;
    }
    final firstName = json['first_name']?.toString() ??
        json['firstname']?.toString() ??
        '';
    final lastName = json['last_name']?.toString() ??
        json['lastname']?.toString() ??
        json['surname']?.toString() ??
        '';
    final fullName = '$firstName $lastName'.trim();
    return fullName.isNotEmpty ? fullName : 'Unknown Client';
  }

  static String? _buildAddress(Map<String, dynamic> json) {
    if (json.containsKey('address') && json['address'] != null) {
      return json['address'].toString();
    }
    final street = json['street']?.toString() ?? '';
    final city = json['city']?.toString() ?? '';
    final zip = json['zip']?.toString() ?? json['postal_code']?.toString() ?? '';
    final parts = [street, zip, city].where((s) => s.isNotEmpty).toList();
    return parts.isNotEmpty ? parts.join(', ') : null;
  }

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }

  static int? _parseNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value == 0 ? null : value;
    if (value is String) return int.tryParse(value);
    return null;
  }

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[parts.length - 1][0]}'.toUpperCase();
  }
}
