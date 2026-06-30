import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/service_models.dart';

class ServicesRepository {
  ServicesRepository(this._api);
  final ApiClient _api;

  Future<List<ServiceCategory>> getCategories() async {
    final data = await _api.get(
      '/services',
      queryParameters: {'limit': 100},
    ) as Map<String, dynamic>;
    final services = PaginatedResponse.fromJson(data, ServiceModel.fromJson).data;
    final seen = <String>{};
    final cats = <ServiceCategory>[];
    for (final s in services) {
      if (s.category != null && seen.add(s.category!.id)) {
        cats.add(s.category!);
      }
    }
    return cats;
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
