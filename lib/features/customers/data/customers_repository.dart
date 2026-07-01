import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/customer_models.dart';

class CustomersRepository {
  CustomersRepository(this._api);
  final ApiClient _api;

  Future<List<CustomerModel>> getAll({
    String? query,
    int page = 1,
    int limit = 100,
  }) async {
    final data = await _api.get('/customers', queryParameters: {
      'page': page,
      'limit': limit,
      if (query != null && query.isNotEmpty) 'search': query,
    }) as Map<String, dynamic>;
    return PaginatedResponse.fromJson(data, CustomerModel.fromJson).data;
  }

  Future<CustomerModel> getById(String id) async {
    final data = await _api.get('/customers/$id') as Map<String, dynamic>;
    return CustomerModel.fromJson(data);
  }

  Future<CustomerModel> create({
    required String firstName,
    required String lastName,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final data = await _api.post('/customers', data: {
      'firstName': firstName,
      'lastName': lastName,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (notes != null && notes.isNotEmpty) 'notes': notes,
    }) as Map<String, dynamic>;
    return CustomerModel.fromJson(data);
  }

  Future<CustomerModel> update(
    String id, {
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    String? notes,
  }) async {
    final data = await _api.patch('/customers/$id', data: {
      'firstName': ?firstName,
      'lastName': ?lastName,
      'email': ?email,
      'phone': ?phone,
      'notes': ?notes,
    }) as Map<String, dynamic>;
    return CustomerModel.fromJson(data);
  }

  Future<void> delete(String id) => _api.delete('/customers/$id');
}
