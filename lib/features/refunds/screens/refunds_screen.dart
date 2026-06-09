import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/refunds_provider.dart';

class RefundsScreen extends ConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(refundsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Refunds')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (refunds) => refunds.isEmpty
            ? const Center(child: Text('No refunds yet'))
            : ListView.builder(
                itemCount: refunds.length,
                itemBuilder: (_, i) {
                  final r = refunds[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.undo, size: 18)),
                    title: Text('NPR ${r.amount.toStringAsFixed(0)} — Cash Refund'),
                    subtitle: Text(r.reason),
                    trailing: Text(
                      '${r.createdAt.day}/${r.createdAt.month}/${r.createdAt.year}',
                      style: TextStyle(color: Colors.grey[600], fontSize: 12),
                    ),
                  );
                },
              ),
      ),
    );
  }
}

Future<void> showIssueRefundDialog(BuildContext context, WidgetRef ref, String transactionId, double transactionTotal) {
  final reasonCtrl = TextEditingController();
  return showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Issue Refund'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Amount: NPR ${transactionTotal.toStringAsFixed(0)} (cash only)'),
          const SizedBox(height: 12),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Reason *', hintText: 'Required — explain why'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            if (reasonCtrl.text.trim().isEmpty) return;
            Navigator.pop(ctx);
            await ref.read(refundNotifierProvider.notifier).issueRefund(
              transactionId: transactionId,
              reason: reasonCtrl.text.trim(),
            );
          },
          child: const Text('Confirm Refund'),
        ),
      ],
    ),
  );
}
