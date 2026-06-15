/// Auth-Ticket vom LibreLinkUp Login-Endpoint.
class LibreAuthTicket {
  final String token;
  final DateTime expires;

  const LibreAuthTicket({required this.token, required this.expires});

  bool get isExpired => DateTime.now().isAfter(expires);

  factory LibreAuthTicket.fromJson(Map<String, dynamic> json) {
    final ticket = json['authTicket'] as Map<String, dynamic>? ?? json;
    // `expires` kommt als Unix-Timestamp in Millisekunden
    final expiresMs = (ticket['expires'] as num?)?.toInt() ?? 0;
    return LibreAuthTicket(
      token: ticket['token'] as String? ?? '',
      expires: expiresMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(expiresMs)
          : DateTime.now().add(const Duration(days: 180)),
    );
  }

  Map<String, dynamic> toJson() => {
        'token': token,
        'expires': expires.millisecondsSinceEpoch,
      };
}

/// Libre-Verbindung (i.d.R. der Patient selbst oder ein Follower-Profil).
class LibreConnection {
  final String patientId;
  final String firstName;
  final String lastName;

  const LibreConnection({
    required this.patientId,
    required this.firstName,
    required this.lastName,
  });

  factory LibreConnection.fromJson(Map<String, dynamic> json) {
    return LibreConnection(
      patientId: json['patientId'] as String? ?? '',
      firstName: json['firstName'] as String? ?? '',
      lastName: json['lastName'] as String? ?? '',
    );
  }
}

/// Region bestimmt den API-Endpunkt.
enum LibreRegion {
  eu('https://api-eu.libreview.io'),
  us('https://api.libreview.io'),
  de('https://api-de.libreview.io'),
  ap('https://api-ap.libreview.io');

  final String baseUrl;
  const LibreRegion(this.baseUrl);
}
