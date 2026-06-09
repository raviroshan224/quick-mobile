enum CashMovementType { cashIn, cashOut }

class CashMovement {
  final String id;
  final CashMovementType type;
  final double amount;
  final String reason;
  final DateTime createdAt;

  const CashMovement({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
  });

  factory CashMovement.fromJson(Map<String, dynamic> j) => CashMovement(
        id: j['id'] as String,
        type: j['type'] == 'IN' ? CashMovementType.cashIn : CashMovementType.cashOut,
        amount: (j['amount'] as num).toDouble(),
        reason: j['reason'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}

class CashDrawer {
  final String id;
  final double openBalance;
  final double? closeBalance;
  final double? expectedBalance;
  final double? difference;
  final bool isOpen;
  final DateTime openedAt;
  final DateTime? closedAt;
  final List<CashMovement> movements;

  const CashDrawer({
    required this.id,
    required this.openBalance,
    this.closeBalance,
    this.expectedBalance,
    this.difference,
    required this.isOpen,
    required this.openedAt,
    this.closedAt,
    this.movements = const [],
  });

  factory CashDrawer.fromJson(Map<String, dynamic> j) => CashDrawer(
        id: j['id'] as String,
        openBalance: (j['openBalance'] as num).toDouble(),
        closeBalance: (j['closeBalance'] as num?)?.toDouble(),
        expectedBalance: (j['expectedBalance'] as num?)?.toDouble(),
        difference: (j['difference'] as num?)?.toDouble(),
        isOpen: j['closedAt'] == null,
        openedAt: DateTime.parse(j['openedAt'] as String),
        closedAt: j['closedAt'] != null ? DateTime.parse(j['closedAt'] as String) : null,
        movements: (j['movements'] as List? ?? []).map((e) => CashMovement.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
