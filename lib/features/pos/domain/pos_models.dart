import '../../services/domain/service_models.dart';
import '../../staff/domain/staff_models.dart';
import '../../customers/domain/customer_models.dart';
import '../../inventory/domain/inventory_models.dart';

// ─── Payment ──────────────────────────────────────────────────────────────────

enum PaymentMethod { cash, fonepay, split }

extension PaymentMethodExt on PaymentMethod {
  String get label => switch (this) {
        PaymentMethod.cash => 'Cash',
        PaymentMethod.fonepay => 'Fonepay QR',
        PaymentMethod.split => 'Split',
      };
}

// ─── Cart Item ────────────────────────────────────────────────────────────────

class CartItem {
  CartItem({
    required this.id,
    this.service,
    this.product,
    this.assignedStaff,
    this.quantity = 1,
    required this.unitPrice,
  });

  final String id;
  final ServiceModel? service;
  final ProductModel? product;
  final StaffMember? assignedStaff;
  final int quantity;
  final double unitPrice;

  double get totalPrice => unitPrice * quantity;
  String get name => service?.name ?? product?.name ?? 'Item';

  CartItem copyWith({StaffMember? assignedStaff, int? quantity, double? unitPrice}) => CartItem(
        id: id,
        service: service,
        product: product,
        assignedStaff: assignedStaff ?? this.assignedStaff,
        quantity: quantity ?? this.quantity,
        unitPrice: unitPrice ?? this.unitPrice,
      );

  // ── Local persistence (session survives an app restart) ────────────────────
  // Round-trips through device storage only — never sent to or read from the
  // backend this way (checkout still builds its own request body from these
  // fields directly; see TransactionsRepository._itemsFor). assignedStaff is
  // stored as a minimal id+name stub rather than via a StaffModel.toJson()
  // that doesn't exist — the full record is only ever needed again for its
  // id at checkout, and its name for display, both covered here.

  Map<String, dynamic> toJson() => {
        'id': id,
        'service': service?.toJson(),
        'product': product?.toJson(),
        'assignedStaffId': assignedStaff?.id,
        'assignedStaffFirstName': assignedStaff?.firstName,
        'assignedStaffLastName': assignedStaff?.lastName,
        'quantity': quantity,
        'unitPrice': unitPrice,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: j['id'] as String,
        service: j['service'] == null
            ? null
            : ServiceModel.fromJson(j['service'] as Map<String, dynamic>),
        product: j['product'] == null
            ? null
            : ProductModel.fromJson(j['product'] as Map<String, dynamic>),
        assignedStaff: j['assignedStaffId'] == null
            ? null
            : StaffMember(
                id: j['assignedStaffId'] as String,
                userId: '',
                firstName: j['assignedStaffFirstName'] as String? ?? '',
                lastName: j['assignedStaffLastName'] as String? ?? '',
              ),
        quantity: j['quantity'] as int? ?? 1,
        unitPrice: (j['unitPrice'] as num).toDouble(),
      );
}

// ─── Cart State ───────────────────────────────────────────────────────────────

enum DiscountEntryScope { all, service }

class DiscountEntry {
  const DiscountEntry({
    required this.label,
    required this.amount,
    required this.isPercentage,
    this.discountId,
    this.scope = DiscountEntryScope.all,
    this.serviceId,
  });
  final String label;
  final double amount; // if isPercentage: 10 = 10%
  final bool isPercentage;
  // Set when applied from the saved Discount catalog (as opposed to a
  // manually typed amount) — forwarded to the backend so it recalculates
  // authoritatively instead of trusting the client's amount.
  final String? discountId;
  final DiscountEntryScope scope;
  final String? serviceId; // set when scope == service

  Map<String, dynamic> toJson() => {
        'label': label,
        'amount': amount,
        'isPercentage': isPercentage,
        'discountId': discountId,
        'scope': scope.name,
        'serviceId': serviceId,
      };

  factory DiscountEntry.fromJson(Map<String, dynamic> j) => DiscountEntry(
        label: j['label'] as String,
        amount: (j['amount'] as num).toDouble(),
        isPercentage: j['isPercentage'] as bool? ?? true,
        discountId: j['discountId'] as String?,
        scope: DiscountEntryScope.values.firstWhere(
          (s) => s.name == j['scope'],
          orElse: () => DiscountEntryScope.all,
        ),
        serviceId: j['serviceId'] as String?,
      );
}

