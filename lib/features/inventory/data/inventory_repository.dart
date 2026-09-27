import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/inventory_models.dart';

class InventoryRepository {
  InventoryRepository(this._api);
  final ApiClient _api;

  /// Every active product. The API pages at most 100 at a time, so this
  /// fetches page 1, then the remaining pages a few at a time — a pharmacy
  /// can easily stock thousands of items, and checkout search, category
  /// chips and barcode lookup all work on this full list.
  Future<List<ProductModel>> getProducts({bool? lowStock}) async {
    Future<PaginatedResponse<ProductModel>> page(int n) async {
      final data = await _api.get('/products', queryParameters: {
        'page': n,
        'limit': _pageSize,
        'isActive': true,
        if (lowStock == true) 'lowStock': true,
      }) as Map<String, dynamic>;
      return PaginatedResponse.fromJson(data, ProductModel.fromJson);
    }

    final first = await page(1);
    final products = [...first.data];
    final lastPage = first.meta.totalPages.clamp(1, _maxPages);
    for (var start = 2; start <= lastPage; start += _parallelPages) {
      final end = (start + _parallelPages - 1).clamp(start, lastPage);
      final pages = await Future.wait(
          [for (var n = start; n <= end; n++) page(n)]);
      for (final p in pages) {
        products.addAll(p.data);
      }
    }
    return products;
  }

  static const _pageSize = 100;
  static const _parallelPages = 4;
  // 10,000 products — a safety cap, well above any single shop's catalogue.
  static const _maxPages = 100;

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
    String? barcode,
    String? genericName,
    String? manufacturer,
    String? strength,
    String? dosageForm,
    bool requiresPrescription = false,
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
      'barcode': ?barcode,
      'genericName': ?genericName,
      'manufacturer': ?manufacturer,
      'strength': ?strength,
      'dosageForm': ?dosageForm,
      'requiresPrescription': requiresPrescription,
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
    String? barcode,
    String? genericName,
    String? manufacturer,
    String? strength,
    String? dosageForm,
    bool? requiresPrescription,
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
      'barcode': barcode,
      'genericName': genericName,
      'manufacturer': manufacturer,
      'strength': strength,
      'dosageForm': dosageForm,
      'lowStockThreshold': ?lowStockThreshold,
      'isActive': ?isActive,
      'requiresPrescription': ?requiresPrescription,
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

  /// The active product with this scanned [code] (barcode, or SKU for older
  /// products), or null if there is none.
  Future<ProductModel?> findByCode(String code) async {
    final byBarcode = await _api.get('/products', queryParameters: {
      'barcode': code,
      'limit': 1,
      'isActive': true,
    }) as Map<String, dynamic>;
    final hit = PaginatedResponse.fromJson(byBarcode, ProductModel.fromJson).data;
    if (hit.isNotEmpty) return hit.first;
    // Search matches substrings, so keep only an exact SKU/barcode match.
    return (await searchProducts(code)).where((p) => p.matchesCode(code)).firstOrNull;
  }

  Future<void> recordMovement({
    required String productId,
    required InventoryMovementType type,
    required int quantity,
    required String reason,
    String? batchNumber,
    DateTime? expiryDate,
    String? batchId,
  }) async {
    await _api.post('/inventory/movement', data: {
      'productId': productId,
      'type': _movementTypeToString(type),
      'quantity': quantity,
      'reason': reason,
      'batchNumber': ?batchNumber,
      if (expiryDate != null) 'expiryDate': formatApiDate(expiryDate),
      'batchId': ?batchId,
    });
  }

  /// A product's batches that still hold stock, soonest expiry first.
  Future<List<ProductBatch>> getBatches(String productId) async {
    final data =
        await _api.get('/inventory/products/$productId/batches') as List<dynamic>;
    return data
        .map((e) => ProductBatch.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Batches expired or expiring within [days] days, soonest first.
  Future<List<ProductBatch>> getExpiring({int days = 90}) async {
    final data = await _api.get('/inventory/expiring',
        queryParameters: {'days': days}) as List<dynamic>;
    return data
        .map((e) => ProductBatch.fromJson(e as Map<String, dynamic>))
        .toList();
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
