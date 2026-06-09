import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/cash_drawer_provider.dart';
import '../models/cash_drawer_model.dart';

class CashDrawerScreen extends ConsumerWidget {
  const CashDrawerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(currentDrawerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Cash Drawer')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (drawer) => drawer == null
            ? _NoDrawerView(onOpen: () => _showOpenDrawerDialog(context, ref))
            : _DrawerOpenView(drawer: drawer, ref: ref),
      ),
    );
  }

  void _showOpenDrawerDialog(BuildContext context, WidgetRef ref) {
    final ctrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Cash Drawer'),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: 'Opening Balance (NPR)', prefixText: 'NPR '),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(ctrl.text);
              if (amount == null) return;
              Navigator.pop(ctx);
              await ref.read(cashDrawerNotifierProvider.notifier).open(amount);
            },
            child: const Text('Open'),
          ),
        ],
      ),
    );
  }
}

class _NoDrawerView extends StatelessWidget {
  final VoidCallback onOpen;
  const _NoDrawerView({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.point_of_sale, size: 64, color: Colors.grey),
          const SizedBox(height: 16),
          const Text('No drawer is open'),
          const SizedBox(height: 12),
          FilledButton.icon(onPressed: onOpen, icon: const Icon(Icons.lock_open), label: const Text('Open Drawer')),
        ],
      ),
    );
  }
}

class _DrawerOpenView extends StatelessWidget {
  final CashDrawer drawer;
  final WidgetRef ref;
  const _DrawerOpenView({required this.drawer, required this.ref});

  @override
  Widget build(BuildContext context) {
    final inTotal = drawer.movements.where((m) => m.type == CashMovementType.cashIn).fold(0.0, (s, m) => s + m.amount);
    final outTotal = drawer.movements.where((m) => m.type == CashMovementType.cashOut).fold(0.0, (s, m) => s + m.amount);
    final balance = drawer.openBalance + inTotal - outTotal;

    return Column(
      children: [
        Container(
          color: Colors.green.shade50,
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.point_of_sale, color: Colors.green),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Current Balance', style: TextStyle(color: Colors.grey)),
                Text('NPR ${balance.toStringAsFixed(0)}', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              ]),
              const Spacer(),
              FilledButton(onPressed: () {}, child: const Text('Close Drawer')),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => _showMovementDialog(context, 'IN'), icon: const Icon(Icons.add), label: const Text('Payment In'))),
              const SizedBox(width: 8),
              Expanded(child: OutlinedButton.icon(onPressed: () => _showMovementDialog(context, 'OUT'), icon: const Icon(Icons.remove), label: const Text('Payment Out'))),
            ],
          ),
        ),
        const Divider(),
        Expanded(
          child: ListView.builder(
            itemCount: drawer.movements.length,
            itemBuilder: (_, i) {
              final m = drawer.movements[i];
              final isIn = m.type == CashMovementType.cashIn;
              return ListTile(
                leading: Icon(isIn ? Icons.add_circle : Icons.remove_circle, color: isIn ? Colors.green : Colors.red),
                title: Text(m.reason),
                trailing: Text('${isIn ? '+' : '-'} NPR ${m.amount.toStringAsFixed(0)}',
                    style: TextStyle(color: isIn ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                subtitle: Text('${m.createdAt.hour}:${m.createdAt.minute.toString().padLeft(2, '0')}'),
              );
            },
          ),
        ),
      ],
    );
  }

  void _showMovementDialog(BuildContext context, String type) {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(type == 'IN' ? 'Payment In' : 'Payment Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: amountCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (NPR)')),
            const SizedBox(height: 8),
            TextField(controller: reasonCtrl, decoration: const InputDecoration(labelText: 'Reason *'), maxLines: 2),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () async {
              final amount = double.tryParse(amountCtrl.text);
              if (amount == null || reasonCtrl.text.trim().isEmpty) return;
              Navigator.pop(ctx);
              await ref.read(cashDrawerNotifierProvider.notifier).addMovement(
                drawerId: drawer.id, type: type, amount: amount, reason: reasonCtrl.text.trim(),
              );
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }
}
