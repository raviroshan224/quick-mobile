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
}

// ─── Cart State ───────────────────────────────────────────────────────────────

class DiscountEntry {
  const DiscountEntry({required this.label, required this.amount, required this.isPercentage});
  final String label;
  final double amount; // if isPercentage: 10 = 10%
  final bool isPercentage;
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
    this.notes,
  });

  final List<CartItem> items;
  final CustomerModel? customer;
  final bool isGuest;
  final String? guestName;
  final String? guestPhone;
  final DiscountEntry? discount;
  final double tipAmount;
  final String? notes;

  bool get isEmpty => items.isEmpty;
  int get itemCount => items.fold(0, (s, i) => s + i.quantity);

  double get subtotal => items.fold(0.0, (s, i) => s + i.totalPrice);

  double get discountAmount {
    if (discount == null) return 0;
    return discount!.isPercentage ? subtotal * discount!.amount / 100 : discount!.amount;
  }

  double get total => subtotal - discountAmount + tipAmount;

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
    String? notes,
    bool clearCustomer = false,
    bool clearDiscount = false,
  }) => CartState(
        items: items ?? this.items,
        customer: clearCustomer ? null : (customer ?? this.customer),
        isGuest: isGuest ?? this.isGuest,
        guestName: guestName ?? this.guestName,
        guestPhone: guestPhone ?? this.guestPhone,
        discount: clearDiscount ? null : (discount ?? this.discount),
        tipAmount: tipAmount ?? this.tipAmount,
        notes: notes ?? this.notes,
      );
}

// Re-export StaffMember alias for POS use (avoids import confusion)
typedef StaffMember = StaffModel;
