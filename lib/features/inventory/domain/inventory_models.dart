enum InventoryMovementType { stockIn, stockOut, adjustment }

class ProductModel {
  const ProductModel({
    required this.id,
    required this.name,
    required this.price,
    required this.stock,
    this.description,
    this.sku,
    this.cost,
    this.lowStockThreshold = 5,
    this.category,
    this.imageUrl,
    this.isActive = true,
    this.barcode,
    this.genericName,
    this.manufacturer,
    this.strength,
    this.dosageForm,
    this.requiresPrescription = false,
    this.expiredStock = 0,
    this.nextExpiry,
  });

  final String id;
  final String name;
  final double price;
  final int stock;
  final String? description;
  final String? sku;
  final double? cost;
  final int lowStockThreshold;
  final String? category;
  final String? imageUrl;
  final bool isActive;
  final String? barcode;

  // Medicine details (pharmacies); null/false for everyone else.
  final String? genericName;
  final String? manufacturer;
  final String? strength;
  final String? dosageForm;
  final bool requiresPrescription;

  /// Units in expired batches — counted in [stock] but not sellable.
  final int expiredStock;

  /// Soonest expiry date among unexpired batches, if any are dated.
  final DateTime? nextExpiry;

  /// Units that can actually be sold.
  int get sellableStock => (stock - expiredStock).clamp(0, stock);

  factory ProductModel.fromJson(Map<String, dynamic> j) => ProductModel(
        id: j['id'] as String,
        name: j['name'] as String,
        price: (j['price'] as num).toDouble(),
        stock: j['stock'] as int? ?? 0,
        description: j['description'] as String?,
        sku: j['sku'] as String?,
        cost: (j['cost'] as num?)?.toDouble(),
        lowStockThreshold: j['lowStockThreshold'] as int? ?? 5,
        category: j['category'] as String?,
        imageUrl: j['imageUrl'] as String?,
        isActive: j['isActive'] as bool? ?? true,
        barcode: j['barcode'] as String?,
        genericName: j['genericName'] as String?,
        manufacturer: j['manufacturer'] as String?,
        strength: j['strength'] as String?,
        dosageForm: j['dosageForm'] as String?,
        requiresPrescription: j['requiresPrescription'] as bool? ?? false,
        expiredStock: j['expiredStock'] as int? ?? 0,
        nextExpiry: parseApiDate(j['nextExpiry'] as String?),
      );

  bool get isLowStock => stock <= lowStockThreshold;
  String get priceLabel => 'Rs ${price.toStringAsFixed(0)}';

  /// Whether a scanned [code] identifies this product. SKU counts too: the
  /// item form used to have a single "SKU / Barcode" field, so older products
  /// may have their barcode stored as the SKU.
  bool matchesCode(String code) => barcode == code || sku == code;

  /// e.g. "500 mg · Tablet", or null when neither is set.
  String? get medicineDetail {
    final parts = [strength, dosageForm]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();
    return parts.isEmpty ? null : parts.join(' · ');
  }

  // Local-only round-trip (session persistence), not sent to the backend.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'price': price,
        'stock': stock,
        'description': description,
        'sku': sku,
        'cost': cost,
        'lowStockThreshold': lowStockThreshold,
        'category': category,
        'imageUrl': imageUrl,
        'isActive': isActive,
        'barcode': barcode,
        'genericName': genericName,
        'manufacturer': manufacturer,
        'strength': strength,
        'dosageForm': dosageForm,
        'requiresPrescription': requiresPrescription,
        'expiredStock': expiredStock,
        'nextExpiry': nextExpiry == null ? null : formatApiDate(nextExpiry!),
      };

  ProductModel copyWith({
    String? name, double? price, int? stock, String? description,
    String? sku, double? cost, int? lowStockThreshold, String? category,
    String? imageUrl, bool? isActive, String? barcode, String? genericName,
    String? manufacturer, String? strength, String? dosageForm,
    bool? requiresPrescription, int? expiredStock,
  }) => ProductModel(
        id: id, name: name ?? this.name, price: price ?? this.price,
        stock: stock ?? this.stock, description: description ?? this.description,
        sku: sku ?? this.sku, cost: cost ?? this.cost,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        category: category ?? this.category, imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive ?? this.isActive,
        barcode: barcode ?? this.barcode,
        genericName: genericName ?? this.genericName,
        manufacturer: manufacturer ?? this.manufacturer,
        strength: strength ?? this.strength,
        dosageForm: dosageForm ?? this.dosageForm,
        requiresPrescription: requiresPrescription ?? this.requiresPrescription,
        expiredStock: expiredStock ?? this.expiredStock,
        nextExpiry: nextExpiry,
      );
}

/// Parses a date-only API value ("2027-03-31" or "2027-03-31T00:00:00.000Z")
/// as a local calendar date, so it never shifts a day across time zones.
DateTime? parseApiDate(String? s) {
  if (s == null || s.length < 10) return null;
  return DateTime.tryParse(s.substring(0, 10));
}

String formatApiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

/// A received lot of a product with its own expiry date.
class ProductBatch {
  const ProductBatch({
    required this.id,
    required this.productId,
    required this.quantity,
    required this.isExpired,
    this.batchNumber,
    this.expiryDate,
    this.productName,
    this.productDetail,
  });

  final String id;
  final String productId;
  final int quantity;
  final bool isExpired;
  final String? batchNumber;
  final DateTime? expiryDate;

  /// Filled in by the expiring-stock list, which spans products.
  final String? productName;
  final String? productDetail;

  factory ProductBatch.fromJson(Map<String, dynamic> j) {
    final product = j['product'] as Map<String, dynamic>?;
    final detail = [product?['strength'], product?['dosageForm']]
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .join(' · ');
    return ProductBatch(
      id: j['id'] as String,
      productId: j['productId'] as String,
      quantity: j['quantity'] as int? ?? 0,
      isExpired: j['isExpired'] as bool? ?? false,
      batchNumber: j['batchNumber'] as String?,
      expiryDate: parseApiDate(j['expiryDate'] as String?),
      productName: product?['name'] as String?,
      productDetail: detail.isEmpty ? null : detail,
    );
  }

  /// Days until expiry (negative once expired), or null if undated.
  int? get daysToExpiry {
    if (expiryDate == null) return null;
    final now = DateTime.now();
    return expiryDate!.difference(DateTime(now.year, now.month, now.day)).inDays;
  }

  String get label => batchNumber?.isNotEmpty == true ? 'Batch $batchNumber' : 'No batch number';
}

class InventoryLogEntry {
  const InventoryLogEntry({
    required this.id,
    required this.productId,
    required this.productName,
    required this.type,
    required this.quantity,
    required this.reason,
    required this.stockBefore,
    required this.stockAfter,
    required this.createdAt,
    this.createdByName,
  });

  final String id;
  final String productId;
  final String productName;
  final InventoryMovementType type;
  final int quantity;
  final String reason;
  final int stockBefore;
  final int stockAfter;
  final DateTime createdAt;
  final String? createdByName;
}
