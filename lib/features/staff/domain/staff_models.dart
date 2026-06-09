class StaffModel {
  const StaffModel({
    required this.id,
    required this.userId,
    required this.firstName,
    required this.lastName,
    this.phone,
    this.specialties = const [],
    this.commissionRate,
    this.photoUrl,
    this.isActive = true,
  });

  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? phone;
  final List<String> specialties;
  final double? commissionRate;
  final String? photoUrl;
  final bool isActive;

  String get fullName => '$firstName $lastName';
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  StaffModel copyWith({
    String? firstName, String? lastName, String? phone,
    List<String>? specialties, double? commissionRate, String? photoUrl, bool? isActive,
  }) => StaffModel(
        id: id, userId: userId,
        firstName: firstName ?? this.firstName, lastName: lastName ?? this.lastName,
        phone: phone ?? this.phone, specialties: specialties ?? this.specialties,
        commissionRate: commissionRate ?? this.commissionRate,
        photoUrl: photoUrl ?? this.photoUrl, isActive: isActive ?? this.isActive,
      );
}
