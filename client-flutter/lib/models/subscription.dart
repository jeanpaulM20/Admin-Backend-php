/// Online-coaching subscription status for the current client.
/// Single source for the client-app state machine — all flags are
/// computed server-side, the UI never does date math.
class SubscriptionStatus {
  final bool active;
  final String? tier; // 'trial' | 'monthly' | 'yearly'
  final String? validFrom;
  final String? validTo;
  final int? daysLeft;
  final bool isTrial;
  final bool trialUsed;     // has ever used the one-time free trial
  final bool canStartTrial; // !active && !trialUsed → show trial banner
  final bool expiringSoon;  // active && daysLeft <= 7 → show renew popup

  SubscriptionStatus({
    this.active = false,
    this.tier,
    this.validFrom,
    this.validTo,
    this.daysLeft,
    this.isTrial = false,
    this.trialUsed = false,
    this.canStartTrial = false,
    this.expiringSoon = false,
  });

  factory SubscriptionStatus.fromJson(Map<String, dynamic> json) {
    final rawDays = json['daysLeft'];
    return SubscriptionStatus(
      active: json['active'] == true,
      tier: json['tier']?.toString(),
      validFrom: json['validFrom']?.toString(),
      validTo: json['validTo']?.toString(),
      daysLeft: rawDays is int ? rawDays : int.tryParse(rawDays?.toString() ?? ''),
      isTrial: json['isTrial'] == true,
      trialUsed: json['trialUsed'] == true,
      canStartTrial: json['canStartTrial'] == true,
      expiringSoon: json['expiringSoon'] == true,
    );
  }

  String get tierLabel {
    switch (tier) {
      case 'trial':
        return 'Test-Abo';
      case 'yearly':
        return 'Jahres-Abo';
      case 'monthly':
        return 'Monats-Abo';
      default:
        return 'Online Coaching';
    }
  }
}
