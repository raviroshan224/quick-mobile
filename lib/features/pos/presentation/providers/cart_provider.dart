import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../pos/domain/pos_models.dart';
import '../../../services/domain/service_models.dart';
import '../../../customers/domain/customer_models.dart';

const _uuid = Uuid();

class CartNotifier extends Notifier<CartState> {
  @override
  CartState build() => const CartState();

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

  void removeItem(String itemId) {
    state = state.copyWith(items: state.items.where((i) => i.id != itemId).toList());
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

  void applyDiscount(String label, double amount, {bool isPercentage = true}) {
    state = state.copyWith(discount: DiscountEntry(label: label, amount: amount, isPercentage: isPercentage));
  }

  void clearDiscount() {
    state = state.copyWith(clearDiscount: true);
  }

  void setTip(double amount) {
    state = state.copyWith(tipAmount: amount);
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

final cartProvider = NotifierProvider<CartNotifier, CartState>(CartNotifier.new);

final cartItemCountProvider = Provider<int>((ref) => ref.watch(cartProvider).itemCount);

final cartTotalProvider = Provider<double>((ref) => ref.watch(cartProvider).total);
