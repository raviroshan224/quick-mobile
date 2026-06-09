import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/inventory_model.dart';

final inventoryLogsProvider = FutureProvider<List<InventoryLog>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/inventory/logs');
  final list = response['data'] as List;
  return list.map((e) => InventoryLog.fromJson(e as Map<String, dynamic>)).toList();
});

final lowStockProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/inventory/low-stock');
  return (response['data'] as List).cast<Map<String, dynamic>>();
});
