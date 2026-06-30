class ProfileModel {
  const ProfileModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.role,
    this.photoUrl,
    this.hasPin = false,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String role;
  final String? photoUrl;
  final bool hasPin;

  String get fullName => '$firstName $lastName';
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  bool get isOwner => role == 'OWNER';

  factory ProfileModel.fromJson(Map<String, dynamic> j) => ProfileModel(
        id: j['id'] as String,
        firstName: j['firstName'] as String,
        lastName: j['lastName'] as String,
        role: j['role'] as String,
        photoUrl: j['photoUrl'] as String?,
        hasPin: j['hasPin'] as bool? ?? false,
      );
}
