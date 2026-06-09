import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/cash_drawer_models.dart';
import '../providers/cash_drawer_provider.dart';

class CashDrawerScreen extends ConsumerWidget {
  const CashDrawerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final drawerAsync = ref.watch(currentDrawerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: drawerAsync.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (session) => session == null
            ? _ClosedDrawer()
            : _OpenDrawer(session: session),
      ),
    );
  }
}

class _ClosedDrawer extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.point_of_sale_outlined,
              size: 64, color: AppColors.textTertiary),
          const SizedBox(height: AppSpacing.lg),
          Text('Cash Drawer is Closed',
              style: AppTextStyles.headlineLarge),
          const SizedBox(height: AppSpacing.sm),
          Text('Open the drawer to start accepting cash payments.',
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: AppSpacing.xxl),
          FilledButton.icon(
            icon: const Icon(Icons.lock_open_rounded),
            label: const Text('Open Cash Drawer'),
            onPressed: () {},
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.xl, vertical: AppSpacing.md)),
          ),
        ],
      ),
    );
  }
}

class _OpenDrawer extends HookConsumerWidget {
  const _OpenDrawer({required this.session});
  final CashDrawerSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        // Header
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Cash Drawer',
                        style: AppTextStyles.headlineMedium),
                    Row(
                      children: [
                        const Icon(Icons.circle,
                            size: 8, color: AppColors.success),
                        const SizedBox(width: 4),
                        Text('Open',
                            style: AppTextStyles.labelMedium
                                .copyWith(color: AppColors.success)),
                      ],
                    ),
                  ],
                ),
              ),
              _BalanceChip(
                  label: 'Current Balance',
                  value:
                      'NPR ${session.currentBalance.toStringAsFixed(0)}',
                  color: AppColors.success),
              const SizedBox(width: AppSpacing.md),
              _BalanceChip(
                  label: 'Total In',
                  value: 'NPR ${session.totalIn.toStringAsFixed(0)}',
                  color: AppColors.primary),
              const SizedBox(width: AppSpacing.md),
              _BalanceChip(
                  label: 'Total Out',
                  value: 'NPR ${session.totalOut.toStringAsFixed(0)}',
                  color: AppColors.danger),
            ],
          ),
        ),
        // Actions row
        Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              _ActionButton(
                icon: Icons.add_rounded,
                label: 'Pay In',
                color: AppColors.success,
                onTap: () => _showMovementSheet(context, ref, isIn: true),
              ),
              const SizedBox(width: AppSpacing.md),
              _ActionButton(
                icon: Icons.remove_rounded,
                label: 'Pay Out',
                color: AppColors.danger,
                onTap: () => _showMovementSheet(context, ref, isIn: false),
              ),
              const Spacer(),
              OutlinedButton.icon(
                icon: const Icon(Icons.lock_rounded, size: 16),
                label: const Text('Close Drawer'),
                onPressed: () {},
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: BorderSide(color: AppColors.danger)),
              ),
            ],
          ),
        ),
        // Movements list
        Expanded(
          child: session.movements.isEmpty
              ? const EmptyState(
                  icon: Icons.history_rounded,
                  title: 'No movements yet')
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg),
                  itemCount: session.movements.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (_, i) =>
                      _MovementTile(entry: session.movements[i]),
                ),
        ),
      ],
    );
  }

  void _showMovementSheet(BuildContext context, WidgetRef ref,
      {required bool isIn}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MovementSheet(isIn: isIn),
    );
  }
}

class _BalanceChip extends StatelessWidget {
  const _BalanceChip(
      {required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: AppRadius.lgBR,
          border: Border.all(color: color.withValues(alpha: 0.25))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  fontSize: 11,
                  color: color,
                  fontWeight: FontWeight.w500)),
          Text(value,
              style: TextStyle(
                  fontSize: 16,
                  color: color,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.md)),
    );
  }
}

class _MovementTile extends StatelessWidget {
  const _MovementTile({required this.entry});
  final CashMovementEntry entry;

  @override
  Widget build(BuildContext context) {
    final isIn = entry.type == CashMovementType.cashIn;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: isIn ? AppColors.successLight : AppColors.dangerLight,
            shape: BoxShape.circle),
        child: Icon(
          isIn ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
          color: isIn ? AppColors.success : AppColors.danger,
          size: 18,
        ),
      ),
      title: Text(entry.reason, style: AppTextStyles.titleMedium),
      subtitle: Text(entry.type.name, style: AppTextStyles.bodySmall),
      trailing: Text(
        '${isIn ? '+' : '-'} NPR ${entry.amount.toStringAsFixed(0)}',
        style: TextStyle(
            color: isIn ? AppColors.success : AppColors.danger,
            fontWeight: FontWeight.w700,
            fontSize: 15),
      ),
    );
  }
}

class _MovementSheet extends HookWidget {
  const _MovementSheet({required this.isIn});
  final bool isIn;

  @override
  Widget build(BuildContext context) {
    final amountCtrl = useTextEditingController();
    final reasonCtrl = useTextEditingController();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(isIn ? 'Cash Pay In' : 'Cash Pay Out',
              style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: amountCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                labelText: 'Amount *', prefixText: 'NPR '),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: reasonCtrl,
            decoration: const InputDecoration(labelText: 'Reason *'),
          ),
          const SizedBox(height: AppSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context),
              style: FilledButton.styleFrom(
                  backgroundColor:
                      isIn ? AppColors.success : AppColors.danger),
              child: Text(isIn ? 'Confirm Pay In' : 'Confirm Pay Out'),
            ),
          ),
        ],
      ),
    );
  }
}
