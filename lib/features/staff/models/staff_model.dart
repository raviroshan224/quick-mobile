class StaffMember {
  final String id;
  final String userId;
  final String firstName;
  final String lastName;
  final String? phone;
  final List<String> specialties;
  final double? commissionRate;
  final String? photoUrl;
  final bool isActive;

  const StaffMember({
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

  String get fullName => '$firstName $lastName';

  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  factory StaffMember.fromJson(Map<String, dynamic> j) {
    final user = j['user'] as Map<String, dynamic>? ?? {};
    return StaffMember(
      id: j['id'] as String,
      userId: j['userId'] as String,
      firstName: user['firstName'] as String? ?? '',
      lastName: user['lastName'] as String? ?? '',
      phone: j['phone'] as String?,
      specialties: (j['specialties'] as List?)?.map((e) => e as String).toList() ?? [],
      commissionRate: (j['commissionRate'] as num?)?.toDouble(),
      photoUrl: j['photoUrl'] as String?,
      isActive: j['isActive'] as bool? ?? true,
    );
  }
}
