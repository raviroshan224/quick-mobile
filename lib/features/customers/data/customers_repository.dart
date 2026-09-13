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
    String? address,
    String? notes,
  }) async {
    final data = await _api.post('/customers', data: {
      'firstName': firstName,
      'lastName': lastName,
      if (email != null && email.isNotEmpty) 'email': email,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
      if (address != null && address.isNotEmpty) 'address': address,
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
    String? address,
    String? notes,
  }) async {
    final data = await _api.patch('/customers/$id', data: {
      'firstName': ?firstName,
      'lastName': ?lastName,
      // email/phone/address/notes are sent as an explicit key even when
      // null (never omitted like firstName/lastName above) — the only
      // caller (customer_form_screen) always submits the form's full
      // current state, and a cleared field must actually clear on the
      // backend rather than silently leaving the old value in place
      // (an omitted key means "leave unchanged" in this PATCH).
      'email': email,
      'phone': phone,
      'address': address,
      'notes': notes,
    }) as Map<String, dynamic>;
    return CustomerModel.fromJson(data);
  }

  Future<void> delete(String id) => _api.delete('/customers/$id');
}
