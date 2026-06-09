enum UserRole { owner, staff }

class UserModel {
  const UserModel({
    required this.id,
    required this.email,
    required this.firstName,
    required this.lastName,
    required this.role,
  });

  final String id;
  final String email;
  final String firstName;
  final String lastName;
  final UserRole role;

  String get fullName => '$firstName $lastName';
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  bool get isOwner => role == UserRole.owner;

  factory UserModel.fromJson(Map<String, dynamic> j) => UserModel(
        id: j['id'] as String,
        email: j['email'] as String,
        firstName: j['firstName'] as String,
        lastName: j['lastName'] as String,
        role: (j['role'] as String).toLowerCase() == 'owner' ? UserRole.owner : UserRole.staff,
      );

  UserModel copyWith({String? firstName, String? lastName, String? email}) => UserModel(
        id: id,
        email: email ?? this.email,
        firstName: firstName ?? this.firstName,
        lastName: lastName ?? this.lastName,
        role: role,
      );
}
