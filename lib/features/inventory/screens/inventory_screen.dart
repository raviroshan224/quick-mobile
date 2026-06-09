import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/inventory_provider.dart';
import '../models/inventory_model.dart';

class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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
        title: const Text('Inventory'),
        bottom: TabBar(
          controller: _tabs,
          tabs: const [Tab(text: 'Products'), Tab(text: 'Low Stock')],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _LogsTab(),
          _LowStockTab(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showMovementDialog(context),
        icon: const Icon(Icons.swap_vert),
        label: const Text('Record Movement'),
      ),
    );
  }

  void _showMovementDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _MovementSheet(),
    );
  }
}

class _LogsTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(inventoryLogsProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (logs) => ListView.builder(
        itemCount: logs.length,
        itemBuilder: (_, i) {
          final log = logs[i];
          final isIn = log.type == InventoryMovementType.stockIn;
          return ListTile(
            leading: Icon(isIn ? Icons.add_circle : Icons.remove_circle, color: isIn ? Colors.green : Colors.red),
            title: Text(log.productName),
            subtitle: Text(log.reason),
            trailing: Text('${isIn ? '+' : '-'}${log.quantity}  →  ${log.stockAfter}',
                style: TextStyle(color: isIn ? Colors.green : Colors.red)),
          );
        },
      ),
    );
  }
}

class _LowStockTab extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lowStockProvider);
    return async.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Error: $e')),
      data: (products) => products.isEmpty
          ? const Center(child: Text('All products are adequately stocked'))
          : ListView.builder(
              itemCount: products.length,
              itemBuilder: (_, i) {
                final p = products[i];
                return ListTile(
                  leading: const Icon(Icons.warning_amber, color: Colors.orange),
                  title: Text(p['name'] as String),
                  subtitle: Text('Threshold: ${p['lowStockThreshold']}'),
                  trailing: Text('${p['stock']} left', style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                );
              },
            ),
    );
  }
}

class _MovementSheet extends StatelessWidget {
  const _MovementSheet();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Record Stock Movement', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 16),
          // TODO: product picker, type selector, quantity, reason fields
          const Text('Form fields — implement with product picker and reason field'),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
