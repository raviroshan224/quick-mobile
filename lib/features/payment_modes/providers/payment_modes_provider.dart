import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/payment_modes_repository.dart';
import '../models/payment_mode_model.dart';

final paymentModesRepoProvider = Provider<PaymentModesRepository>(
  (ref) => PaymentModesRepository(ref.read(apiClientProvider)),
);

/// Active payment modes only — this is what Checkout shows alongside Cash.
final paymentModesProvider = AsyncNotifierProvider<PaymentModesNotifier, List<PaymentMode>>(
  PaymentModesNotifier.new,
);

class PaymentModesNotifier extends AsyncNotifier<List<PaymentMode>> {
  @override
  Future<List<PaymentMode>> build() {
    return ref.read(paymentModesRepoProvider).getAll();
  }

  Future<void> createMode({required String name, required String qrImageUrl}) async {
    await ref.read(paymentModesRepoProvider).create(name: name, qrImageUrl: qrImageUrl);
    _refreshBoth();
  }

  Future<void> updateMode(
    String id, {
    String? name,
    String? qrImageUrl,
    bool? isActive,
  }) async {
    await ref.read(paymentModesRepoProvider).update(
          id,
          name: name,
          qrImageUrl: qrImageUrl,
          isActive: isActive,
        );
    _refreshBoth();
  }

  Future<void> deleteMode(String id) async {
    await ref.read(paymentModesRepoProvider).delete(id);
    _refreshBoth();
  }

  // The management screen (allPaymentModesProvider) and Checkout
  // (this provider, active-only) read from the same backend list — a
  // mutation from either surface must invalidate both, or one screen keeps
  // showing stale data until it happens to rebuild on its own.
  void _refreshBoth() {
    ref.invalidateSelf();
    ref.invalidate(allPaymentModesProvider);
  }
}

/// Management screen (Settings) needs inactive modes too, so they can be
/// re-enabled — a separate provider rather than a parameterized one since
/// Checkout must never accidentally pick up the includeInactive=true list.
final allPaymentModesProvider = FutureProvider.autoDispose<List<PaymentMode>>(
  (ref) => ref.read(paymentModesRepoProvider).getAll(includeInactive: true),
);
