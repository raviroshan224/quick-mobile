/// A single line item on a printed receipt.
class ReceiptLineItem {
  const ReceiptLineItem({
    required this.name,
    required this.quantity,
    required this.totalPrice,
  });

  final String name;
  final int quantity;
  final double totalPrice;
}

/// Everything needed to print a receipt — plain data, no ESC/POS/formatting
/// knowledge. [CashDrawerService.printReceipt] is the only place that turns
/// this into printer bytes, keeping the third-party package fully contained
/// there.
class ReceiptData {
  const ReceiptData({
    required this.salonName,
    required this.address,
    required this.phone,
    required this.currency,
    required this.footer,
    required this.items,
    required this.total,
    required this.paymentMethodLabel,
    required this.dateTime,
    this.subtotal,
    this.discountAmount = 0,
    this.tax = 0,
    this.tip = 0,
    this.manualAdjustment = 0,
    this.change,
    this.customerName,
    this.staffName,
    this.transactionId,
  });

  final String salonName;
  final String address;
  final String phone;
  final String currency;
  final String footer;

  /// Empty for a keypad-only custom-amount sale, which has no line-item
  /// breakdown — the receipt then prints just the total.
  final List<ReceiptLineItem> items;

  /// Null alongside an empty [items] list (custom-amount sale).
  final double? subtotal;
  final double discountAmount;
  final double tax;
  final double tip;
  final double manualAdjustment;
  final double total;

  final String paymentMethodLabel;
  final double? change;
  final String? customerName;
  final String? staffName;

  /// Backend transaction id, printed as the receipt number when available.
  final String? transactionId;
  final DateTime dateTime;
}
