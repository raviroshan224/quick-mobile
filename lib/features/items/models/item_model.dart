import 'package:uuid/uuid.dart';

const _uuid = Uuid();

const List<String> itemCategories = [
  'All',
  'Hair Care',
  'Skin Care',
  'Nail Care',
  'Retail',
  'Equipment',
  'Other',
];

class Item {
  final String id;
  final String name;
  final String? sku;
  final double price;
  final double? costPrice;
  final int stockQty;
  final String category;
  final int lowStockThreshold;
  final bool isActive;

  const Item({
    required this.id,
    required this.name,
    this.sku,
    required this.price,
    this.costPrice,
    required this.stockQty,
    required this.category,
    this.lowStockThreshold = 5,
    this.isActive = true,
  });

  bool get isLowStock => stockQty <= lowStockThreshold && stockQty > 0;
  bool get isOutOfStock => stockQty == 0;

  Item copyWith({
    String? name,
    String? sku,
    double? price,
    double? costPrice,
    int? stockQty,
    String? category,
    int? lowStockThreshold,
    bool? isActive,
  }) {
    return Item(
      id: id,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      costPrice: costPrice ?? this.costPrice,
      stockQty: stockQty ?? this.stockQty,
      category: category ?? this.category,
      lowStockThreshold: lowStockThreshold ?? this.lowStockThreshold,
      isActive: isActive ?? this.isActive,
    );
  }

  static Item create({
    required String name,
    String? sku,
    required double price,
    double? costPrice,
    required int stockQty,
    required String category,
    int lowStockThreshold = 5,
    bool isActive = true,
  }) {
    return Item(
      id: _uuid.v4(),
      name: name,
      sku: sku,
      price: price,
      costPrice: costPrice,
      stockQty: stockQty,
      category: category,
      lowStockThreshold: lowStockThreshold,
      isActive: isActive,
    );
  }
}
