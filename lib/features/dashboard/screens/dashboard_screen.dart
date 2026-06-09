import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardSummaryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (summary) => RefreshIndicator(
          onRefresh: () async => ref.invalidate(dashboardSummaryProvider),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatCard(label: "Today's Sales", value: 'NPR ${summary.todaySales.toStringAsFixed(0)}'),
              _StatCard(label: 'Customers Served', value: '${summary.customersServedToday}'),
              _StatCard(label: 'Transactions', value: '${summary.todayTransactionCount}'),
              _StatCard(label: "Today's Tips", value: 'NPR ${summary.todayTips.toStringAsFixed(0)}'),
              if (summary.lowStockAlerts.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Low Stock Alerts (${summary.lowStockAlerts.length})', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.orange)),
                ...summary.lowStockAlerts.map((p) => ListTile(
                  leading: const Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text(p.name),
                  trailing: Text('${p.stock} left', style: const TextStyle(color: Colors.orange)),
                )),
              ],
              if (summary.topStaff.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text('Top Staff Today', style: Theme.of(context).textTheme.titleMedium),
                ...summary.topStaff.asMap().entries.map((e) => ListTile(
                  leading: CircleAvatar(child: Text('${e.key + 1}')),
                  title: Text(e.value.staffName),
                  trailing: Text('NPR ${e.value.totalSales.toStringAsFixed(0)}'),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(label, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
        trailing: Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
