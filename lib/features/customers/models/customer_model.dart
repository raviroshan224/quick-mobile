import 'package:uuid/uuid.dart';

const _uuid = Uuid();

class Customer {
  final String id;
  final String name;
  final String phone;
  final DateTime? birthday;
  final String? notes;
  final int visitCount;
  final double totalSpend;
  final DateTime? lastVisitDate;

  const Customer({
    required this.id,
    required this.name,
    required this.phone,
    this.birthday,
    this.notes,
    this.visitCount = 0,
    this.totalSpend = 0,
    this.lastVisitDate,
  });

  String get initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String get lastVisitLabel {
    if (lastVisitDate == null) return 'Never';
    final diff = DateTime.now().difference(lastVisitDate!);
    if (diff.inDays == 0) return 'Today';
    if (diff.inDays == 1) return 'Yesterday';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
    return '${(diff.inDays / 365).floor()}y ago';
  }

  Customer copyWith({
    String? name,
    String? phone,
    DateTime? birthday,
    String? notes,
    int? visitCount,
    double? totalSpend,
    DateTime? lastVisitDate,
  }) {
    return Customer(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      birthday: birthday ?? this.birthday,
      notes: notes ?? this.notes,
      visitCount: visitCount ?? this.visitCount,
      totalSpend: totalSpend ?? this.totalSpend,
      lastVisitDate: lastVisitDate ?? this.lastVisitDate,
    );
  }

  static Customer create({
    required String name,
    required String phone,
    DateTime? birthday,
    String? notes,
  }) {
    return Customer(
      id: _uuid.v4(),
      name: name,
      phone: phone,
      birthday: birthday,
      notes: notes,
      visitCount: 0,
      totalSpend: 0,
    );
  }
}

/// A single visit record shown on the customer detail screen.
class VisitRecord {
  final String id;
  final DateTime date;
  final List<String> services;
  final double total;

  const VisitRecord({
    required this.id,
    required this.date,
    required this.services,
    required this.total,
  });

  String get dateLabel {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[date.month - 1]} ${date.day}';
  }
}
