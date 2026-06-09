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

  bool get isLowStock => stock <= lowStockThreshold;
  String get priceLabel => 'NPR ${price.toStringAsFixed(0)}';

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
}
