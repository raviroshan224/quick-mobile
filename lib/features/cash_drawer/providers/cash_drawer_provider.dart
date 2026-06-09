import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/cash_drawer_model.dart';

final currentDrawerProvider = FutureProvider<CashDrawer?>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/cash-drawer/current');
  final data = response['data'];
  if (data == null) return null;
  return CashDrawer.fromJson(data as Map<String, dynamic>);
});

class CashDrawerNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<void> open(double openBalance) async {
    final client = ref.read(apiClientProvider);
    await client.post('/cash-drawer/open', data: {'openBalance': openBalance});
    ref.invalidate(currentDrawerProvider);
  }

  Future<void> close(double closeBalance, {String? notes}) async {
    final client = ref.read(apiClientProvider);
    await client.post('/cash-drawer/close', data: {'closeBalance': closeBalance, 'notes': notes});
    ref.invalidate(currentDrawerProvider);
  }

  Future<void> addMovement({required String drawerId, required String type, required double amount, required String reason}) async {
    final client = ref.read(apiClientProvider);
    await client.post('/cash-drawer/movement', data: {'cashDrawerId': drawerId, 'type': type, 'amount': amount, 'reason': reason});
    ref.invalidate(currentDrawerProvider);
  }
}

final cashDrawerNotifierProvider = AsyncNotifierProvider<CashDrawerNotifier, void>(CashDrawerNotifier.new);
