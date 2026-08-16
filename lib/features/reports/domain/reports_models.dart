class SalesSummary {
  const SalesSummary({
    required this.totalRevenue,
    required this.transactionCount,
    required this.avgTicket,
    required this.refundTotal,
    required this.totalDiscounts,
    required this.serviceValue,
    required this.manualAdjustments,
    required this.finalCollectedAmount,
    required this.byPaymentMethod,
  });

  final double totalRevenue;
  final int transactionCount;
  final double avgTicket;
  final double refundTotal;
  // Catalog/promo discounts only — kept separate from manualAdjustments
  // below, since the two are different mechanisms (see ReportsService.
  // getSalesSummary on the backend). Never mixed into one figure.
  final double totalDiscounts;
  // Salon "final payable" checkout, owner-facing figures:
  // serviceValue = catalog price of services actually performed (=subtotal)
  // manualAdjustments = signed sum of cashier-entered adjustments (+/-)
  // finalCollectedAmount = what was actually charged (=totalRevenue)
  // Kept as distinct named fields (rather than reusing totalRevenue/
  // totalDiscounts) so the Reports screen can show them under their own
  // labels without implying they're the same thing as ordinary discounts.
  final double serviceValue;
  final double manualAdjustments;
  final double finalCollectedAmount;
  final Map<String, double> byPaymentMethod; // keys: CASH, FONEPAY, SPLIT

  factory SalesSummary.fromJson(Map<String, dynamic> j) {
    // byPaymentMethod arrives as a List from groupBy: [{paymentMethod:'CASH', _sum:{total:100}}, ...]
    final rawList = j['byPaymentMethod'];
    final Map<String, double> byMethod = {};
    if (rawList is List) {
      for (final item in rawList) {
        if (item is Map<String, dynamic>) {
          final method = item['paymentMethod'] as String? ?? 'UNKNOWN';
          final sum = item['_sum'] as Map<String, dynamic>?;
          byMethod[method] = (sum?['total'] as num? ?? 0).toDouble();
        }
      }
    } else if (rawList is Map<String, dynamic>) {
      rawList.forEach((k, v) => byMethod[k] = (v as num? ?? 0).toDouble());
    }
    final totalRevenue = (j['totalRevenue'] as num? ?? 0).toDouble();
    final totalSubtotal = (j['totalSubtotal'] as num? ?? 0).toDouble();
    return SalesSummary(
      totalRevenue: totalRevenue,
      transactionCount: (j['totalTransactions'] as num? ?? j['transactionCount'] as num? ?? 0).toInt(),
      avgTicket: (j['averageTransaction'] as num? ?? j['avgTicket'] as num? ?? 0).toDouble(),
      refundTotal: (j['refundTotal'] as num? ?? 0).toDouble(),
      totalDiscounts: (j['totalDiscounts'] as num? ?? 0).toDouble(),
      // Fall back to the plain sums the backend has always returned
      // (subtotal/total) if an older backend build hasn't added the
      // dedicated keys yet — keeps this screen working either way.
      serviceValue: (j['serviceValue'] as num? ?? totalSubtotal).toDouble(),
      manualAdjustments: (j['manualAdjustments'] as num? ?? j['totalManualAdjustments'] as num? ?? 0)
          .toDouble(),
      finalCollectedAmount: (j['finalCollectedAmount'] as num? ?? totalRevenue).toDouble(),
      byPaymentMethod: byMethod,
    );
  }
}

class StaffPerformance {
  const StaffPerformance({
    required this.staffId,
    required this.staffName,
    required this.serviceCount,
    required this.totalRevenue,
    required this.commission,
    required this.shiftsCount,
    required this.totalHours,
  });

  final String staffId;
  final String staffName;
  final int serviceCount;
  final double totalRevenue;
  final double commission;
  final int shiftsCount;
  final double totalHours;

  factory StaffPerformance.fromJson(Map<String, dynamic> j) {
    final staff = j['staff'] as Map<String, dynamic>?;
    final user = staff?['user'] as Map<String, dynamic>?;
    final firstName = user?['firstName'] as String? ?? '';
    final lastName = user?['lastName'] as String? ?? '';
    final fullName = '$firstName $lastName'.trim();
    return StaffPerformance(
      staffId: staff?['id'] as String? ?? j['staffId'] as String? ?? '',
      staffName: fullName.isNotEmpty ? fullName : j['staffName'] as String? ?? '',
      serviceCount: j['serviceCount'] as int? ?? 0,
      totalRevenue: (j['totalSales'] as num? ?? j['totalRevenue'] as num? ?? 0).toDouble(),
      commission: (j['totalCommission'] as num? ?? j['commission'] as num? ?? 0).toDouble(),
      shiftsCount: j['shiftsCount'] as int? ?? 0,
      totalHours: (j['totalHoursWorked'] as num? ?? j['totalHours'] as num? ?? 0).toDouble(),
    );
  }
}

