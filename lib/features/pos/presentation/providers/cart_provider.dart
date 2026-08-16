import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../pos/domain/pos_models.dart';
import '../../../services/domain/service_models.dart';
import '../../../inventory/domain/inventory_models.dart';
import '../../../customers/domain/customer_models.dart';
import '../../../pos/presentation/providers/salon_sessions_provider.dart';

const _uuid = Uuid();

/// One cart per salon session — family-keyed by [SalonSession.id], so each
/// concurrently open session (Ram's customer, Shyam's customer, ...) has a
/// genuinely independent instance of this notifier with its own state.
/// Riverpod creates and holds a separate CartNotifier per distinct id
/// automatically; nothing about the notifier's own logic needed to change
/// to get that isolation — see cartProvider below. Mirrors the same
/// StateNotifierProvider.family pattern already used for BookingsNotifier
/// in calendar_tab.dart.
class CartNotifier extends StateNotifier<CartState> {
  CartNotifier(this.sessionId) : super(const CartState());
  final String sessionId;

  // '' is the "no session assigned" placeholder id (see
  // selectedSessionIdProvider) — its cart is meant to be permanently empty
  // and inert, never a real place to stash items, since there's no session
  // for it to ever be checked out into. Without this guard, items added
  // while briefly unassigned (e.g. before session data finishes loading)
  // would sit here forever — this provider isn't autoDispose — and keep
  // reappearing every time the user has no session, looking like a phantom
  // cart that can't be cleared.
  bool get _isThrowaway => sessionId.isEmpty;

  // ── Items ─────────────────────────────────────────────────────────────────

  void addService(ServiceModel service, {StaffMember? staff}) {
    if (_isThrowaway) return;
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
    if (_isThrowaway) return;
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

  // ── Restore (app-start session persistence — see salon_sessions_storage.dart) ──
  // Only ever called once, immediately after this notifier is first created
  // for a session id being restored from disk, before any UI has read it —
  // never during normal use, so this is not a general-purpose "overwrite
  // the cart" escape hatch.
  void restore(CartState restored) {
    state = restored;
  }
}

// ─── Providers ────────────────────────────────────────────────────────────────

/// One independent CartNotifier per session id — see the class doc comment
/// above. Not autoDispose: a session (and its cart) must survive the
/// cashier navigating away from Checkout and back, or switching to another
/// session and back, exactly like the old single global cart did.
final cartProvider = StateNotifierProvider.family<CartNotifier, CartState, String>(
  (ref, sessionId) => CartNotifier(sessionId),
);

// ─── "Active" convenience providers ────────────────────────────────────────
//
// The overwhelming majority of the app only ever needs "whatever cart is
// currently selected in Checkout" — these two exist so call sites can keep
// the exact same shape they had before sessions existed
// (`ref.watch(activeCartProvider)` / `ref.read(activeCartNotifierProvider)`)
// instead of every one of them having to thread a session id through by
// hand. Restaurant-style single-session use is just the special case where
// there's only ever one id to resolve to.

final activeCartProvider = Provider<CartState>((ref) {
  final sessionId = ref.watch(selectedSessionIdProvider);
  return ref.watch(cartProvider(sessionId));
});

final activeCartNotifierProvider = Provider<CartNotifier>((ref) {
  final sessionId = ref.watch(selectedSessionIdProvider);
  return ref.watch(cartProvider(sessionId).notifier);
});

final cartItemCountProvider = Provider<int>((ref) => ref.watch(activeCartProvider).itemCount);

final cartTotalProvider = Provider<double>((ref) => ref.watch(activeCartProvider).total);
