import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../data/discounts_repository.dart';
import '../models/discount_model.dart';

final discountsRepoProvider = Provider<DiscountsRepository>(
  (ref) => DiscountsRepository(ref.read(apiClientProvider)),
);

class DiscountsNotifier extends AsyncNotifier<List<Discount>> {
  @override
  Future<List<Discount>> build() {
    return ref.read(discountsRepoProvider).getAll();
  }

  Future<void> createDiscount({
    required String name,
    required DiscountType type,
    required double value,
    bool isActive = true,
    DiscountScope scope = DiscountScope.all,
    String? serviceId,
  }) async {
    await ref.read(discountsRepoProvider).create(
          name: name,
          type: type,
          value: value,
          isActive: isActive,
          scope: scope,
          serviceId: serviceId,
        );
    ref.invalidateSelf();
  }

  Future<void> updateDiscount(
    String id, {
    String? name,
    DiscountType? type,
    double? value,
    bool? isActive,
    DiscountScope? scope,
    String? serviceId,
  }) async {
    await ref.read(discountsRepoProvider).update(
          id,
          name: name,
          type: type,
          value: value,
          isActive: isActive,
          scope: scope,
          serviceId: serviceId,
        );
    ref.invalidateSelf();
  }

  Future<void> deleteDiscount(String id) async {
    await ref.read(discountsRepoProvider).delete(id);
    ref.invalidateSelf();
  }
}

final discountsProvider =
    AsyncNotifierProvider<DiscountsNotifier, List<Discount>>(
  DiscountsNotifier.new,
);