class ServicePopularity {
  const ServicePopularity({
    required this.serviceId,
    required this.serviceName,
    required this.bookingCount,
    required this.revenue,
  });

  final String serviceId;
  final String serviceName;
  final int bookingCount;
  final double revenue;

  factory ServicePopularity.fromJson(Map<String, dynamic> j) {
    final service = j['service'] as Map<String, dynamic>?;
    return ServicePopularity(
      serviceId: service?['id'] as String? ?? j['serviceId'] as String? ?? '',
      serviceName: service?['name'] as String? ?? j['serviceName'] as String? ?? '',
      bookingCount: j['count'] as int? ?? j['bookingCount'] as int? ?? 0,
      revenue: (j['totalRevenue'] as num? ?? j['revenue'] as num? ?? 0).toDouble(),
    );
  }
}

class InventoryProduct {
  const InventoryProduct({
    required this.id,
    required this.name,
    required this.stock,
    required this.lowStockThreshold,
    required this.status,
  });

  final String id;
  final String name;
  final int stock;
  final int lowStockThreshold;
  final String status; // 'ok' | 'low' | 'critical'

  factory InventoryProduct.fromJson(Map<String, dynamic> j) {
    final stock = (j['stock'] as num?)?.toInt() ?? 0;
    final threshold = (j['lowStockThreshold'] as num?)?.toInt() ?? 0;
    // Backend doesn't send a `status` field — derive it from stock vs threshold.
    final derivedStatus = stock <= 0 ? 'critical' : (stock <= threshold ? 'low' : 'ok');
    return InventoryProduct(
      id: j['id'] as String? ?? '',
      name: j['name'] as String? ?? '',
      stock: stock,
      lowStockThreshold: threshold,
      status: j['status'] as String? ?? derivedStatus,
    );
  }
}

class InventoryMovement {
  const InventoryMovement({
    required this.item,
    required this.type,
    required this.qty,
    required this.note,
    required this.date,
  });

  final String item;
  final String type; // 'in' | 'out'
  final int qty;
  final String note;
  final String date;

  factory InventoryMovement.fromJson(Map<String, dynamic> j) {
    // Backend sends the log's `product: {name}` relation and a
    // STOCK_IN/STOCK_OUT/ADJUSTMENT `type` enum, not the flat
    // item/type('in'|'out')/note shape this model exposes to the UI.
    final product = j['product'] as Map<String, dynamic>?;
    final rawType = j['type'] as String?;
    final stockBefore = (j['stockBefore'] as num?)?.toInt();
    final stockAfter = (j['stockAfter'] as num?)?.toInt();
    final isIn = rawType == 'STOCK_IN' ||
        (rawType != 'STOCK_OUT' &&
            stockBefore != null &&
            stockAfter != null &&
            stockAfter >= stockBefore);
    return InventoryMovement(
      item: product?['name'] as String? ??
          j['item'] as String? ??
          j['productName'] as String? ??
          '',
      type: isIn ? 'in' : 'out',
      qty: (j['quantity'] as num?)?.toInt() ?? (j['qty'] as num?)?.toInt() ?? 0,
      note: j['reason'] as String? ?? j['note'] as String? ?? '',
      date: j['createdAt'] as String? ?? j['date'] as String? ?? '',
    );
  }
}

class InventoryReport {
  const InventoryReport({
    required this.products,
    required this.recentMovements,
  });

  final List<InventoryProduct> products;
  final List<InventoryMovement> recentMovements;

  factory InventoryReport.fromJson(Map<String, dynamic> j) => InventoryReport(
        products: (j['products'] as List<dynamic>? ?? [])
            .map((e) => InventoryProduct.fromJson(e as Map<String, dynamic>))
            .toList(),
        // Backend field is `recentLogs`, not `recentMovements`.
        recentMovements: (j['recentLogs'] as List<dynamic>? ??
                j['recentMovements'] as List<dynamic>? ??
                [])
            .map((e) => InventoryMovement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
