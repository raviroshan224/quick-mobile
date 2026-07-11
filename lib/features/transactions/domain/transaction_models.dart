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
    // The backend stores serviceName/productName/staffName as immutable
    // snapshot columns on the transaction item itself (so historical
    // receipts don't change if a service/staff record is later renamed).
    // Fall back to the nested service/product/staff relation objects in
    // case a caller ever includes those instead.
    final service = j['service'] as Map<String, dynamic>?;
    final product = j['product'] as Map<String, dynamic>?;
    final staff = j['staff'] as Map<String, dynamic>?;
    final nestedFirstName = staff?['firstName'] as String? ?? '';
    final nestedLastName = staff?['lastName'] as String? ?? '';
    final nestedStaffName = '$nestedFirstName $nestedLastName'.trim();

    final staffName = (j['staffName'] as String?)?.trim();
    return TransactionItem(
      id: j['id'] as String,
      quantity: j['quantity'] as int? ?? 1,
      unitPrice: (j['unitPrice'] as num? ?? j['price'] as num? ?? 0).toDouble(),
      total: (j['totalPrice'] as num? ?? j['total'] as num? ?? 0).toDouble(),
      serviceName: j['serviceName'] as String? ?? service?['name'] as String?,
      productName: j['productName'] as String? ?? product?['name'] as String?,
      staffName: (staffName != null && staffName.isNotEmpty)
          ? staffName
          : (nestedStaffName.isEmpty ? null : nestedStaffName),
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
    // transactionItem carries serviceName/productName as flat snapshot
    // columns (see TransactionItem.fromJson) — read those first and only
    // fall back to nested service/product relation objects if present.
    final item = j['transactionItem'] as Map<String, dynamic>?;
    final service = item?['service'] as Map<String, dynamic>?;
    final product = item?['product'] as Map<String, dynamic>?;
    final name = item?['serviceName'] as String? ??
        item?['productName'] as String? ??
        service?['name'] as String? ??
        product?['name'] as String?;
    final quantity = j['quantity'] as int? ?? 0;
    // RefundItem has no unitPrice column — only `amount` (the refund total
    // for this line). Derive a per-unit price so existing unitPrice*quantity
    // display math still reconstructs the correct line total.
    final amount = (j['amount'] as num?)?.toDouble() ?? 0;
    return RefundedItem(
      id: j['id'] as String,
      quantity: quantity,
      unitPrice: quantity > 0 ? amount / quantity : amount,
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
      amount: (j['amount'] as num? ?? 0).toDouble(),
      reason: j['reason'] as String? ?? '',
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
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
    this.staffName,
    this.processedByName,
    this.processedByIsOwner = false,
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
  // Staff member who processed the sale (Transaction.staff on the backend).
  // Null when the OWNER checked out personally (owners have no Staff row) —
  // [processedByName] always has a value in that case instead.
  final String? staffName;
  // The account that processed the sale (Transaction.user on the backend) —
  // always present, unlike [staffName]. Used as a fallback so every
  // transaction can show who handled it, owner or staff.
  final String? processedByName;
  final bool processedByIsOwner;

  String get displayName {
    if (!isGuest && customerName != null && customerName!.trim().isNotEmpty) {
      return customerName!.trim();
    }
    if (guestName != null && guestName!.trim().isNotEmpty) return guestName!.trim();
    return 'Walk-in';
  }

  // Who actually processed the sale — the staff snapshot if one exists,
  // otherwise the processing account (which covers owner-self-checkouts).
  String? get processedByDisplayName {
    if (staffName != null) return staffName;
    if (processedByName == null) return null;
    return processedByIsOwner ? '$processedByName (Owner)' : processedByName;
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

    // Staff who processed the sale — backend includes it as staff.user.
    final staff = j['staff'] as Map<String, dynamic>?;
    final staffUser = staff?['user'] as Map<String, dynamic>?;
    final staffFirst = staffUser?['firstName'] as String? ?? '';
    final staffLast = staffUser?['lastName'] as String? ?? '';
    final staffFullName = '$staffFirst $staffLast'.trim();

    // The account that actually processed the sale — always present, unlike
    // `staff` which is null for owner-self-checkouts (owners have no Staff
    // row). Used as a fallback so every transaction shows who handled it.
    final processedBy = j['user'] as Map<String, dynamic>?;
    final processedByFirst = processedBy?['firstName'] as String? ?? '';
    final processedByLast = processedBy?['lastName'] as String? ?? '';
    final processedByFullName = '$processedByFirst $processedByLast'.trim();

    return Transaction(
      id: j['id'] as String,
      receiptNumber: j['receiptNumber'] as String?,
      status: _parseStatus(statusStr),
      paymentMethod: _parseMethod(methodStr),
      subtotal: (j['subtotal'] as num?)?.toDouble(),
      total: (j['total'] as num? ?? 0).toDouble(),
      isGuest: j['isGuest'] as bool? ?? false,
      createdAt: DateTime.parse(j['createdAt'] as String).toLocal(),
      customerName: fullName.isEmpty ? null : fullName,
      guestName: j['guestName'] as String?,
      staffName: staffFullName.isEmpty ? null : staffFullName,
      processedByName:
          processedByFullName.isEmpty ? null : processedByFullName,
      processedByIsOwner: processedBy?['role'] == 'OWNER',
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
