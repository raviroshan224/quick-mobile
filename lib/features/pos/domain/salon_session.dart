import 'pos_models.dart' show StaffMember;

enum SalonSessionStatus { waiting, inProgress }

extension SalonSessionStatusExt on SalonSessionStatus {
  String get label => switch (this) {
        SalonSessionStatus.waiting => 'Waiting',
        SalonSessionStatus.inProgress => 'In Progress',
      };
}

/// One customer's independent, concurrently-open till on the shared
/// reception tablet. A salon serves several customers with different staff
/// at once — unlike a restaurant's single-ticket-at-a-time model — so each
/// session must be able to exist, be edited, and be checked out completely
/// independently of every other open session.
///
/// A session's actual cart contents (items, customer, discount, tip, ...)
/// are NOT stored as a field here — they live in `cartProvider(session.id)`
/// (see cart_provider.dart), which is a family-scoped provider keyed by
/// this session's id. This keeps the entire existing CartNotifier/CartState
/// implementation completely unchanged and reused as-is; SalonSession only
/// carries the session-level metadata that doesn't already belong to a cart.
class SalonSession {
  const SalonSession({
    required this.id,
    required this.number,
    this.label,
    this.primaryStaff,
    this.status = SalonSessionStatus.inProgress,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  // Auto-incrementing, cosmetic display counter ("Session 101") — purely
  // local, never sent to the backend.
  final int number;
  // Optional custom name overriding the default "Session ###" display.
  final String? label;
  final StaffMember? primaryStaff;
  final SalonSessionStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  String get displayName =>
      (label?.isNotEmpty ?? false) ? label! : 'Session $number';

  SalonSession copyWith({
    String? label,
    StaffMember? primaryStaff,
    SalonSessionStatus? status,
    DateTime? updatedAt,
    bool clearPrimaryStaff = false,
    bool clearLabel = false,
  }) =>
      SalonSession(
        id: id,
        number: number,
        label: clearLabel ? null : (label ?? this.label),
        primaryStaff:
            clearPrimaryStaff ? null : (primaryStaff ?? this.primaryStaff),
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'number': number,
        'label': label,
        'primaryStaffId': primaryStaff?.id,
        'primaryStaffFirstName': primaryStaff?.firstName,
        'primaryStaffLastName': primaryStaff?.lastName,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'updatedAt': updatedAt.toIso8601String(),
      };

  // Reconstructs a session from local storage. The primary staff is
  // rehydrated as a minimal StaffModel stub (id + name only, no phone/
  // specialties/etc.) — enough for display and for re-sending staffId at
  // checkout; a full record isn't needed since the real one is always
  // fetched fresh from the staff list when actually assigning staff.
  factory SalonSession.fromJson(Map<String, dynamic> j) => SalonSession(
        id: j['id'] as String,
        number: j['number'] as int,
        label: j['label'] as String?,
        primaryStaff: j['primaryStaffId'] == null
            ? null
            : StaffMember(
                id: j['primaryStaffId'] as String,
                userId: '',
                firstName: j['primaryStaffFirstName'] as String? ?? '',
                lastName: j['primaryStaffLastName'] as String? ?? '',
              ),
        status: SalonSessionStatus.values.firstWhere(
          (s) => s.name == j['status'],
          orElse: () => SalonSessionStatus.inProgress,
        ),
        createdAt: DateTime.parse(j['createdAt'] as String),
        updatedAt: DateTime.parse(j['updatedAt'] as String),
      );
}
