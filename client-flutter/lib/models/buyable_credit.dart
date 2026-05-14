/// A credit package available for purchase (from sihltraining.ch pricing)
class CreditPackage {
  final String id;
  final String name;
  final int credits;
  final double price;
  final double? pricePerSession;
  final int? durationMonths;
  final String? description;
  final String? includes;

  CreditPackage({
    required this.id,
    required this.name,
    required this.credits,
    required this.price,
    this.pricePerSession,
    this.durationMonths,
    this.description,
    this.includes,
  });

  factory CreditPackage.fromJson(Map<String, dynamic> json) {
    return CreditPackage(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      credits: int.tryParse(json['credits']?.toString() ?? '0') ?? 0,
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
      pricePerSession: json['pricePerSession'] != null
          ? double.tryParse(json['pricePerSession'].toString())
          : null,
      durationMonths: json['durationMonths'] != null
          ? int.tryParse(json['durationMonths'].toString())
          : null,
      description: json['description']?.toString(),
      includes: json['includes']?.toString(),
    );
  }
}

/// Represents a client's owned credit pack (from the API)
class ClientCredit {
  final String id;
  final String title;
  final int paid;
  final int attended;
  final int remaining;
  final String? startdate;
  final String? expires;

  ClientCredit({
    required this.id,
    required this.title,
    required this.paid,
    required this.attended,
    required this.remaining,
    this.startdate,
    this.expires,
  });

  factory ClientCredit.fromJson(Map<String, dynamic> json) {
    final paid = int.tryParse(json['paid']?.toString() ?? '0') ?? 0;
    final attended = int.tryParse(json['attended']?.toString() ?? '0') ?? 0;
    return ClientCredit(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Credit-Paket',
      paid: paid,
      attended: attended,
      remaining: int.tryParse(json['remaining']?.toString() ?? '0') ?? (paid - attended),
      startdate: json['startdate']?.toString(),
      expires: json['expires']?.toString(),
    );
  }
}
