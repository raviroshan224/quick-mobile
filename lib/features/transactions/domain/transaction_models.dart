enum TransactionStatus { pending, completed, partiallyRefunded, refunded, voided }

enum TxPaymentMethod { cash, fonepay, split }

class TransactionItem {
  const TransactionItem({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.serviceName,
    this.productName,
    this.staffName,
    this.refundedQty,
  });

  final String id;
  final int quantity;
  final double unitPrice;
  final double total;
  final String? serviceName;
  final String? productName;
  final String? staffName;
  final int? refundedQty;

  String get displayName => serviceName ?? productName ?? 'Item';
  int get maxRefundable => quantity - (refundedQty ?? 0);

  factory TransactionItem.fromJson(Map<String, dynamic> j) {
    final service = j['service'] as Map<String, dynamic>?;
    final product = j['product'] as Map<String, dynamic>?;
    final staff = j['staff'] as Map<String, dynamic>?;
    final firstName = staff?['firstName'] as String? ?? '';
    final lastName = staff?['lastName'] as String? ?? '';
    final staffName = '$firstName $lastName'.trim();
    return TransactionItem(
      id: j['id'] as String,
      quantity: j['quantity'] as int? ?? 1,
      unitPrice: (j['unitPrice'] as num).toDouble(),
      total: (j['total'] as num).toDouble(),
      serviceName: service?['name'] as String?,
      productName: product?['name'] as String?,
      staffName: staffName.isEmpty ? null : staffName,
      refundedQty: j['refundedQty'] as int?,
    );
  }
}

// ─── Refund models ────────────────────────────────────────────────────────────

class CreateRefundDto {
  const CreateRefundDto({required this.reason, required this.items});
  final String reason;
  final List<({String transactionItemId, int quantity})> items;
}

class RefundedItem {
  const RefundedItem({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    this.displayName,
  });

  final String id;
  final int quantity;
  final double unitPrice;
  final String? displayName;

  factory RefundedItem.fromJson(Map<String, dynamic> j) {
    final item = j['transactionItem'] as Map<String, dynamic>?;
    final service = item?['service'] as Map<String, dynamic>?;
    final product = item?['product'] as Map<String, dynamic>?;
    final name = service?['name'] as String? ?? product?['name'] as String?;
    return RefundedItem(
      id: j['id'] as String,
      quantity: j['quantity'] as int? ?? 0,
      unitPrice: (j['unitPrice'] as num?)?.toDouble() ?? 0,
      displayName: name,
    );
  }
}

class RefundRecord {
  const RefundRecord({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.reason,
    required this.createdAt,
    this.receiptNumber,
    this.customerName,
    this.processedByName,
    this.items,
  });

  final String id;
  final String transactionId;
  final double amount;
  final String reason;
  final DateTime createdAt;
  final String? receiptNumber;
  final String? customerName;
  final String? processedByName;
  final List<RefundedItem>? items;

  factory RefundRecord.fromJson(Map<String, dynamic> j) {
    final transaction = j['transaction'] as Map<String, dynamic>?;
    final customer = transaction?['customer'] as Map<String, dynamic>?;
    final processedBy = j['processedBy'] as Map<String, dynamic>?;
    final firstName = customer?['firstName'] as String? ?? '';
    final lastName = customer?['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    final pFirst = processedBy?['firstName'] as String? ?? '';
    final pLast = processedBy?['lastName'] as String? ?? '';
    final byName = '$pFirst $pLast'.trim();
    final itemsJson = j['items'] as List<dynamic>?;
    return RefundRecord(
      id: j['id'] as String,
      transactionId:
          j['transactionId'] as String? ?? transaction?['id'] as String? ?? '',
      amount: (j['amount'] as num).toDouble(),
      reason: j['reason'] as String? ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String),
      receiptNumber: transaction?['receiptNumber'] as String?,
      customerName: fullName.isNotEmpty
          ? fullName
          : transaction?['guestName'] as String?,
      processedByName: byName.isEmpty ? null : byName,
      items: itemsJson
          ?.map((e) => RefundedItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class Transaction {
  const Transaction({
    required this.id,
    required this.status,
    required this.paymentMethod,
    required this.total,
    required this.isGuest,
    required this.createdAt,
    this.receiptNumber,
    this.subtotal,
    this.customerName,
    this.guestName,
    this.items,
    this.discountAmount,
    this.tipAmount,
    this.refundAmount,
    this.notes,
  });

  final String id;
  final String? receiptNumber;
  final TransactionStatus status;
  final TxPaymentMethod paymentMethod;
  final double? subtotal;
  final double total;
  final bool isGuest;
  final DateTime createdAt;
  final String? customerName;
  final String? guestName;
  final List<TransactionItem>? items;
  final double? discountAmount;
  final double? tipAmount;
  final double? refundAmount;
  final String? notes;

  String get displayName {
    if (!isGuest && customerName != null && customerName!.trim().isNotEmpty) {
      return customerName!.trim();
    }
    if (guestName != null && guestName!.trim().isNotEmpty) return guestName!.trim();
    return 'Walk-in';
  }

  String get displayId {
    if (receiptNumber != null) return receiptNumber!;
    final short = id.length > 8 ? id.substring(0, 8) : id;
    return '#${short.toUpperCase()}';
  }

  bool get isRefundable =>
      status == TransactionStatus.completed ||
      status == TransactionStatus.partiallyRefunded;

  factory Transaction.fromJson(Map<String, dynamic> j) {
    final customer = j['customer'] as Map<String, dynamic>?;
    final statusStr = j['status'] as String? ?? 'PENDING';
    final methodStr = j['paymentMethod'] as String? ?? 'CASH';
    final itemsJson = j['items'] as List<dynamic>?;
    final firstName = customer?['firstName'] as String? ?? '';
    final lastName = customer?['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();

    return Transaction(
      id: j['id'] as String,
      receiptNumber: j['receiptNumber'] as String?,
      status: _parseStatus(statusStr),
      paymentMethod: _parseMethod(methodStr),
      subtotal: (j['subtotal'] as num?)?.toDouble(),
      total: (j['total'] as num).toDouble(),
      isGuest: j['isGuest'] as bool? ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String),
      customerName: fullName.isEmpty ? null : fullName,
      guestName: j['guestName'] as String?,
      items: itemsJson
          ?.map((e) => TransactionItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      discountAmount: (j['discountAmount'] as num?)?.toDouble(),
      tipAmount: (j['tipAmount'] as num?)?.toDouble(),
      refundAmount: (j['refundAmount'] as num?)?.toDouble(),
      notes: j['notes'] as String?,
    );
  }

  static TransactionStatus _parseStatus(String s) => switch (s) {
        'COMPLETED' => TransactionStatus.completed,
        'PARTIALLY_REFUNDED' => TransactionStatus.partiallyRefunded,
        'REFUNDED' => TransactionStatus.refunded,
        'VOIDED' => TransactionStatus.voided,
        _ => TransactionStatus.pending,
      };

  static TxPaymentMethod _parseMethod(String s) => switch (s) {
        'FONEPAY' => TxPaymentMethod.fonepay,
        'SPLIT' => TxPaymentMethod.split,
        _ => TxPaymentMethod.cash,
      };
}
