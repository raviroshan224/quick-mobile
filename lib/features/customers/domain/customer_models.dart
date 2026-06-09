class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.notes,
    this.photoUrl,
    this.visitCount = 0,
    this.totalSpent = 0,
    this.lastVisitDate,
  });

  final String id;
  final String firstName;
  final String lastName;
  final String? email;
  final String? phone;
  final String? notes;
  final String? photoUrl;
  final int visitCount;
  final double totalSpent;
  final DateTime? lastVisitDate;

  String get fullName => '$firstName $lastName';
  String get initials {
    final f = firstName.isNotEmpty ? firstName[0] : '';
    final l = lastName.isNotEmpty ? lastName[0] : '';
    return '$f$l'.toUpperCase();
  }

  String get lastVisitLabel {
    if (lastVisitDate == null) return 'Never';
    final diff = DateTime.now().difference(lastVisitDate!);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }

  CustomerModel copyWith({
    String? firstName, String? lastName, String? email, String? phone,
    String? notes, String? photoUrl, int? visitCount, double? totalSpent, DateTime? lastVisitDate,
  }) => CustomerModel(
        id: id,
        firstName: firstName ?? this.firstName, lastName: lastName ?? this.lastName,
        email: email ?? this.email, phone: phone ?? this.phone, notes: notes ?? this.notes,
        photoUrl: photoUrl ?? this.photoUrl, visitCount: visitCount ?? this.visitCount,
        totalSpent: totalSpent ?? this.totalSpent, lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      );
}