class CartState {
  const CartState({
    this.items = const [],
    this.customer,
    this.isGuest = false,
    this.guestName,
    this.guestPhone,
    this.discount,
    this.tipAmount = 0,
    this.finalPayable,
    this.notes,
  });

  final List<CartItem> items;
  final CustomerModel? customer;
  final bool isGuest;
  final String? guestName;
  final String? guestPhone;
  final DiscountEntry? discount;
  final double tipAmount;
  // Salon checkout: the amount the cashier typed as what the customer
  // actually pays. Null means the field hasn't been touched yet (defaults
  // to subtotal on screen, but isn't sent to the backend until the cashier
  // has an actual value). Independent of `discount`/`tipAmount` above,
  // which stay in the model for backward compatibility but are no longer
  // surfaced by the checkout UI (see ReviewSaleSheet._ChargeStep).
  final double? finalPayable;
  final String? notes;

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  double get subtotal => items.fold(0.0, (s, i) => s + i.totalPrice);

  double get discountAmount {
    if (discount == null) return 0;
    // Scoped discounts only apply to the matching service's line items —
    // mirrors the backend's scoped-discount calculation so the total shown
    // to the cashier before payment matches what's actually charged.
    final base = discount!.scope == DiscountEntryScope.service
        ? items
            .where((i) => i.service?.id == discount!.serviceId)
            .fold(0.0, (s, i) => s + i.totalPrice)
        : subtotal;
    final amount =
        discount!.isPercentage ? base * discount!.amount / 100 : discount!.amount;
    return amount > base ? base : amount;
  }

  // Salon checkout: manualAdjustment = finalPayable - subtotal, mirroring
  // TransactionsService.priceCart() on the backend exactly. This is a local
  // placeholder only — the backend recomputes it against its own
  // authoritative subtotal in the quote/checkout response, which is what
  // ReviewSaleSheet actually charges (see CartQuote in
  // transactions_repository.dart).
  double get manualAdjustment => finalPayable == null ? 0 : finalPayable! - subtotal;

  double get total =>
      subtotal - discountAmount + tipAmount + manualAdjustment;

  String? get customerLabel {
    if (customer != null) return customer!.fullName;
    if (isGuest) return guestName?.isNotEmpty == true ? guestName : 'Guest';
    return null;
  }

  CartState copyWith({
    List<CartItem>? items,
    CustomerModel? customer,
    bool? isGuest,
    String? guestName,
    String? guestPhone,
    DiscountEntry? discount,
    double? tipAmount,
    double? finalPayable,
    String? notes,
    bool clearCustomer = false,
    bool clearDiscount = false,
    bool clearFinalPayable = false,
  }) => CartState(
        items: items ?? this.items,
        customer: clearCustomer ? null : (customer ?? this.customer),
        isGuest: isGuest ?? this.isGuest,
        guestName: guestName ?? this.guestName,
        guestPhone: guestPhone ?? this.guestPhone,
        discount: clearDiscount ? null : (discount ?? this.discount),
        tipAmount: tipAmount ?? this.tipAmount,
        finalPayable: clearFinalPayable ? null : (finalPayable ?? this.finalPayable),
        notes: notes ?? this.notes,
      );

  // Local persistence only (session survives an app restart) — see
  // SalonSessionsStorage. Never sent to or read from the backend directly;
  // checkout/quote build their own request bodies from live CartState.
  Map<String, dynamic> toJson() => {
        'items': items.map((i) => i.toJson()).toList(),
        'customer': customer?.toJson(),
        'isGuest': isGuest,
        'guestName': guestName,
        'guestPhone': guestPhone,
        'discount': discount?.toJson(),
        'tipAmount': tipAmount,
        'finalPayable': finalPayable,
        'notes': notes,
      };

  factory CartState.fromJson(Map<String, dynamic> j) => CartState(
        items: (j['items'] as List<dynamic>? ?? [])
            .map((e) => CartItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        customer: j['customer'] == null
            ? null
            : CustomerModel.fromJson(j['customer'] as Map<String, dynamic>),
        isGuest: j['isGuest'] as bool? ?? false,
        guestName: j['guestName'] as String?,
        guestPhone: j['guestPhone'] as String?,
        discount: j['discount'] == null
            ? null
            : DiscountEntry.fromJson(j['discount'] as Map<String, dynamic>),
        tipAmount: (j['tipAmount'] as num?)?.toDouble() ?? 0,
        finalPayable: (j['finalPayable'] as num?)?.toDouble(),
        notes: j['notes'] as String?,
      );
}

// Re-export StaffMember alias for POS use (avoids import confusion)
typedef StaffMember = StaffModel;
