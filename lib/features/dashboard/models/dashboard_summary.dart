class LowStockProduct {
  final String id;
  final String name;
  final int stock;
  final int lowStockThreshold;

  const LowStockProduct({required this.id, required this.name, required this.stock, required this.lowStockThreshold});

  factory LowStockProduct.fromJson(Map<String, dynamic> j) => LowStockProduct(
        id: j['id'] as String,
        name: j['name'] as String,
        stock: (j['stock'] as num).toInt(),
        lowStockThreshold: (j['lowStockThreshold'] as num).toInt(),
      );
}

class TopStaffEntry {
  final String? staffId;
  final String staffName;
  final double totalSales;

  const TopStaffEntry({this.staffId, required this.staffName, required this.totalSales});

  factory TopStaffEntry.fromJson(Map<String, dynamic> j) {
    return TopStaffEntry(
      staffId: j['staffId'] as String?,
      staffName: j['name'] as String? ?? 'Unknown',
      totalSales: (j['totalSales'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class DashboardSummary {
  final double todaySales;
  final double todayTips;
  final int todayTransactionCount;
  final int customersServedToday;
  final List<TopStaffEntry> topStaff;
  final List<LowStockProduct> lowStockAlerts;
  final bool cashDrawerOpen;
  final double? cashDrawerBalance;

  const DashboardSummary({
    required this.todaySales,
    required this.todayTips,
    required this.todayTransactionCount,
    required this.customersServedToday,
    required this.topStaff,
    required this.lowStockAlerts,
    required this.cashDrawerOpen,
    this.cashDrawerBalance,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) {
    final cashDrawer = j['cashDrawer'] as Map<String, dynamic>?;
    return DashboardSummary(
      todaySales: (j['todaySales'] as num).toDouble(),
      todayTips: (j['todayTips'] as num).toDouble(),
      todayTransactionCount: j['transactionCount'] as int,
      customersServedToday: j['customersServed'] as int,
      topStaff: (j['topStaff'] as List)
          .map((e) => TopStaffEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      lowStockAlerts: (j['lowStock'] as List)
          .map((e) => LowStockProduct.fromJson(e as Map<String, dynamic>))
          .toList(),
      cashDrawerOpen: cashDrawer?['isOpen'] as bool? ?? false,
      cashDrawerBalance: (cashDrawer?['currentBalance'] as num?)?.toDouble(),
    );
  }
}
