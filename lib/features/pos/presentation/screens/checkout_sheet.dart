import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/pos_models.dart';
import '../providers/cart_provider.dart';

class CheckoutSheet extends HookConsumerWidget {
  const CheckoutSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);
    final method = useState(PaymentMethod.cash);
    final splitCash = useTextEditingController();
    final splitFonepay = useTextEditingController();
    final isProcessing = useState(false);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(top: AppSpacing.md),
                decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: AppRadius.pillBR),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
              child: Row(
                children: [
                  Text('Checkout', style: AppTextStyles.headlineMedium),
                  const Spacer(),
                  Text(
                    'NPR ${cart.total.toStringAsFixed(0)}',
                    style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.primary, fontSize: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: AppSpacing.lg),
            Expanded(
              child: ListView(
                controller: sc,
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg),
                children: [
                  // Order summary
                  Text('Order Summary',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  ...cart.items.map((item) => Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Expanded(
                                child: Text(item.name,
                                    style: AppTextStyles.bodyMedium)),
                            Text(
                              'NPR ${item.totalPrice.toStringAsFixed(0)}',
                              style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textPrimary,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      )),
                  if (cart.discountAmount > 0)
                    _SummaryRow(
                        label: 'Discount',
                        value:
                            '- NPR ${cart.discountAmount.toStringAsFixed(0)}',
                        color: AppColors.success),
                  if (cart.tipAmount > 0)
                    _SummaryRow(
                        label: 'Tip',
                        value:
                            'NPR ${cart.tipAmount.toStringAsFixed(0)}'),
                  const Divider(height: AppSpacing.lg),
                  _SummaryRow(
                    label: 'Total',
                    value: 'NPR ${cart.total.toStringAsFixed(0)}',
                    bold: true,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  // Payment method
                  Text('Payment Method',
                      style: AppTextStyles.titleMedium),
                  const SizedBox(height: AppSpacing.sm),
                  _PaymentMethodSelector(
                      selected: method.value,
                      onChanged: (m) => method.value = m),
                  const SizedBox(height: AppSpacing.md),
                  // Fonepay QR
                  if (method.value == PaymentMethod.fonepay)
                    _FonepayQRWidget(amount: cart.total),
                  // Split payment inputs
                  if (method.value == PaymentMethod.split)
                    _SplitPaymentWidget(
                      total: cart.total,
                      cashCtrl: splitCash,
                      fonepayCtrl: splitFonepay,
                    ),
                  const SizedBox(height: AppSpacing.xxxl),
                ],
              ),
            ),
            // Confirm button
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  0,
                  AppSpacing.lg,
                  AppSpacing.lg),
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: isProcessing.value
                      ? null
                      : () => _confirm(
                          context, ref, method.value, isProcessing),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.md),
                  ),
                  child: isProcessing.value
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(
                          method.value == PaymentMethod.fonepay
                              ? 'Confirm Payment'
                              : 'Collect  NPR ${cart.total.toStringAsFixed(0)}',
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirm(BuildContext context, WidgetRef ref,
      PaymentMethod method, ValueNotifier<bool> isProcessing) async {
    isProcessing.value = true;
    await Future.delayed(const Duration(milliseconds: 800));
    ref.read(cartProvider.notifier).clear();
    if (context.mounted) {
      Navigator.pop(context); // close sheet
      context.go(AppRoutes.posReceipt);
    }
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow(
      {required this.label,
      required this.value,
      this.color,
      this.bold = false});
  final String label;
  final String value;
  final Color? color;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(label,
              style: bold
                  ? AppTextStyles.titleMedium
                  : AppTextStyles.bodyMedium),
          const Spacer(),
          Text(value,
              style: (bold
                      ? AppTextStyles.titleMedium
                      : AppTextStyles.bodyMedium)
                  .copyWith(
                      color: color ?? AppColors.textPrimary,
                      fontWeight: bold
                          ? FontWeight.w700
                          : FontWeight.w600)),
        ],
      ),
    );
  }
}

class _PaymentMethodSelector extends StatelessWidget {
  const _PaymentMethodSelector(
      {required this.selected, required this.onChanged});
  final PaymentMethod selected;
  final ValueChanged<PaymentMethod> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: PaymentMethod.values.map((m) {
        final isSelected = m == selected;
        final color = switch (m) {
          PaymentMethod.cash => AppColors.cashColor,
          PaymentMethod.fonepay => AppColors.fonepayColor,
          PaymentMethod.split => AppColors.splitColor,
        };
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: AppSpacing.sm),
            child: GestureDetector(
              onTap: () => onChanged(m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                    vertical: AppSpacing.md, horizontal: AppSpacing.sm),
                decoration: BoxDecoration(
                  color: isSelected
                      ? color.withValues(alpha: 0.1)
                      : AppColors.surfaceVariant,
                  borderRadius: AppRadius.lgBR,
                  border: Border.all(
                      color: isSelected ? color : AppColors.divider,
                      width: isSelected ? 2 : 1),
                ),
                child: Column(
                  children: [
                    Icon(
                      switch (m) {
                        PaymentMethod.cash =>
                          Icons.payments_outlined,
                        PaymentMethod.fonepay =>
                          Icons.qr_code_rounded,
                        PaymentMethod.split =>
                          Icons.call_split_rounded,
                      },
                      color: isSelected ? color : AppColors.textSecondary,
                      size: 22,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: isSelected
                            ? color
                            : AppColors.textSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _FonepayQRWidget extends StatelessWidget {
  const _FonepayQRWidget({required this.amount});
  final double amount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.fonepayColor.withValues(alpha: 0.06),
        borderRadius: AppRadius.lgBR,
        border: Border.all(
            color: AppColors.fonepayColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                    color: AppColors.fonepayColor,
                    borderRadius: AppRadius.smBR),
                child: const Icon(Icons.qr_code_2_rounded,
                    color: Colors.white, size: 16),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text('Fonepay QR',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.fonepayColor)),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Container(
            width: 160,
            height: 160,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: AppRadius.lgBR,
              border: Border.all(color: AppColors.divider),
            ),
            child: const Icon(Icons.qr_code_2_rounded,
                size: 120, color: AppColors.textTertiary),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'NPR ${amount.toStringAsFixed(0)}',
            style: AppTextStyles.kpiValue.copyWith(
                color: AppColors.fonepayColor, fontSize: 24),
          ),
          const SizedBox(height: 4),
          Text('Scan with Fonepay app',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}

class _SplitPaymentWidget extends HookWidget {
  const _SplitPaymentWidget({
    required this.total,
    required this.cashCtrl,
    required this.fonepayCtrl,
  });
  final double total;
  final TextEditingController cashCtrl;
  final TextEditingController fonepayCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: AppRadius.lgBR,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Split Payment',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.primary)),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: cashCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Cash (NPR)',
                    prefixIcon: Icon(Icons.payments_outlined),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: TextField(
                  controller: fonepayCtrl,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Fonepay (NPR)',
                    prefixIcon: Icon(Icons.qr_code_rounded),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Total: NPR ${total.toStringAsFixed(0)}',
            style: AppTextStyles.labelMedium
                .copyWith(color: AppColors.primary),
          ),
        ],
      ),
    );
  }
}
