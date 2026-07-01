import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/item_model.dart';

class ItemsNotifier extends StateNotifier<List<Item>> {
  ItemsNotifier() : super(_mockItems);

  void add(Item item) => state = [...state, item];

  void update(Item item) {
    state = [for (final i in state) if (i.id == item.id) item else i];
  }

  void delete(String id) => state = state.where((i) => i.id != id).toList();

  void adjustStock(String id, int delta) {
    state = [
      for (final i in state)
        if (i.id == id)
          i.copyWith(stockQty: (i.stockQty + delta).clamp(0, 99999))
        else
          i,
    ];
  }
}

final itemsProvider = StateNotifierProvider<ItemsNotifier, List<Item>>(
  (_) => ItemsNotifier(),
);

final _mockItems = [
  Item(
    id: '1',
    name: 'Keratin Shampoo',
    sku: 'SH-001',
    price: 450,
    costPrice: 200,
    stockQty: 12,
    category: 'Hair Care',
    lowStockThreshold: 5,
    isActive: true,
  ),
  Item(
    id: '2',
    name: 'Argan Oil Conditioner',
    sku: 'SH-002',
    price: 550,
    costPrice: 250,
    stockQty: 3,
    category: 'Hair Care',
    lowStockThreshold: 5,
    isActive: true,
  ),
  Item(
    id: '3',
    name: 'Hair Color Gel – Black',
    sku: 'GEL-001',
    price: 280,
    costPrice: 100,
    stockQty: 20,
    category: 'Hair Care',
    lowStockThreshold: 5,
    isActive: true,
  ),
  Item(
    id: '4',
    name: 'Moisturizing Face Cream',
    sku: 'SK-001',
    price: 680,
    costPrice: 320,
    stockQty: 0,
    category: 'Skin Care',
    lowStockThreshold: 5,
    isActive: true,
  ),
  Item(
    id: '5',
    name: 'Nail Polish – Red',
    sku: 'NL-001',
    price: 180,
    costPrice: 60,
    stockQty: 15,
    category: 'Nail Care',
    lowStockThreshold: 3,
    isActive: true,
  ),
  Item(
    id: '6',
    name: 'Professional Hair Brush',
    sku: 'EQ-001',
    price: 850,
    costPrice: 400,
    stockQty: 4,
    category: 'Equipment',
    lowStockThreshold: 2,
    isActive: true,
  ),
];
