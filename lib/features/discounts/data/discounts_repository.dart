import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../models/discount_model.dart';

class DiscountsRepository {
  DiscountsRepository(this._api);
  final ApiClient _api;

  Future<List<Discount>> getAll() async {
    final data = await _api.get('/discounts', queryParameters: {'limit': 100}) as Map<String, dynamic>;
    return PaginatedResponse.fromJson(data, _fromJson).data;
  }

  Future<Discount?> findByCode(String code) async {
    try {
      final data = await _api.get('/discounts/code/$code') as Map<String, dynamic>;
      return _fromJson(data);
    } catch (_) {
      return null;
    }
  }

  Future<Discount> create({
    required String name,
    required DiscountType type,
    required double value,
    bool isActive = true,
    String? code,
    DiscountScope scope = DiscountScope.all,
    String? serviceId,
  }) async {
    final data = await _api.post('/discounts', data: {
      'name': name,
      'type': type == DiscountType.percentage ? 'PERCENTAGE' : 'FIXED',
      'value': value,
      'isActive': isActive,
      if (code != null && code.isNotEmpty) 'code': code,
      'scope': scope == DiscountScope.service ? 'SERVICE' : 'ALL',
      if (scope == DiscountScope.service) 'serviceId': serviceId,
    }) as Map<String, dynamic>;
    return _fromJson(data);
  }

  Future<Discount> update(
    String id, {
    String? name,
    DiscountType? type,
    double? value,
    bool? isActive,
    DiscountScope? scope,
    String? serviceId,
  }) async {
    final data = await _api.patch('/discounts/$id', data: {
      'name': ?name,
      if (type != null) 'type': type == DiscountType.percentage ? 'PERCENTAGE' : 'FIXED',
      'value': ?value,
      'isActive': ?isActive,
      if (scope != null) 'scope': scope == DiscountScope.service ? 'SERVICE' : 'ALL',
      if (scope == DiscountScope.service) 'serviceId': serviceId,
    }) as Map<String, dynamic>;
    return _fromJson(data);
  }

  Future<void> delete(String id) => _api.delete('/discounts/$id');

  static Discount _fromJson(Map<String, dynamic> j) {
    final service = j['service'] as Map<String, dynamic>?;
    return Discount(
      id: j['id'] as String,
      name: j['name'] as String,
      type: (j['type'] as String?) == 'PERCENTAGE'
          ? DiscountType.percentage
          : DiscountType.fixed,
      value: (j['value'] as num).toDouble(),
      isActive: j['isActive'] as bool? ?? true,
      scope: (j['scope'] as String?) == 'SERVICE'
          ? DiscountScope.service
          : DiscountScope.all,
      serviceId: j['serviceId'] as String?,
      serviceName: service?['name'] as String?,
    );
  }
}
