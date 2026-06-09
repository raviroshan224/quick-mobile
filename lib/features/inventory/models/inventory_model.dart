enum InventoryMovementType { stockIn, stockOut, adjustment }

class InventoryLog {
  final String id;
  final String productId;
  final String productName;
  final InventoryMovementType type;
  final int quantity;
  final String reason;
  final int stockBefore;
  final int stockAfter;
  final DateTime createdAt;

  const InventoryLog({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.reason,
    required this.stockBefore,
    required this.stockAfter,
    required this.createdAt,
  });

  factory InventoryLog.fromJson(Map<String, dynamic> j) => InventoryLog(
        id: j['id'] as String,
        productId: j['productId'] as String,
        productName: (j['product'] as Map<String, dynamic>?)?['name'] as String? ?? '',
        type: _typeFromString(j['type'] as String),
        quantity: j['quantity'] as int,
        reason: j['reason'] as String,
        stockBefore: j['stockBefore'] as int,
        stockAfter: j['stockAfter'] as int,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  static InventoryMovementType _typeFromString(String s) => switch (s) {
        'STOCK_IN' => InventoryMovementType.stockIn,
        'STOCK_OUT' => InventoryMovementType.stockOut,
        _ => InventoryMovementType.adjustment,
      };
}
