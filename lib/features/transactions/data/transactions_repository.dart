import 'package:uuid/uuid.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../../pos/domain/pos_models.dart';
import '../domain/transaction_models.dart';

const _uuid = Uuid();

/// Authoritative cart total from the backend — the exact amount `checkout()`
/// will charge, including tax the client has no way to compute itself. See
/// [TransactionsRepository.quote].
class CartQuote {
  const CartQuote({
    required this.subtotal,
    required this.discountAmount,
    required this.totalTax,
    required this.tipAmount,
    required this.manualAdjustment,
    required this.finalPayableAmount,
    required this.total,
  });

  factory CartQuote.fromJson(Map<String, dynamic> json) => CartQuote(
        subtotal: (json['subtotal'] as num).toDouble(),
        discountAmount: (json['discountAmount'] as num).toDouble(),
        totalTax: (json['totalTax'] as num).toDouble(),
        tipAmount: (json['tipAmount'] as num).toDouble(),
        // Server-computed — the client never derives this itself. See
        // TransactionsService.priceCart() on the backend.
        manualAdjustment: (json['manualAdjustment'] as num?)?.toDouble() ?? 0,
        finalPayableAmount: (json['finalPayableAmount'] as num?)?.toDouble(),
        total: (json['total'] as num).toDouble(),
      );

  final double subtotal;
  final double discountAmount;
  final double totalTax;
  final double tipAmount;
  final double manualAdjustment;
  final double? finalPayableAmount;
  final double total;
}

class TransactionsRepository {
  TransactionsRepository(this._api);
  final ApiClient _api;

  // Shared by checkout() and quote() so a quote is always priced from
  // exactly the same item/discount payload checkout() would actually send.
  List<Map<String, dynamic>> _itemsFor(CartState cart, double? keypadAmount) {
    if (cart.items.isEmpty && keypadAmount != null && keypadAmount > 0) {
      // Keypad-only checkout: no service selected, just a custom amount.
      return [{'quantity': 1, 'unitPrice': keypadAmount}];
    }
    return cart.items
        .map((i) => {
              if (i.service != null) 'serviceId': i.service!.id,
              if (i.product != null) 'productId': i.product!.id,
              if (i.assignedStaff != null) 'staffId': i.assignedStaff!.id,
              'quantity': i.quantity,
              'unitPrice': i.unitPrice,
            })
        .toList();
  }

  /// Quotes the cart's authoritative subtotal/discount/tax/total from the
  /// server — the same pricing code checkout() charges from — so the amount
  /// shown to the cashier before payment (which the client alone cannot
  /// compute, since it has no visibility into tax rates) matches what's
  /// actually collected.
  Future<CartQuote> quote({
    required CartState cart,
    String? discountId,
    double? keypadAmount,
  }) async {
    final body = <String, dynamic>{
      'items': _itemsFor(cart, keypadAmount),
      'discountId': ?discountId,
      if (cart.discount != null && discountId == null) ...{
        'manualDiscountType':
            cart.discount!.isPercentage ? 'PERCENTAGE' : 'FIXED',
        'manualDiscountValue': cart.discount!.amount,
      },
      if (cart.tipAmount > 0) 'tipAmount': cart.tipAmount,
      // Salon checkout: only the raw amount the cashier typed is sent — the
      // backend derives manualAdjustment against its own authoritative
      // subtotal (TransactionsService.priceCart()). Never computed here.
      if (cart.finalPayable != null) 'finalPayableAmount': cart.finalPayable,
    };
    final data = await _api.post('/transactions/quote', data: body) as Map<String, dynamic>;
    return CartQuote.fromJson(data);
  }

