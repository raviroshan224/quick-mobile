import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../../pos/domain/pos_models.dart';
import '../domain/transaction_models.dart';

class TransactionsRepository {
  TransactionsRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> checkout({
    required CartState cart,
    required PaymentMethod paymentMethod,
    double? splitCash,
    double? splitFonepay,
    String? discountId,
    double? keypadAmount,
  }) async {
    final List<Map<String, dynamic>> items;
    if (cart.items.isEmpty && keypadAmount != null && keypadAmount > 0) {
      // Keypad-only checkout: no service selected, just a custom amount.
      items = [{'quantity': 1, 'unitPrice': keypadAmount}];
    } else {
      items = cart.items
          .map((i) => {
                if (i.service != null) 'serviceId': i.service!.id,
                if (i.product != null) 'productId': i.product!.id,
                if (i.assignedStaff != null) 'staffId': i.assignedStaff!.id,
                'quantity': i.quantity,
                'unitPrice': i.unitPrice,
              })
          .toList();
    }

    final body = <String, dynamic>{
      'items': items,
      'paymentMethod': _methodToString(paymentMethod),
      'isGuest': cart.isGuest || cart.customer == null,
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
      if (cart.notes != null) 'notes': cart.notes,
      if (paymentMethod == PaymentMethod.split && splitCash != null)
        'splitCash': splitCash,
      if (paymentMethod == PaymentMethod.split && splitFonepay != null)
        'splitFonepay': splitFonepay,
    };

    return await _api.post('/transactions', data: body) as Map<String, dynamic>;
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

  Future<Transaction> refund(
    String id, {
    required double amount,
    required String reason,
  }) async {
    final data = await _api.post(
      '/transactions/$id/refund',
      data: {'amount': amount, 'reason': reason},
    ) as Map<String, dynamic>;
    return Transaction.fromJson(data);
  }

  Future<Map<String, dynamic>> getReceipt(String id) async {
    return await _api.get('/transactions/$id/receipt') as Map<String, dynamic>;
  }

  Future<void> emailReceipt(String transactionId, {String? email}) async {
    await _api.post('/transactions/$transactionId/receipt/email', data: {
      'email': ?email,
    });
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
