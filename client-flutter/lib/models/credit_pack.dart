class CreditPack {
  final String title;
  final int prepaidCredits;
  final int spentCredits;
  final DateTime? expiryDate;

  CreditPack({
    required this.title,
    required this.prepaidCredits,
    required this.spentCredits,
    this.expiryDate,
  });

  int get remainingCredits => prepaidCredits - spentCredits;

  factory CreditPack.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      try {
        return DateTime.parse(val.toString());
      } catch (_) {
        return null;
      }
    }

    return CreditPack(
      title: json['title']?.toString() ?? '',
      prepaidCredits:
          int.tryParse(json['prepaidCredits']?.toString() ?? '0') ?? 0,
      spentCredits:
          int.tryParse(json['spentCredits']?.toString() ?? '0') ?? 0,
      expiryDate: parseDate(json['expiryDate']),
    );
  }
}
