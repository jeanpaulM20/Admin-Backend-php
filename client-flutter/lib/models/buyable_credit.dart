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