  Future<Map<String, dynamic>> checkout({
    required CartState cart,
    required PaymentMethod paymentMethod,
    double? splitCash,
    double? splitFonepay,
    String? discountId,
    double? keypadAmount,
    // The salon session's primary staff — sent as the transaction-level
    // staffId so revenue/commission attribute to whoever actually served
    // the customer, not whoever happens to be logged into the shared
    // reception tablet (the backend auto-attributes to the logged-in user
    // only when no staffId is provided at all — see
    // TransactionsService.create()). Line items with their own explicit
    // override (CartItem.assignedStaff, see _itemsFor above) still take
    // precedence over this for that specific line.
    String? primaryStaffId,
  }) async {
    final body = <String, dynamic>{
      'items': _itemsFor(cart, keypadAmount),
      'paymentMethod': _methodToString(paymentMethod),
      'isGuest': cart.isGuest || cart.customer == null,
      'staffId': ?primaryStaffId,
      if (cart.customer != null) 'customerId': cart.customer!.id,
      if (cart.isGuest && cart.guestName != null) 'guestName': cart.guestName,
      if (cart.isGuest && cart.guestPhone != null) 'guestPhone': cart.guestPhone,
      'discountId': ?discountId,
      if (cart.discount != null && discountId == null) ...{
        'manualDiscountType':
            cart.discount!.isPercentage ? 'PERCENTAGE' : 'FIXED',
        'manualDiscountValue': cart.discount!.amount,
      },
      if (cart.tipAmount > 0) 'tipAmount': cart.tipAmount,
      if (cart.finalPayable != null) 'finalPayableAmount': cart.finalPayable,
      if (cart.notes != null) 'notes': cart.notes,
      if (paymentMethod == PaymentMethod.split && splitCash != null)
        'splitCash': splitCash,
      if (paymentMethod == PaymentMethod.split && splitFonepay != null)
        'splitFonepay': splitFonepay,
    };

    // Stable per checkout attempt — dedupes a resubmit if Dio's
    // RetryInterceptor (or a user retry after a dropped connection) resends
    // this exact request, so a connection drop can't double-charge a sale.
    // Mirrors the same pattern already used for booking creation.
    final idempotencyKey = _uuid.v4();
    return await _api.post(
      '/transactions',
      data: body,
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Map<String, dynamic>;
  }

  /// Independently confirms a PENDING Fonepay sale — the sale is not
  /// COMPLETED, has no receipt, and doesn't count anywhere as revenue until
  /// this succeeds. [fonepayTransactionId] is the reference number the
  /// cashier reads off the actual Fonepay payment notification.
  Future<Map<String, dynamic>> verifyFonepay(
    String transactionId,
    String fonepayTransactionId,
  ) async {
    final idempotencyKey = _uuid.v4();
    return await _api.post(
      '/transactions/$transactionId/fonepay-verify',
      data: {'fonepayTransactionId': fonepayTransactionId},
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Map<String, dynamic>;
  }

  /// Best-effort cancellation of a PENDING Fonepay sale that was abandoned
  /// before payment was confirmed (cashier backed out, closed the sheet).
  /// Restores the stock committed when the pending sale was created.
  Future<void> cancelPendingFonepay(String transactionId) async {
    await _api.patch('/transactions/$transactionId/cancel');
  }

  Future<({List<Transaction> items, bool hasMore})> getAll({
    int page = 1,
    int limit = 20,
    String? status,
    String? paymentMethod,
    String? from,
    String? to,
    String? customerId,
    String? staffId,
    String? userId,
  }) async {
    final data = await _api.get('/transactions', queryParameters: {
      'page': page,
      'limit': limit,
      'status': ?status,
      'paymentMethod': ?paymentMethod,
      'dateFrom': ?from,
      'dateTo': ?to,
      'customerId': ?customerId,
      'staffId': ?staffId,
      'userId': ?userId,
    }) as Map<String, dynamic>;
    final response = PaginatedResponse.fromJson(data, Transaction.fromJson);
    return (
      items: response.data,
      hasMore: response.meta.page < response.meta.totalPages,
    );
  }

  Future<Transaction> getById(String id) async {
    final data = await _api.get('/transactions/$id') as Map<String, dynamic>;
    return Transaction.fromJson(data);
  }

  Future<Map<String, dynamic>> getReceipt(String id) async {
    return await _api.get('/transactions/$id/receipt') as Map<String, dynamic>;
  }

  Future<void> createRefund(
    String transactionId,
    CreateRefundDto dto,
  ) async {
    await _api.post('/refunds/$transactionId', data: {
      'reason': dto.reason,
      'items': dto.items
          .map((i) => {
                'transactionItemId': i.transactionItemId,
                'quantity': i.quantity,
              })
          .toList(),
    });
  }

  /// Previews a refund's tax- and discount-accurate amount without creating
  /// it — the client alone can't compute this (no visibility into per-item
  /// tax or discount proration), so this must come from the server.
  Future<double> previewRefund(
    String transactionId,
    List<({String transactionItemId, int quantity})> items,
  ) async {
    final data = await _api.post('/refunds/$transactionId/preview', data: {
      'items': items
          .map((i) => {
                'transactionItemId': i.transactionItemId,
                'quantity': i.quantity,
              })
          .toList(),
    }) as Map<String, dynamic>;
    return (data['refundAmount'] as num).toDouble();
  }

  Future<({List<RefundRecord> items, bool hasMore})> getRefundHistory({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get('/refunds', queryParameters: {
      'page': page,
      'limit': limit,
    }) as Map<String, dynamic>;
    final response = PaginatedResponse.fromJson(data, RefundRecord.fromJson);
    return (
      items: response.data,
      hasMore: response.meta.page < response.meta.totalPages,
    );
  }

  String _methodToString(PaymentMethod m) => switch (m) {
        PaymentMethod.cash => 'CASH',
        PaymentMethod.fonepay => 'FONEPAY',
        PaymentMethod.split => 'SPLIT',
      };
}
