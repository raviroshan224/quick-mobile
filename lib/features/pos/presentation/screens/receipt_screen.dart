import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../transactions/domain/transaction_models.dart';
import '../../../transactions/presentation/providers/transactions_provider.dart';

class ReceiptScreen extends ConsumerWidget {
  const ReceiptScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txId = ref.watch(lastTransactionIdProvider);

    if (txId == null) return const _StaticReceipt();

    final txAsync = ref.watch(transactionDetailProvider(txId));
    return txAsync.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (e, st) => const _StaticReceipt(),
      data: (tx) => _ReceiptBody(tx: tx),
    );
  }
}

// ─── Real transaction receipt ─────────────────────────────────────────────────

class _ReceiptBody extends StatelessWidget {
  const _ReceiptBody({required this.tx});
  final Transaction tx;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _fmtDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  String _paymentLabel(TxPaymentMethod m) => switch (m) {
        TxPaymentMethod.fonepay => 'Fonepay',
        TxPaymentMethod.split => 'Split',
        _ => 'Cash',
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 420,
            padding: const EdgeInsets.all(AppSpacing.xxxl),
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.xlBR,
              boxShadow: AppShadows.elevated,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.successLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_rounded,
                      color: AppColors.success, size: 36),
                ),
                const SizedBox(height: AppSpacing.lg),
                Text('Payment Successful',
                    style: AppTextStyles.headlineLarge,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.sm),
                Text(tx.displayId,
                    style: AppTextStyles.bodyMedium,
                    textAlign: TextAlign.center),
                const SizedBox(height: AppSpacing.xxxl),
                const Divider(),
                const SizedBox(height: AppSpacing.lg),
                _row('Date', _fmtDate(tx.createdAt)),
                _row('Customer', tx.displayName),
                _row('Payment', _paymentLabel(tx.paymentMethod)),
                if (tx.subtotal != null && tx.subtotal != tx.total)
                  _row('Subtotal',
                      'Rs ${tx.subtotal!.toStringAsFixed(2)}'),
                if ((tx.discountAmount ?? 0) > 0)
                  _row('Discount',
                      '- Rs ${tx.discountAmount!.toStringAsFixed(2)}'),
                if ((tx.tipAmount ?? 0) > 0)
                  _row('Tip', 'Rs ${tx.tipAmount!.toStringAsFixed(2)}'),
                _row('Total', 'Rs ${tx.total.toStringAsFixed(2)}',
                    bold: true),
                _row('Status', 'Completed'),
                const SizedBox(height: AppSpacing.xxxl),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.print_outlined, size: 16),
                        label: const Text('Print Receipt'),
                        onPressed: () {},
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.point_of_sale_rounded,
                            size: 16),
                        label: const Text('New Sale'),
                        onPressed: () => context.go(AppRoutes.pos),
                        style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                TextButton(
                  onPressed: () => context.go(AppRoutes.dashboard),
                  child: const Text('Back to Dashboard'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            const Spacer(),
            Text(value,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight:
                      bold ? FontWeight.w700 : FontWeight.w600,
                )),
          ],
        ),
      );
}

// ─── Fallback when no transaction ID available ────────────────────────────────

class _StaticReceipt extends StatelessWidget {
  const _StaticReceipt();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          width: 420,
          padding: const EdgeInsets.all(AppSpacing.xxxl),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.xlBR,
            boxShadow: AppShadows.elevated,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: const BoxDecoration(
                  color: AppColors.successLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    color: AppColors.success, size: 36),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text('Payment Successful',
                  style: AppTextStyles.headlineLarge,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.sm),
              Text('Transaction completed',
                  style: AppTextStyles.bodyMedium,
                  textAlign: TextAlign.center),
              const SizedBox(height: AppSpacing.xxxl),
              const Divider(),
              const SizedBox(height: AppSpacing.lg),
              _receiptRow('Status', 'Completed'),
              const SizedBox(height: AppSpacing.xxxl),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Print Receipt'),
                      onPressed: () {},
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: FilledButton.icon(
                      icon:
                          const Icon(Icons.point_of_sale_rounded, size: 16),
                      label: const Text('New Sale'),
                      onPressed: () => context.go(AppRoutes.pos),
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.md),
              TextButton(
                onPressed: () => context.go(AppRoutes.dashboard),
                child: const Text('Back to Dashboard'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _receiptRow(String label, String value) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            const Spacer(),
            Text(value,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );
}
