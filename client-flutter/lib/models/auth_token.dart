class AuthToken {
  final String token;
  final String clientId;
  final String? firstName;
  final String? lastName;

  AuthToken({
    required this.token,
    required this.clientId,
    this.firstName,
    this.lastName,
  });

  factory AuthToken.fromJson(Map<String, dynamic> json) {
    final client = json['client'];
    String clientId = '';
    String? firstName;
    String? lastName;

    if (client is Map<String, dynamic>) {
      clientId = client['id']?.toString() ?? '';
      firstName = client['firstname']?.toString();
      lastName = client['lastname']?.toString();
    }

    return AuthToken(
      token: json['token']?.toString() ?? '',
      clientId: clientId,
      firstName: firstName,
      lastName: lastName,
    );
  }
}
