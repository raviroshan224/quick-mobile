enum CashMovementType { cashIn, cashOut }

class CashMovementEntry {
  const CashMovementEntry({
    required this.id,
    required this.type,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.transactionId,
  });

  final String id;
  final CashMovementType type;
  final double amount;
  final String reason;
  final DateTime createdAt;
  final String? transactionId;

  bool get isIn => type == CashMovementType.cashIn;
  String get timeLabel {
    final h = createdAt.hour.toString().padLeft(2, '0');
    final m = createdAt.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }
}

class CashDrawerSession {
  const CashDrawerSession({
    required this.id,
    required this.openBalance,
    required this.openedAt,
    required this.movements,
    this.closeBalance,
    this.closedAt,
    this.notes,
  });

  final String id;
  final double openBalance;
  final DateTime openedAt;
  final List<CashMovementEntry> movements;
  final double? closeBalance;
  final DateTime? closedAt;
  final String? notes;

  bool get isOpen => closedAt == null;

  double get totalIn => movements.where((m) => m.isIn).fold(0.0, (s, m) => s + m.amount);
  double get totalOut => movements.where((m) => !m.isIn).fold(0.0, (s, m) => s + m.amount);
  double get currentBalance => openBalance + totalIn - totalOut;
  double get expectedBalance => currentBalance;
  double? get discrepancy => closeBalance != null ? closeBalance! - expectedBalance : null;
}
