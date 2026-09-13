import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/inventory_models.dart';

class InventoryRepository {
  InventoryRepository(this._api);
  final ApiClient _api;

  Future<List<ProductModel>> getProducts({bool? lowStock}) async {
    final data = await _api.get('/products', queryParameters: {
      'limit': 100,
      'isActive': true,
      if (lowStock == true) 'lowStock': true,
    }) as Map<String, dynamic>;
    return PaginatedResponse.fromJson(data, ProductModel.fromJson).data;
  }

  Future<ProductModel> getById(String id) async {
    final data = await _api.get('/products/$id') as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> create({
    required String name,
    required double price,
    required int stock,
    double? cost,
    String? sku,
    String? description,
    String? category,
    int lowStockThreshold = 5,
    bool isActive = true,
  }) async {
    final data = await _api.post('/products', data: {
      'name': name,
      'price': price,
      'stock': stock,
      'cost': ?cost,
      'sku': ?sku,
      'description': ?description,
      'category': ?category,
      'lowStockThreshold': lowStockThreshold,
      'isActive': isActive,
    }) as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<ProductModel> update(String id, {
    String? name,
    double? price,
    int? stock,
    double? cost,
    String? sku,
    String? description,
    String? category,
    int? lowStockThreshold,
    bool? isActive,
  }) async {
    final data = await _api.patch('/products/$id', data: {
      'name': ?name,
      'price': ?price,
      'stock': ?stock,
      // Sent as an explicit key even when null (not omitted) — the only
      // caller (item_form_screen._save) always submits the form's full
      // current state, so a field the user cleared must actually clear on
      // the backend rather than silently keeping its old value (an omitted
      // key means "leave unchanged" in this PATCH).
      'cost': cost,
      'sku': sku,
      'description': description,
      'category': category,
      'lowStockThreshold': ?lowStockThreshold,
      'isActive': ?isActive,
    }) as Map<String, dynamic>;
    return ProductModel.fromJson(data);
  }

  Future<void> delete(String id) => _api.delete('/products/$id');

  Future<List<ProductModel>> searchProducts(String query) async {
    final data = await _api.get('/products', queryParameters: {
      'search': query,
      'limit': 10,
      'isActive': true,
    }) as Map<String, dynamic>;
    return PaginatedResponse.fromJson(data, ProductModel.fromJson).data;
  }

  Future<void> recordMovement({
    required String productId,
    required InventoryMovementType type,
    required int quantity,
    required String reason,
  }) async {
    await _api.post('/inventory/movement', data: {
      'productId': productId,
      'type': _movementTypeToString(type),
      'quantity': quantity,
      'reason': reason,
    });
  }

  Future<List<InventoryLogEntry>> getLogs({int page = 1, int limit = 50}) async {
    final data = await _api.get('/inventory/logs', queryParameters: {
      'page': page,
      'limit': limit,
    }) as Map<String, dynamic>;
    return PaginatedResponse.fromJson(data, _logFromJson).data;
  }

  Future<({List<InventoryLogEntry> items, bool hasMore})> getLogsPaginated({
    int page = 1,
    int limit = 20,
    InventoryMovementType? type,
  }) async {
    final data = await _api.get('/inventory/logs', queryParameters: {
      'page': page,
      'limit': limit,
      if (type != null) 'type': _movementTypeToString(type),
    }) as Map<String, dynamic>;
    final response = PaginatedResponse.fromJson(data, _logFromJson);
    return (
      items: response.data,
      hasMore: response.meta.page < response.meta.totalPages,
    );
  }

  String _movementTypeToString(InventoryMovementType t) => switch (t) {
        InventoryMovementType.stockIn => 'STOCK_IN',
        InventoryMovementType.stockOut => 'STOCK_OUT',
        InventoryMovementType.adjustment => 'ADJUSTMENT',
      };

  static InventoryLogEntry _logFromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>?;
    final createdBy = j['createdBy'] as Map<String, dynamic>?;
    final typeStr = j['type'] as String? ?? 'ADJUSTMENT';
    final type = switch (typeStr) {
      'STOCK_IN' => InventoryMovementType.stockIn,
      'STOCK_OUT' => InventoryMovementType.stockOut,
      _ => InventoryMovementType.adjustment,
    };
    final firstName = createdBy?['firstName'] as String? ?? '';
    final lastName = createdBy?['lastName'] as String? ?? '';
    final byName = '$firstName $lastName'.trim();
    return InventoryLogEntry(
      id: j['id'] as String,
      productId: j['productId'] as String? ?? '',
      productName: product?['name'] as String? ?? '',
      type: type,
      quantity: j['quantity'] as int? ?? 0,
      reason: j['reason'] as String? ?? '',
      stockBefore: j['stockBefore'] as int? ?? 0,
      stockAfter: j['stockAfter'] as int? ?? 0,
      createdAt: DateTime.parse(j['createdAt'] as String),
      createdByName: byName.isEmpty ? null : byName,
    );
  }
}
