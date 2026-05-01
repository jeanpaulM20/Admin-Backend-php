class ClientModel {
  final int id;
  final String firstname;
  final String lastname;
  final String email;
  final String phone;
  final String? photo;
  final int credits;

  ClientModel({
    required this.id,
    required this.firstname,
    required this.lastname,
    required this.email,
    required this.phone,
    this.photo,
    this.credits = 0,
  });

  String get fullName => '$firstname $lastname'.trim();

  factory ClientModel.fromJson(Map<String, dynamic> j) {
    // PHP uses surname=Vorname, name=Nachname (same naming as Trainer)
    final first = j['firstname']?.toString() ??
        j['surname']?.toString() ??
        j['first_name']?.toString() ?? '';
    final last = j['lastname']?.toString() ??
        j['name']?.toString() ??
        j['last_name']?.toString() ?? '';
    return ClientModel(
      id: _parseInt(j['id'] ?? j['client_id'] ?? 0),
      firstname: first,
      lastname: last,
      email: j['email']?.toString() ?? '',
      phone: j['phone']?.toString() ?? j['telephone']?.toString() ?? '',
      photo: j['photo']?.toString() ?? j['picture']?.toString() ?? j['image']?.toString(),
      credits: _parseInt(j['credits'] ?? j['credit_count'] ?? 0),
    );
  }

  static int _parseInt(dynamic v) {
    if (v == null) return 0;
    if (v is int) return v;
    if (v is String) return int.tryParse(v) ?? 0;
    return 0;
  }
}
