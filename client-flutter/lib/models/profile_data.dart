import 'credit_pack.dart';

class ProfileData {
  final String firstName;
  final String lastName;
  final String? imageUrl;
  final String? email;
  final String? phone;
  final String? birthday;
  final String? gender;
  final List<CreditPack> creditPacks;

  ProfileData({
    required this.firstName,
    required this.lastName,
    this.imageUrl,
    this.email,
    this.phone,
    this.birthday,
    this.gender,
    this.creditPacks = const [],
  });

  String get fullName => '$lastName $firstName';
  String get initials =>
      '${lastName.isNotEmpty ? lastName[0] : ''}${firstName.isNotEmpty ? firstName[0] : ''}'
          .toUpperCase();

  factory ProfileData.fromJson(Map<String, dynamic> json) {
    final rawCredits = json['creditPacks'] ?? json['credit_packs'];
    final creditPacks = <CreditPack>[];
    if (rawCredits is List) {
      for (final c in rawCredits) {
        if (c is Map<String, dynamic>) {
          creditPacks.add(CreditPack.fromJson(c));
        }
      }
    }

    return ProfileData(
      firstName: json['firstname']?.toString() ?? json['firstName']?.toString() ?? '',
      lastName: json['lastname']?.toString() ?? json['lastName']?.toString() ?? '',
      imageUrl: json['photo']?.toString() ?? json['picture']?.toString() ?? json['foto']?.toString() ?? json['imageUrl']?.toString(),
      email: json['email']?.toString(),
      phone: json['phone']?.toString(),
      birthday: json['birthday']?.toString(),
      gender: json['gender']?.toString(),
      creditPacks: creditPacks,
    );
  }
}
