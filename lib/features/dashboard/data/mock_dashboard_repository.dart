import '../../staff/domain/staff_models.dart';
import '../../inventory/domain/inventory_models.dart';

class TopStaffEntry {
  const TopStaffEntry({required this.staff, required this.totalSales, required this.serviceCount});
  final StaffModel staff;
  final double totalSales;
  final int serviceCount;
}

class DashboardSummary {
  const DashboardSummary({
    required this.todaySales,
    required this.todayTips,
    required this.todayTransactionCount,
    required this.customersServedToday,
    required this.topStaff,
    required this.lowStockAlerts,
    required this.cashDrawerOpen,
    required this.cashDrawerBalance,
  });

  final double todaySales;
  final double todayTips;
  final int todayTransactionCount;
  final int customersServedToday;
  final List<TopStaffEntry> topStaff;
  final List<ProductModel> lowStockAlerts;
  final bool cashDrawerOpen;
  final double? cashDrawerBalance;
}

class MockDashboardRepository {
  Future<DashboardSummary> getSummary() async {
    await Future.delayed(const Duration(milliseconds: 400));
    return DashboardSummary(
      todaySales: 34800,
      todayTips: 1800,
      todayTransactionCount: 18,
      customersServedToday: 14,
      topStaff: [
        TopStaffEntry(
          staff: const StaffModel(id: 'st-01', userId: 'u-st-01', firstName: 'Priya', lastName: 'Thapa', commissionRate: 15),
          totalSales: 12400, serviceCount: 6,
        ),
        TopStaffEntry(
          staff: const StaffModel(id: 'st-03', userId: 'u-st-03', firstName: 'Sita', lastName: 'Gurung', commissionRate: 10),
          totalSales: 9800, serviceCount: 5,
        ),
        TopStaffEntry(
          staff: const StaffModel(id: 'st-04', userId: 'u-st-04', firstName: 'Anil', lastName: 'Rai', commissionRate: 15),
          totalSales: 7200, serviceCount: 4,
        ),
        TopStaffEntry(
          staff: const StaffModel(id: 'st-02', userId: 'u-st-02', firstName: 'Rina', lastName: 'Shrestha', commissionRate: 12),
          totalSales: 5400, serviceCount: 3,
        ),
      ],
      lowStockAlerts: const [
        ProductModel(id: 'p-05', name: 'Face Wash 100ml', price: 380, stock: 2, lowStockThreshold: 8),
        ProductModel(id: 'p-03', name: 'OPI Nail Polish', price: 900, stock: 3, lowStockThreshold: 5),
        ProductModel(id: 'p-02', name: 'Loreal Shampoo 500ml', price: 680, stock: 8, lowStockThreshold: 10),
      ],
      cashDrawerOpen: true,
      cashDrawerBalance: 28400,
    );
  }
}
