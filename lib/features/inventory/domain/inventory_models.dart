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
      );

  bool get isLowStock => stock <= lowStockThreshold;
  String get priceLabel => 'Rs ${price.toStringAsFixed(0)}';

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
      };

  ProductModel copyWith({
    String? name, double? price, int? stock, String? description,
    String? sku, double? cost, int? lowStockThreshold, String? category,
    String? imageUrl, bool? isActive,
  }) => ProductModel(
        id: id, name: name ?? this.name, price: price ?? this.price,
        stock: stock ?? this.stock, description: description ?? this.description,
        sku: sku ?? this.sku, cost: cost ?? this.cost,
        lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
        category: category ?? this.category, imageUrl: imageUrl ?? this.imageUrl,
        isActive: isActive ?? this.isActive,
      );
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
