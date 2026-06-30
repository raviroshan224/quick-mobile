class SalesSummary {
  const SalesSummary({
    required this.totalRevenue,
    required this.transactionCount,
    required this.avgTicket,
    required this.refundTotal,
    required this.byPaymentMethod,
  });

  final double totalRevenue;
  final int transactionCount;
  final double avgTicket;
  final double refundTotal;
  final Map<String, double> byPaymentMethod; // keys: CASH, FONEPAY, SPLIT

  factory SalesSummary.fromJson(Map<String, dynamic> j) {
    final raw = j['byPaymentMethod'] as Map<String, dynamic>? ?? {};
    return SalesSummary(
      totalRevenue: (j['totalRevenue'] as num? ?? 0).toDouble(),
      transactionCount: j['transactionCount'] as int? ?? 0,
      avgTicket: (j['avgTicket'] as num? ?? 0).toDouble(),
      refundTotal: (j['refundTotal'] as num? ?? 0).toDouble(),
      byPaymentMethod: raw.map((k, v) => MapEntry(k, (v as num).toDouble())),
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

  factory StaffPerformance.fromJson(Map<String, dynamic> j) => StaffPerformance(
        staffId: j['staffId'] as String? ?? '',
        staffName: j['staffName'] as String? ?? '',
        serviceCount: j['serviceCount'] as int? ?? 0,
        totalRevenue: (j['totalRevenue'] as num? ?? 0).toDouble(),
        commission: (j['commission'] as num? ?? 0).toDouble(),
        shiftsCount: j['shiftsCount'] as int? ?? 0,
        totalHours: (j['totalHours'] as num? ?? 0).toDouble(),
      );
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

  factory ServicePopularity.fromJson(Map<String, dynamic> j) => ServicePopularity(
        serviceId: j['serviceId'] as String? ?? '',
        serviceName: j['serviceName'] as String? ?? '',
        bookingCount: j['bookingCount'] as int? ?? 0,
        revenue: (j['revenue'] as num? ?? 0).toDouble(),
      );
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

  factory InventoryProduct.fromJson(Map<String, dynamic> j) => InventoryProduct(
        id: j['id'] as String? ?? '',
        name: j['name'] as String? ?? '',
        stock: j['stock'] as int? ?? 0,
        lowStockThreshold: j['lowStockThreshold'] as int? ?? 0,
        status: j['status'] as String? ?? 'ok',
      );
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

  factory InventoryMovement.fromJson(Map<String, dynamic> j) => InventoryMovement(
        item: j['item'] as String? ?? j['productName'] as String? ?? '',
        type: j['type'] as String? ?? 'out',
        qty: (j['qty'] as num?)?.toInt() ?? (j['quantity'] as num?)?.toInt() ?? 0,
        note: j['note'] as String? ?? '',
        date: j['date'] as String? ?? j['createdAt'] as String? ?? '',
      );
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
        recentMovements: (j['recentMovements'] as List<dynamic>? ?? [])
            .map((e) => InventoryMovement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
