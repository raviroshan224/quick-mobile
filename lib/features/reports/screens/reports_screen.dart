import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/reports_provider.dart';

class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabs: const [
            Tab(text: 'Sales'),
            Tab(text: 'Staff'),
            Tab(text: 'Services'),
            Tab(text: 'Inventory'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [
          _SalesReportTab(),
          _StaffReportTab(),
          _ServicesReportTab(),
          _InventoryReportTab(),
        ],
      ),
    );
  }
}

class _SalesReportTab extends ConsumerWidget {
  const _SalesReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(salesSummaryProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (s) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ReportTile('Total Revenue', 'NPR ${s['totalRevenue']?.toStringAsFixed(0) ?? '0'}'),
          _ReportTile('Transactions', '${s['totalTransactions'] ?? 0}'),
          _ReportTile('Tips Collected', 'NPR ${s['totalTips']?.toStringAsFixed(0) ?? '0'}'),
          _ReportTile('Discounts Given', 'NPR ${s['totalDiscounts']?.toStringAsFixed(0) ?? '0'}'),
          _ReportTile('Avg. Transaction', 'NPR ${s['averageTransaction']?.toStringAsFixed(0) ?? '0'}'),
        ],
      ),
    );
  }
}

class _StaffReportTab extends ConsumerWidget {
  const _StaffReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffPerformanceProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final entry = list[i] as Map<String, dynamic>;
          final staff = entry['staff'] as Map<String, dynamic>?;
          final user = staff?['user'] as Map<String, dynamic>?;
          final name = user != null ? '${user['firstName']} ${user['lastName']}' : 'Unknown';
          return ListTile(
            leading: CircleAvatar(child: Text(name.isNotEmpty ? name[0] : '?')),
            title: Text(name),
            subtitle: Text('${entry['serviceCount'] ?? 0} services'),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('NPR ${(entry['totalSales'] as num?)?.toStringAsFixed(0) ?? '0'}'),
                Text('Comm: NPR ${(entry['totalCommission'] as num?)?.toStringAsFixed(0) ?? '0'}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ServicesReportTab extends ConsumerWidget {
  const _ServicesReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(servicePopularityProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (list) => ListView.builder(
        itemCount: list.length,
        itemBuilder: (_, i) {
          final entry = list[i] as Map<String, dynamic>;
          final service = entry['service'] as Map<String, dynamic>?;
          return ListTile(
            title: Text(service?['name'] as String? ?? 'Unknown'),
            subtitle: Text('${entry['count'] ?? 0} bookings'),
            trailing: Text('NPR ${(entry['totalRevenue'] as num?)?.toStringAsFixed(0) ?? '0'}'),
          );
        },
      ),
    );
  }
}

class _InventoryReportTab extends ConsumerWidget {
  const _InventoryReportTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inventoryReportProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (report) {
        final lowStock = (report['lowStock'] as List?) ?? [];
        final products = (report['products'] as List?) ?? [];
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (lowStock.isNotEmpty) ...[
              Text('Low Stock (${lowStock.length})', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
              ...lowStock.map((p) => ListTile(
                    dense: true,
                    leading: const Icon(Icons.warning_amber, color: Colors.orange, size: 18),
                    title: Text((p as Map<String, dynamic>)['name'] as String),
                    trailing: Text('${p['stock']} / ${p['lowStockThreshold']}'),
                  )),
              const Divider(),
            ],
            Text('All Products (${products.length})', style: const TextStyle(fontWeight: FontWeight.bold)),
            ...products.map((p) => ListTile(
                  dense: true,
                  title: Text((p as Map<String, dynamic>)['name'] as String),
                  subtitle: Text((p['sku'] as String?) ?? ''),
                  trailing: Text('${p['stock']} in stock'),
                )),
          ],
        );
      },
    );
  }
}

class _ReportTile extends StatelessWidget {
  final String label;
  final String value;
  const _ReportTile(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label, style: TextStyle(color: Colors.grey[600])),
        trailing: Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      ),
    );
  }
}
