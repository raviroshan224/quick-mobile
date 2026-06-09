import 'package:uuid/uuid.dart';

const _uuid = Uuid();

enum DiscountType { percentage, fixed }

/// Where the discount applies during checkout.
enum DiscountScope {
  all,       // entire cart subtotal
  category,  // line items belonging to a specific service category
  service,   // one specific service
}

class Discount {
  final String id;
  final String name;
  final DiscountType type;
  final double value;
  final bool isActive;

  // scope
  final DiscountScope scope;
  final String? categoryName; // e.g. 'Hair', 'Facial' — set when scope == category
  final String? serviceId;    // UUID — set when scope == service
  final String? serviceName;  // denormalised for display

  const Discount({
    required this.id,
    required this.name,
    required this.type,
    required this.value,
    this.isActive = true,
    this.scope = DiscountScope.all,
    this.categoryName,
    this.serviceId,
    this.serviceName,
  });

  /// Short human-readable discount amount label, e.g. "10% off" or "Rs 100 off".
  String get label {
    if (type == DiscountType.percentage) {
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% off';
    }
    return 'Rs ${value.toStringAsFixed(0)} off';
  }

  /// Where this discount applies, e.g. "All services & items" or "Hair".
  String get scopeLabel {
    switch (scope) {
      case DiscountScope.all:
        return 'All services & items';
      case DiscountScope.category:
        return categoryName ?? 'All categories';
      case DiscountScope.service:
        return serviceName ?? 'Specific service';
    }
  }

  /// Calculates the rupee amount to deduct from [subtotal].
  /// For scoped discounts the caller should pass only the relevant subtotal.
  double apply(double subtotal) {
    if (type == DiscountType.percentage) {
      return subtotal * value / 100;
    }
    return value > subtotal ? subtotal : value;
  }

  Discount copyWith({
    String? name,
    DiscountType? type,
    double? value,
    bool? isActive,
    DiscountScope? scope,
    String? categoryName,
    String? serviceId,
    String? serviceName,
  }) {
    return Discount(
      id: id,
      name: name ?? this.name,
      type: type ?? this.type,
      value: value ?? this.value,
      isActive: isActive ?? this.isActive,
      scope: scope ?? this.scope,
      // When scope changes to `all`, clear the scope-specific fields.
      categoryName: (scope ?? this.scope) == DiscountScope.category
          ? (categoryName ?? this.categoryName)
          : null,
      serviceId: (scope ?? this.scope) == DiscountScope.service
          ? (serviceId ?? this.serviceId)
          : null,
      serviceName: (scope ?? this.scope) == DiscountScope.service
          ? (serviceName ?? this.serviceName)
          : null,
    );
  }

  static Discount create({
    required String name,
    required DiscountType type,
    required double value,
    bool isActive = true,
    DiscountScope scope = DiscountScope.all,
    String? categoryName,
    String? serviceId,
    String? serviceName,
  }) {
    return Discount(
      id: _uuid.v4(),
      name: name,
      type: type,
      value: value,
      isActive: isActive,
      scope: scope,
      categoryName: scope == DiscountScope.category ? categoryName : null,
      serviceId: scope == DiscountScope.service ? serviceId : null,
      serviceName: scope == DiscountScope.service ? serviceName : null,
    );
  }
}
