class BuyableCredit {
  final String creditId;
  final String name;
  final String desc;
  final String unit;
  final double price;

  BuyableCredit({
    required this.creditId,
    required this.name,
    required this.desc,
    required this.unit,
    required this.price,
  });

  factory BuyableCredit.fromJson(Map<String, dynamic> json) {
    return BuyableCredit(
      creditId: json['creditId']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      desc: json['desc']?.toString() ?? json['description']?.toString() ?? '',
      unit: json['unit']?.toString() ?? '',
      price: double.tryParse(json['price']?.toString() ?? '0') ?? 0,
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
