import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/service_models.dart';

class ServicesRepository {
  ServicesRepository(this._api);
  final ApiClient _api;

  Future<List<ServiceCategory>> getCategories() async {
    final data = await _api.get('/services/categories') as List<dynamic>;
    return data
        .map((j) => ServiceCategory.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceCategory> createCategory(String name) async {
    final data = await _api.post('/services/categories', data: {'name': name})
        as Map<String, dynamic>;
    return ServiceCategory.fromJson(data);
  }

  Future<List<ServiceModel>> getServices({String? categoryId, bool? isActive = true}) async {
    final data = await _api.get('/services', queryParameters: {
      'limit': 100,
      'isActive': ?isActive,
      'categoryId': ?categoryId,
    }) as Map<String, dynamic>;
    return PaginatedResponse.fromJson(data, ServiceModel.fromJson).data;
  }

  Future<ServiceModel> getById(String id) async {
    final data = await _api.get('/services/$id') as Map<String, dynamic>;
    return ServiceModel.fromJson(data);
  }

  Future<ServiceModel> create({
    required String name,
    required double price,
    required int duration,
    String? description,
    String? categoryId,
    bool isActive = true,
  }) async {
    final data = await _api.post('/services', data: {
      'name': name,
      'price': price,
      'duration': duration,
      'description': ?description,
      'categoryId': ?categoryId,
      'isActive': isActive,
    }) as Map<String, dynamic>;
    return ServiceModel.fromJson(data);
  }

  Future<ServiceModel> update(
    String id, {
    String? name,
    double? price,
    int? duration,
    String? description,
    String? categoryId,
    bool? isActive,
  }) async {
    final data = await _api.patch('/services/$id', data: {
      'name': ?name,
      'price': ?price,
      'duration': ?duration,
      'description': ?description,
      'categoryId': ?categoryId,
      'isActive': ?isActive,
    }) as Map<String, dynamic>;
    return ServiceModel.fromJson(data);
  }

  Future<void> delete(String id) => _api.delete('/services/$id');
}
