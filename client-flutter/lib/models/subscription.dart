/// Online-coaching subscription status for the current client.
class SubscriptionStatus {
  final bool active;
  final String? tier; // 'monthly' | 'yearly'
  final String? validFrom;
  final String? validTo;

  SubscriptionStatus({
    this.active = false,
    this.tier,
    this.validFrom,
    this.validTo,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    return SubscriptionStatus(
      active: json['active'] == true,
      tier: json['tier']?.toString(),
      validFrom: json['validFrom']?.toString(),
      validTo: json['validTo']?.toString(),
    );
  }

  String get tierLabel {
    switch (tier) {
      case 'yearly':
        return 'Jahres-Abo';
      case 'monthly':
        return 'Monats-Abo';
      default:
        return 'Online Coaching';
    }
  }
}
