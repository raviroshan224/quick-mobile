import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/cash_drawer/domain/cash_drawer_models.dart';
import '../../../../features/cash_drawer/presentation/providers/cash_drawer_provider.dart';

class DrawersScreen extends ConsumerWidget {
  const DrawersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerAsync = ref.watch(cashDrawerNotifierProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => context.go(AppRoutes.more),
        ),
        title: const Text('Drawers',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        centerTitle: true,
      ),
      body: drawerAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (session) => session == null
            ? _ClosedState(ref: ref)
            : _OpenState(session: session, ref: ref),
      ),
    );
  }
}

// ─── Closed state ─────────────────────────────────────────────────────────────

class _ClosedState extends StatelessWidget {
  const _ClosedState({required this.ref});
  final WidgetRef ref;

  Future<void> _openDrawer(BuildContext context) async {
    final amountCtrl = TextEditingController();
    final notesCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Open Drawer'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Opening Balance (NPR)',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notes (optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Open')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    try {
      await ref
          .read(cashDrawerNotifierProvider.notifier)
          .openDrawer(amount, notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim());
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.point_of_sale_outlined,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 16),
          const Text('No open drawer',
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w500)),
          const SizedBox(height: 8),
          const Text('Open a cash drawer to start',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => _openDrawer(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
            ),
            child: const Text('Open Drawer'),
          ),
        ],
      ),
    );
  }
}

// ─── Open state ───────────────────────────────────────────────────────────────

class _OpenState extends StatelessWidget {
  const _OpenState({required this.session, required this.ref});
  final CashDrawerSession session;
  final WidgetRef ref;

  Future<void> _showMovementDialog(
      BuildContext context, CashMovementType type) async {
    final isIn = type == CashMovementType.cashIn;
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(isIn ? 'Pay In' : 'Pay Out'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: '${isIn ? 'Amount In' : 'Amount Out'} (NPR)',
                border: const OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(isIn ? 'Pay In' : 'Pay Out')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;
    if (amount <= 0) return;
    try {
      await ref.read(cashDrawerNotifierProvider.notifier).recordMovement(
            type: type,
            amount: amount,
            reason: reasonCtrl.text.trim().isEmpty
                ? (isIn ? 'Cash in' : 'Cash out')
                : reasonCtrl.text.trim(),
          );
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Balance card
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Current Balance',
                  style: TextStyle(
                      color: AppColors.textTertiary, fontSize: 13)),
              const SizedBox(height: 8),
              Text(
                'NPR ${session.currentBalance.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _Chip(
                      label:
                          '+ NPR ${session.totalIn.toStringAsFixed(0)} in'),
                  const SizedBox(width: 8),
                  _Chip(
                      label:
                          '- NPR ${session.totalOut.toStringAsFixed(0)} out'),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        // Action buttons
        Row(
          children: [
            Expanded(
              child: _ActionBtn(
                label: 'Pay In',
                icon: Icons.add,
                onTap: () =>
                    _showMovementDialog(context, CashMovementType.cashIn),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionBtn(
                label: 'Pay Out',
                icon: Icons.remove,
                onTap: () =>
                    _showMovementDialog(context, CashMovementType.cashOut),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        const Text('Movements',
            style: TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        ...session.movements.map((m) => _MovementRow(entry: m)),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: AppColors.textTertiary, fontSize: 12)),
    );
  }
}

class _ActionBtn extends StatelessWidget {
  const _ActionBtn(
      {required this.label,
      required this.icon,
      required this.onTap});
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18),
            const SizedBox(width: 6),
            Text(label,
                style: const TextStyle(
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.entry});
  final CashMovementEntry entry;

  @override
  Widget build(BuildContext context) {
    final isIn = entry.isIn;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isIn
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isIn
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 16,
              color: isIn
                  ? AppColors.success
                  : AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.reason,
                    style: const TextStyle(fontSize: 14)),
                Text(entry.timeLabel,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Text(
            '${isIn ? '+' : '-'} NPR ${entry.amount.toStringAsFixed(0)}',
            style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: isIn
                    ? AppColors.success
                    : AppColors.danger),
          ),
        ],
      ),
    );
  }
}
