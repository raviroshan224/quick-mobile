class LowStockProduct {
  final String id;
  final String name;
  final int stock;
  final int lowStockThreshold;

  const LowStockProduct({required this.id, required this.name, required this.stock, required this.lowStockThreshold});

  factory LowStockProduct.fromJson(Map<String, dynamic> j) => LowStockProduct(
        id: j['id'] as String,
        name: j['name'] as String,
        stock: j['stock'] as int,
        lowStockThreshold: j['lowStockThreshold'] as int,
      );
}

class TopStaffEntry {
  final String? staffId;
  final String staffName;
  final double totalSales;

  const TopStaffEntry({this.staffId, required this.staffName, required this.totalSales});

  factory TopStaffEntry.fromJson(Map<String, dynamic> j) {
    final staff = j['staff'] as Map<String, dynamic>?;
    final user = staff?['user'] as Map<String, dynamic>?;
    return TopStaffEntry(
      staffId: staff?['id'] as String?,
      staffName: user != null ? '${user['firstName']} ${user['lastName']}' : 'Unknown',
      totalSales: (j['totalSales'] as num).toDouble(),
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

  const DashboardSummary({
    required this.todaySales,
    required this.todayTips,
    required this.todayTransactionCount,
    required this.customersServedToday,
    required this.topStaff,
    required this.lowStockAlerts,
    required this.cashDrawerOpen,
  });

  factory DashboardSummary.fromJson(Map<String, dynamic> j) => DashboardSummary(
        todaySales: (j['todaySales'] as num).toDouble(),
        todayTips: (j['todayTips'] as num).toDouble(),
        todayTransactionCount: j['todayTransactionCount'] as int,
        customersServedToday: j['customersServedToday'] as int,
        topStaff: (j['topStaff'] as List).map((e) => TopStaffEntry.fromJson(e as Map<String, dynamic>)).toList(),
        lowStockAlerts: (j['lowStockAlerts'] as List).map((e) => LowStockProduct.fromJson(e as Map<String, dynamic>)).toList(),
        cashDrawerOpen: j['cashDrawerOpen'] as bool,
      );
}
