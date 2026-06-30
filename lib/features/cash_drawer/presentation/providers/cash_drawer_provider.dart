import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/cash_drawer_repository.dart';
import '../../domain/cash_drawer_models.dart';

final cashDrawerRepoProvider = Provider<CashDrawerRepository>(
  (ref) => CashDrawerRepository(ref.read(apiClientProvider)),
);

final currentDrawerProvider = FutureProvider<CashDrawerSession?>((ref) {
  return ref.watch(cashDrawerRepoProvider).getCurrent();
});

class CashDrawerNotifier
    extends StateNotifier<AsyncValue<CashDrawerSession?>> {
  CashDrawerNotifier(this._repo) : super(const AsyncValue.loading()) {
    _load();
  }

  final CashDrawerRepository _repo;

  Future<void> _load() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => _repo.getCurrent());
  }

  Future<void> openDrawer(double openBalance, {String? notes}) async {
    await _repo.open(openBalance, notes: notes);
    await _load();
  }

  Future<void> closeDrawer(double closeBalance, {String? notes}) async {
    await _repo.close(closeBalance, notes: notes);
    await _load();
  }

  Future<void> recordMovement({
    required CashMovementType type,
    required double amount,
    required String reason,
  }) async {
    await _repo.recordMovement(type: type, amount: amount, reason: reason);
    await _load();
  }

  Future<void> refresh() => _load();
}

final cashDrawerNotifierProvider = StateNotifierProvider<CashDrawerNotifier,
    AsyncValue<CashDrawerSession?>>(
  (ref) => CashDrawerNotifier(ref.read(cashDrawerRepoProvider)),
);
