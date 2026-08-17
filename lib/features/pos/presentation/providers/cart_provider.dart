import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../pos/domain/pos_models.dart';
import '../../../services/domain/service_models.dart';
import '../../../inventory/domain/inventory_models.dart';
import '../../../customers/domain/customer_models.dart';

const _uuid = Uuid();

class CartNotifier extends StateNotifier<CartState> {
  CartNotifier() : super(const CartState());

  // ── Items ─────────────────────────────────────────────────────────────────

  void addService(ServiceModel service, {StaffMember? staff}) {
    final id = _uuid.v4();
    final item = CartItem(
      id: id,
      service: service,
      unitPrice: service.price,
      assignedStaff: staff,
    );
    state = state.copyWith(items: [...state.items, item]);
  }

  void addProduct(ProductModel product) {
    final item = CartItem(
      id: _uuid.v4(),
      product: product,
      unitPrice: product.price,
    );
    state = state.copyWith(items: [...state.items, item]);
  }

  void removeItem(String itemId) {
    final items = state.items.where((i) => i.id != itemId).toList();
    // A service-scoped discount that no longer matches anything left in the
    // cart would otherwise keep showing as "applied" while silently
    // contributing Rs 0 (CartState.discountAmount already floors to the
    // matching items' total) — clear it so the UI doesn't imply a discount
    // is active when it no longer applies to anything.
    final discount = state.discount;
    final orphanedDiscount = discount != null &&
        discount.scope == DiscountEntryScope.service &&
        !items.any((i) => i.service?.id == discount.serviceId);
    state = state.copyWith(
      items: items,
      clearDiscount: orphanedDiscount,
    );
  }

  void incrementQuantity(String itemId) {
    state = state.copyWith(
      items: state.items.map((i) => i.id == itemId ? i.copyWith(quantity: i.quantity + 1) : i).toList(),
    );
  }

  void decrementQuantity(String itemId) {
    final item = state.items.firstWhere((i) => i.id == itemId);
    if (item.quantity <= 1) {
      removeItem(itemId);
    } else {
      state = state.copyWith(
        items: state.items.map((i) => i.id == itemId ? i.copyWith(quantity: i.quantity - 1) : i).toList(),
      );
    }
  }

  void assignStaff(String itemId, StaffMember? staff) {
    state = state.copyWith(
      items: state.items.map((i) => i.id == itemId ? i.copyWith(assignedStaff: staff) : i).toList(),
    );
  }

  // ── Customer ──────────────────────────────────────────────────────────────

  void setCustomer(CustomerModel customer) {
    state = state.copyWith(customer: customer, isGuest: false, clearCustomer: false);
  }

  void setGuest({String? name, String? phone}) {
    state = state.copyWith(
      isGuest: true,
      guestName: name,
      guestPhone: phone,
      clearCustomer: true,
    );
  }

  void clearCustomer() {
    state = state.copyWith(clearCustomer: true, isGuest: false);
  }

  // ── Discount & Tip ────────────────────────────────────────────────────────

  void applyDiscount(
    String label,
    double amount, {
    bool isPercentage = true,
    String? discountId,
    DiscountEntryScope scope = DiscountEntryScope.all,
    String? serviceId,
  }) {
    state = state.copyWith(
      discount: DiscountEntry(
        label: label,
        amount: amount,
        isPercentage: isPercentage,
        discountId: discountId,
        scope: scope,
        serviceId: serviceId,
      ),
    );
  }

  void clearDiscount() {
    state = state.copyWith(clearDiscount: true);
  }

  void setTip(double amount) {
    state = state.copyWith(tipAmount: amount);
  }

  // ── Final Payable (salon checkout) ───────────────────────────────────────
  // The cashier types the amount the customer actually pays; the backend
  // derives the manual adjustment from it against the authoritative
  // subtotal (see TransactionsRepository.quote/checkout). The client never
  // computes or sends the adjustment itself — CartState.manualAdjustment is
  // a display-only placeholder shown before the quote comes back.

  void setFinalPayable(double? amount) {
    state = state.copyWith(finalPayable: amount, clearFinalPayable: amount == null);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  // ── Checkout ──────────────────────────────────────────────────────────────

  void clear() {
    state = const CartState();
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

final cartProvider = StateNotifierProvider<CartNotifier, CartState>(
  (ref) => CartNotifier(),
);

final activeCartProvider = Provider<CartState>((ref) => ref.watch(cartProvider));

final activeCartNotifierProvider = Provider<CartNotifier>((ref) => ref.watch(cartProvider.notifier));

final cartItemCountProvider = Provider<int>((ref) => ref.watch(activeCartProvider).itemCount);

final cartTotalProvider = Provider<double>((ref) => ref.watch(activeCartProvider).total);
