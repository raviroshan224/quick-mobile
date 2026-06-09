import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mock_inventory_repository.dart';
import '../../domain/inventory_models.dart';

final _inventoryRepoProvider = Provider((_) => MockInventoryRepository());

final productsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(_inventoryRepoProvider).getAll();
});

final lowStockProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(_inventoryRepoProvider).getLowStock();
});

final inventoryLogsProvider = FutureProvider<List<InventoryLogEntry>>((ref) {
  return ref.watch(_inventoryRepoProvider).getLogs();
});
