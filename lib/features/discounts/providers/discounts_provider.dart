import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/discount_model.dart';

class DiscountsNotifier extends StateNotifier<List<Discount>> {
  DiscountsNotifier() : super(_mockDiscounts);

  void add(Discount d) => state = [...state, d];

  void update(Discount d) {
    state = [for (final s in state) if (s.id == d.id) d else s];
  }

  void delete(String id) => state = state.where((d) => d.id != id).toList();
}

final discountsProvider =
    StateNotifierProvider<DiscountsNotifier, List<Discount>>(
  (_) => DiscountsNotifier(),
);

/// The discount currently applied to the active checkout.
/// Reset to null when the cart is cleared.
final checkoutDiscountProvider = StateProvider<Discount?>((ref) => null);

final _mockDiscounts = [
  const Discount(
    id: '1',
    name: '10% Off',
    type: DiscountType.percentage,
    value: 10,
    isActive: true,
    scope: DiscountScope.all,
  ),
  const Discount(
    id: '2',
    name: 'Flat Rs. 100 Off',
    type: DiscountType.fixed,
    value: 100,
    isActive: true,
    scope: DiscountScope.all,
  ),
  const Discount(
    id: '3',
    name: 'Happy Hour – Hair 15%',
    type: DiscountType.percentage,
    value: 15,
    isActive: true,
    scope: DiscountScope.category,
    categoryName: 'Hair',
  ),
  const Discount(
    id: '4',
    name: 'Facial Special 20%',
    type: DiscountType.percentage,
    value: 20,
    isActive: true,
    scope: DiscountScope.category,
    categoryName: 'Facial',
  ),
  const Discount(
    id: '5',
    name: 'Free Manicure Add-on',
    type: DiscountType.fixed,
    value: 600,
    isActive: true,
    scope: DiscountScope.service,
    serviceId: '5',
    serviceName: 'Manicure',
  ),
  const Discount(
    id: '6',
    name: 'Student 20%',
    type: DiscountType.percentage,
    value: 20,
    isActive: false,
    scope: DiscountScope.all,
  ),
];
