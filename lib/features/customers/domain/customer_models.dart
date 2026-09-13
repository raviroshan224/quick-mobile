class CustomerModel {
  const CustomerModel({
    required this.id,
    required this.firstName,
    required this.lastName,
    this.email,
    this.phone,
    this.address,
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
  final String? address;
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

  factory CustomerModel.fromJson(Map<String, dynamic> j) => CustomerModel(
        id: j['id'] as String,
        firstName: j['firstName'] as String? ?? '',
        lastName: j['lastName'] as String? ?? '',
        email: j['email'] as String?,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        notes: j['notes'] as String?,
        photoUrl: j['photoUrl'] as String?,
        visitCount: j['visitCount'] as int? ?? 0,
        totalSpent: (j['totalSpent'] as num?)?.toDouble() ?? 0.0,
      );

  // Local-only round-trip (session persistence), not sent to the backend.
  Map<String, dynamic> toJson() => {
        'id': id,
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'address': address,
        'notes': notes,
        'photoUrl': photoUrl,
        'visitCount': visitCount,
        'totalSpent': totalSpent,
      };

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
    String? firstName, String? lastName, String? email, String? phone, String? address,
    String? notes, String? photoUrl, int? visitCount, double? totalSpent, DateTime? lastVisitDate,
  }) => CustomerModel(
        id: id,
        firstName: firstName ?? this.firstName, lastName: lastName ?? this.lastName,
        email: email ?? this.email, phone: phone ?? this.phone, address: address ?? this.address,
        notes: notes ?? this.notes,
        photoUrl: photoUrl ?? this.photoUrl, visitCount: visitCount ?? this.visitCount,
        totalSpent: totalSpent ?? this.totalSpent, lastVisitDate: lastVisitDate ?? this.lastVisitDate,
      );
}
