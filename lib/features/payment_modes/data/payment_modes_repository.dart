import '../../../core/network/api_client.dart';
import '../models/payment_mode_model.dart';

class PaymentModesRepository {
  PaymentModesRepository(this._api);
  final ApiClient _api;

  Future<List<PaymentMode>> getAll({bool includeInactive = false}) async {
    final data = await _api.get('/payment-modes', queryParameters: {
      if (includeInactive) 'includeInactive': 'true',
    });
    return (data as List)
        .map((e) => PaymentMode.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PaymentMode> create({
    required String name,
    required String qrImageUrl,
  }) async {
    final data = await _api.post('/payment-modes', data: {
      'name': name,
      'qrImageUrl': qrImageUrl,
    }) as Map<String, dynamic>;
    return PaymentMode.fromJson(data);
  }

  Future<PaymentMode> update(
    String id, {
    String? name,
    String? qrImageUrl,
    bool? isActive,
  }) async {
    final data = await _api.patch('/payment-modes/$id', data: {
      'name': ?name,
      'qrImageUrl': ?qrImageUrl,
      'isActive': ?isActive,
    }) as Map<String, dynamic>;
    return PaymentMode.fromJson(data);
  }

  Future<void> delete(String id) => _api.delete('/payment-modes/$id');
}
