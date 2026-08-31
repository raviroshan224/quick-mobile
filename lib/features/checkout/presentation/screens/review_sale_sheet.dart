import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/cash_drawer_hardware/data/cash_drawer_service.dart';
import '../../../../features/cash_drawer_hardware/domain/printer_connection_config.dart';
import '../../../../features/cash_drawer_hardware/domain/receipt_data.dart';
import '../../../../features/cash_drawer_hardware/presentation/providers/cash_drawer_action_provider.dart';
import '../../../../features/cash_drawer_hardware/presentation/providers/cash_drawer_settings_provider.dart';
import '../../../../features/customers/domain/customer_models.dart';
import '../../../../features/discounts/widgets/discount_picker_sheet.dart';
import '../../../../features/customers/presentation/providers/customers_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../features/more/presentation/screens/settings_screen.dart' show salonSettingsProvider;
import '../../../../features/pos/domain/pos_models.dart';
import '../../../../features/pos/presentation/providers/cart_provider.dart';
import '../../../../features/payment_modes/models/payment_mode_model.dart';
import '../../../../features/payment_modes/providers/payment_modes_provider.dart';
import '../../../../features/transactions/data/transactions_repository.dart';
import '../widgets/staff_picker.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../../../core/theme/app_theme.dart';

enum _Step { currentSale, charge, cash, customPayment, success }

final _reviewRepoProvider = Provider.autoDispose<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.read(apiClientProvider)),
);

// ─── Entry point ──────────────────────────────────────────────────────────────

class ReviewSaleSheet extends HookConsumerWidget {
  const ReviewSaleSheet({super.key, required this.keypadAmount});
  final double keypadAmount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = useState(_Step.currentSale);
    final method = useState(PaymentMethod.cash);
    // Only set when method == PaymentMethod.other — which owner-configured
    // mode (see PaymentMode) the customer is paying via.
    final selectedMode = useState<PaymentMode?>(null);
    final customer = useState<CustomerModel?>(null);
    final cashInput = useState('0');
    final isProcessing = useState(false);
    // Snapshot of what was actually charged, captured the moment checkout()
    // succeeds — the cart itself is cleared right after, so the Success step
    // (which renders a receipt-style breakdown) reads from these instead of
    // the now-empty live cart.
    final completedItems = useState<List<CartItem>>(const []);
    final completedQuote = useState<CartQuote?>(null);
    final completedTransactionId = useState<String?>(null);
    final completedAt = useState<DateTime?>(null);
    final isPrintingReceipt = useState(false);

    useEffect(() => null, const []);

    final cart = ref.watch(activeCartProvider);
    // Client-side estimate — used only as a placeholder while the
    // authoritative quote (below) is loading, since it has no visibility
    // into tax rates and can disagree with what the server actually charges.
    final estimatedTotal = cart.items.isEmpty
        ? keypadAmount - _discountAmountFor(cart, keypadAmount)
        : cart.total;

    // Authoritative subtotal/discount/tax/total from the backend, refetched
    // whenever anything pricing-relevant changes. Payment method selection
    // on the Pick step is gated on this being non-null and not stale, so a
    // cashier can never proceed into a payment step with a total that
    // doesn't match what will actually be charged.
    final quote = useState<CartQuote?>(null);
    final quoting = useState(false);
    final quoteError = useState<String?>(null);
    // Bumped to force a re-quote on demand (e.g. the Pick step's "tap to
    // retry" after a failed quote) without waiting for the cart itself to
    // change.
    final retryTick = useState(0);

    useEffect(() {
      var cancelled = false;
      final hasKeypadAmount = cart.items.isEmpty && keypadAmount > 0;
      if (cart.items.isEmpty && !hasKeypadAmount) {
        // Nothing to price yet — leave any prior quote cleared.
        quote.value = null;
        quoteError.value = null;
        quoting.value = false;
        return null;
      }
      // Clear immediately (not just on response) so a stale total can never
      // be shown/charged while a fresher quote is in flight.
      quote.value = null;
      quoteError.value = null;
      quoting.value = true;
      ref
          .read(_reviewRepoProvider)
          .quote(
            cart: cart,
            discountId: cart.discount?.discountId,
            keypadAmount: hasKeypadAmount ? keypadAmount : null,
          )
          .then((q) {
            if (cancelled) return;
            quote.value = q;
            quoting.value = false;
          })
          .catchError((dynamic e) {
            if (cancelled) return;
            quoteError.value = e.toString();
            quoting.value = false;
          });
      return () => cancelled = true;
    }, [cart.items, cart.discount, cart.tipAmount, cart.finalPayable, keypadAmount, retryTick.value]);

    final total = quote.value?.total ?? estimatedTotal;
    final tendered = double.tryParse(cashInput.value) ?? 0;

    void done() {
      if (isProcessing.value) return;
      // The quote is re-validated here (not just at the Pick-step tap)
      // since it's the actual amount about to be charged.
      final confirmedQuote = quote.value;
      if (confirmedQuote == null) return;
      isProcessing.value = true;

      final checkoutCart = ref.read(activeCartProvider);

      ref
          .read(_reviewRepoProvider)
          .checkout(
            cart: checkoutCart,
            paymentMethod: method.value,
            paymentModeId: method.value == PaymentMethod.other
                ? selectedMode.value?.id
                : null,
            discountId: checkoutCart.discount?.discountId,
            keypadAmount: checkoutCart.items.isEmpty ? keypadAmount : null,
          )
          .then((response) {
            if (!context.mounted) return;
            completedItems.value = checkoutCart.items;
            completedQuote.value = confirmedQuote;
            completedTransactionId.value = response['id'] as String?;
            final createdAtRaw = response['createdAt'] as String?;
            completedAt.value =
                createdAtRaw != null ? DateTime.tryParse(createdAtRaw)?.toLocal() : null;
            ref.read(activeCartNotifierProvider).clear();
            ref.read(transactionListProvider.notifier).refresh();
            ref.invalidate(dashboardProvider);
            ref.invalidate(todayRevenueProvider);
            isProcessing.value = false;
            step.value = _Step.success;

            // Auto-pop the physical cash drawer for cash-tender sales, if
            // the owner opted in (Settings > Hardware > Cash Drawer). Fired
            // and forgotten — a failure here must never disrupt a checkout
            // that has already succeeded; the floating overlay button (if
            // shown) surfaces the failure snackbar via its own listener on
            // this same action provider.
            final drawerSettings = ref.read(cashDrawerSettingsProvider);
            if (method.value == PaymentMethod.cash &&
                drawerSettings.autoOpenOnCashPayment &&
                (drawerSettings.connection?.isValid ?? false)) {
              ref.read(cashDrawerActionProvider.notifier).open();
            }
          })
          .catchError((dynamic e) {
            isProcessing.value = false;
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(e.toString()),
                  backgroundColor: Colors.red,
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          });
    }

    Future<void> printReceipt() async {
      if (isPrintingReceipt.value) return;
      isPrintingReceipt.value = true;

      final salon = ref.read(salonSettingsProvider);
      final connection = ref.read(cashDrawerSettingsProvider).connection;
      final quoteSnapshot = completedQuote.value;
      final methodLabelValue =
          method.value == PaymentMethod.cash ? 'Cash' : (selectedMode.value?.name ?? 'Other');
      final changeValue =
          method.value == PaymentMethod.cash && tendered > total ? tendered - total : null;

      final receipt = ReceiptData(
        salonName: salon.salonName,
        address: salon.address,
        phone: salon.phone,
        currency: salon.currency,
        footer: salon.receiptFooter,
        items: completedItems.value
            .map((i) => ReceiptLineItem(name: i.name, quantity: i.quantity, totalPrice: i.totalPrice))
            .toList(),
        subtotal: quoteSnapshot?.subtotal,
        discountAmount: quoteSnapshot?.discountAmount ?? 0,
        tax: quoteSnapshot?.totalTax ?? 0,
        tip: quoteSnapshot?.tipAmount ?? 0,
        manualAdjustment: quoteSnapshot?.manualAdjustment ?? 0,
        total: quoteSnapshot?.total ?? total,
        paymentMethodLabel: methodLabelValue,
        change: changeValue,
        customerName: customer.value?.fullName,
        transactionId: completedTransactionId.value,
        dateTime: completedAt.value ?? DateTime.now(),
      );

      final result = await ref.read(cashDrawerServiceProvider).printReceipt(connection, receipt);
      isPrintingReceipt.value = false;
      if (!context.mounted) return;
      if (!result.success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.reason == CashDrawerFailureReason.notConfigured
                  ? 'No printer set up — add one in Settings > Hardware > Cash Drawer.'
                  : (result.message ?? "Couldn't reach the printer."),
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    void goCash() {
      // Defensive re-check — the Pick step already disables these taps
      // while unquoted, but a payment method must never be reachable
      // without a confirmed, current total to charge.
      if (quote.value == null) return;
      method.value = PaymentMethod.cash;
      selectedMode.value = null;
      cashInput.value = total.toStringAsFixed(0);
      step.value = _Step.cash;
    }

    void goCustom(PaymentMode mode) {
      if (quote.value == null) return;
      method.value = PaymentMethod.other;
      selectedMode.value = mode;
      step.value = _Step.customPayment;
    }

    void onCustomerChanged(CustomerModel? c) {
      customer.value = c;
      final notifier = ref.read(activeCartNotifierProvider);
      if (c != null) {
        notifier.setCustomer(c);
      } else {
        notifier.clearCustomer();
      }
    }

    return PopScope(
      // Block the system back gesture specifically while a payment request
      // is in flight — swiping/backing out mid-submit must not be able to
      // leave the cart in limbo after a sale may have already gone through
      // server-side. Normal navigation (including at every other step) is
      // unaffected.
      canPop: !isProcessing.value,
      child: Container(
        height: MediaQuery.of(context).size.height * 0.92,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: switch (step.value) {
        _Step.currentSale => _CurrentSaleStep(
          total: total,
          cart: cart,
          customer: customer.value,
          onCustomerChanged: onCustomerChanged,
          onCharge: () => step.value = _Step.charge,
          onClose: () => Navigator.pop(context),
          isQuoting: quoting.value,
          quoteError: quoteError.value,
          onRetryQuote: () => retryTick.value++,
        ),
        _Step.charge => _ChargeStep(
          total: total,
          cart: cart,
          onBack: () => step.value = _Step.currentSale,
          onClose: () => Navigator.pop(context),
          onPickCash: goCash,
          onPickMode: goCustom,
          isQuoting: quoting.value,
          quoteError: quoteError.value,
          onRetryQuote: () => retryTick.value++,
        ),
        _Step.cash => _CashStep(
          total: total,
          cashInput: cashInput,
          tendered: tendered,
          onBack: () => step.value = _Step.charge,
          onConfirm: done,
          isProcessing: isProcessing.value,
        ),
        _Step.customPayment => _CustomPaymentStep(
          mode: selectedMode.value!,
          total: total,
          customer: customer.value,
          onBack: () => step.value = _Step.charge,
          onConfirm: done,
          isProcessing: isProcessing.value,
        ),
        _Step.success => _SuccessStep(
          total: total,
          methodLabel: method.value == PaymentMethod.cash ? 'Cash' : (selectedMode.value?.name ?? 'Other'),
          customer: customer.value,
          change: method.value == PaymentMethod.cash && tendered > total
              ? tendered - total
              : null,
          items: completedItems.value,
          subtotal: completedQuote.value?.subtotal,
          manualAdjustment: completedQuote.value?.manualAdjustment ?? 0,
          onNewSale: () => Navigator.pop(context),
          onPrintReceipt: printReceipt,
          isPrintingReceipt: isPrintingReceipt.value,
        ),
        },
      ),
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

double _discountAmountFor(CartState cart, double keypadAmount) {
  if (cart.items.isNotEmpty) return cart.discountAmount;
  final discount = cart.discount;
  if (discount == null) return 0;
  final raw = discount.isPercentage
      ? keypadAmount * discount.amount / 100
      : discount.amount;
  return raw.clamp(0.0, keypadAmount);
}

String _applyKey(String cur, String k) {
  if (k == 'C') return '0';
  if (k == '.' && cur.contains('.')) return cur;
  if (cur == '0' && k != '.') return k;
  if (cur.contains('.') && cur.split('.')[1].length >= 2) return cur;
  return '$cur$k';
}

List<double> _quickAmounts(double total) {
  final s = {
    total,
    (total / 50).ceil() * 50.0,
    (total / 100).ceil() * 100.0,
    (total / 500).ceil() * 500.0,
  }.toList()..sort();
  return s;
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Center(
    child: Container(
      width: 36,
      height: 4,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(2),
      ),
    ),
  );
}

class _BigBtn extends StatelessWidget {
  const _BigBtn({
    required this.label,
    this.onTap,
    this.enabled = true,
    this.isLoading = false,
    this.color,
    this.outlined = false,
  });
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final bool isLoading;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final active = enabled && !isLoading;
    final bg = outlined
        ? Colors.white
        : (active ? (color ?? Colors.black) : AppColors.border);
    final fg = outlined
        ? Colors.black
        : (active ? Colors.white : AppColors.textTertiary);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: GestureDetector(
        onTap: active ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(26),
            border: outlined ? Border.all(color: AppColors.divider) : null,
          ),
          child: Center(
            child: isLoading
                ? SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      // Matches `fg` — a hardcoded white spinner would be
                      // invisible on an outlined (white-background) button.
                      valueColor: AlwaysStoppedAnimation(fg),
                    ),
                  )
                : Text(
                    label,
                    style: TextStyle(
                      color: fg,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.title, required this.onBack, this.right});
  final String title;
  final VoidCallback onBack;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const _Handle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: onBack,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              right ?? const SizedBox(width: 18),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
      ],
    );
  }
}

// Numpad where each row expands to fill available height (no dead zone).
class _FlexNumpad extends StatelessWidget {
  const _FlexNumpad({required this.onKey});
  final ValueChanged<String> onKey;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['C', '0', '.'],
  ];

  @override
  Widget build(BuildContext context) => Column(
    children: _rows
        .map(
          (row) => Expanded(
            child: Row(
              children: row
                  .map(
                    (k) => Expanded(
                      child: GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onKey(k);
                        },
                        child: Container(
                          margin: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            color: k == 'C'
                                ? AppColors.dangerLight
                                : AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Center(
                            child: Text(
                              k,
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w400,
                                color: k == 'C'
                                    ? AppColors.danger
                                    : Colors.black,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),
        )
        .toList(),
  );
}

void _showCustomerPicker(
  BuildContext context,
  ValueChanged<CustomerModel?> onSelected,
) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _CustomerPicker(onSelected: onSelected),
  );
}

// ─── Step 0: Current Sale ──────────────────────────────────────────────────
// The line-item review — what's in the sale, who's serving it, any discount,
// and the customer — with a single "Add item or service" escape hatch back
// to the grid underneath this sheet. Nothing here is a payment method; that
// choice, and the one editable total, live one step later on _ChargeStep.

class _CurrentSaleStep extends ConsumerWidget {
  const _CurrentSaleStep({
    required this.total,
    required this.cart,
    required this.customer,
    required this.onCustomerChanged,
    required this.onCharge,
    required this.onClose,
    required this.isQuoting,
    required this.quoteError,
    required this.onRetryQuote,
  });
  final double total;
  final CartState cart;
  final CustomerModel? customer;
  final ValueChanged<CustomerModel?> onCustomerChanged;
  final VoidCallback onCharge;
  final VoidCallback onClose;
  final bool isQuoting;
  final String? quoteError;
  final VoidCallback onRetryQuote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final canPay = !isQuoting && quoteError == null;
    return Column(
      children: [
        const _Handle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 8, 8),
          child: Row(
            children: [
              const Text(
                'Current sale',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              IconButton(
                onPressed: onClose,
                icon: const Icon(
                  Icons.close,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                if (cart.items.isNotEmpty)
                  _CartItemsList(items: cart.items)
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'Custom amount',
                      style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
                    ),
                  ),
                const SizedBox(height: 8),
                _CustomerRow(
                  customer: customer,
                  onTap: () => _showCustomerPicker(context, onCustomerChanged),
                  onRemove: () => onCustomerChanged(null),
                ),
                const Divider(height: 1, color: AppColors.divider),
                if (cart.items.isNotEmpty) ...[
                  _ActionRow(
                    icon: Icons.local_offer_outlined,
                    label: cart.discount?.label ?? 'Add discount',
                    color: AppColors.primary,
                    onTap: () =>
                        DiscountPickerSheet.show(context, subtotal: cart.subtotal),
                    trailing: cart.discount == null
                        ? null
                        : GestureDetector(
                            onTap: () =>
                                ref.read(activeCartNotifierProvider).clearDiscount(),
                            child: const Icon(
                              Icons.close,
                              size: 16,
                              color: AppColors.textTertiary,
                            ),
                          ),
                  ),
                  const Divider(height: 1, color: AppColors.divider),
                ],
                _ActionRow(
                  icon: Icons.add_circle_outline_rounded,
                  label: 'Add item or service',
                  color: AppColors.primary,
                  onTap: onClose,
                ),
                const Divider(height: 1, color: AppColors.divider),
                if (cart.manualAdjustment.abs() >= 0.005) ...[
                  _ManualAdjustmentSummaryRow(adjustment: cart.manualAdjustment),
                  const Divider(height: 1, color: AppColors.divider),
                ],
                const SizedBox(height: 12),
                if (isQuoting)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Confirming total…',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                else if (quoteError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: InkWell(
                      onTap: onRetryQuote,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.error_outline_rounded, size: 14, color: AppColors.danger),
                          const SizedBox(width: 6),
                          const Flexible(
                            child: Text(
                              'Could not confirm total — tap to retry.',
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                                decoration: TextDecoration.underline,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        ),
        _BigBtn(
          label: 'Charge Rs ${total.toStringAsFixed(0)}',
          onTap: onCharge,
          enabled: canPay,
          isLoading: isQuoting,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// Line items with per-item staff assignment and remove — shared by the
// Current Sale step. Extracted since Square-style "Current sale" is the
// only place items are shown at review time now.
class _CartItemsList extends ConsumerWidget {
  const _CartItemsList({required this.items});
  final List<CartItem> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              style: const TextStyle(fontSize: 13),
                            ),
                            // Per-service staff override — unassigned until
                            // explicitly picked.
                            GestureDetector(
                              onTap: () async {
                                final staff = await pickStaffMember(
                                  context,
                                  ref,
                                  title: 'Staff for ${item.name}',
                                );
                                ref
                                    .read(activeCartNotifierProvider)
                                    .assignStaff(item.id, staff);
                              },
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.person_outline,
                                    size: 12,
                                    color: item.assignedStaff != null
                                        ? AppColors.primary
                                        : AppColors.textTertiary,
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    item.assignedStaff != null
                                        ? item.assignedStaff!.firstName
                                        : 'Assign staff',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: item.assignedStaff != null
                                          ? AppColors.primary
                                          : AppColors.textTertiary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '×${item.quantity}',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Rs ${item.totalPrice.toStringAsFixed(0)}',
                        style: const TextStyle(fontSize: 13),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () =>
                            ref.read(activeCartNotifierProvider).removeItem(item.id),
                        behavior: HitTestBehavior.opaque,
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                          child: Icon(
                            Icons.close_rounded,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            trailing ??
                Icon(Icons.arrow_forward_ios_rounded, size: 13, color: color.withValues(alpha: 0.6)),
          ],
        ),
      ),
    );
  }
}

// ─── Step 1: Charge ────────────────────────────────────────────────────────
// The editable total plus payment method — Square/Apple-Pay-style: the
// amount is shown big and is itself the "tap to edit" control (opens an
// in-place keypad, no separate screen), and Cash is the prominent default
// action with owner-configured payment modes as secondary options underneath.

class _ChargeStep extends HookConsumerWidget {
  const _ChargeStep({
    required this.total,
    required this.cart,
    required this.onBack,
    required this.onClose,
    required this.onPickCash,
    required this.onPickMode,
    required this.isQuoting,
    required this.quoteError,
    required this.onRetryQuote,
  });
  final double total;
  final CartState cart;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final VoidCallback onPickCash;
  final ValueChanged<PaymentMode> onPickMode;
  final bool isQuoting;
  final String? quoteError;
  final VoidCallback onRetryQuote;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final editing = useState(false);
    final amountInput = useState('0');
    // Only a real cart has a subtotal the final payable amount can be edited
    // against — a keypad-only custom charge already IS the final amount,
    // fixed before this sheet ever opened.
    final canEdit = cart.items.isNotEmpty;
    final canPay = !isQuoting && quoteError == null;

    void startEdit() {
      if (!canEdit) return;
      amountInput.value = total == total.roundToDouble()
          ? total.toStringAsFixed(0)
          : total.toStringAsFixed(2);
      editing.value = true;
    }

    void confirmEdit() {
      final parsed = double.tryParse(amountInput.value);
      if (parsed != null && parsed >= 0) {
        ref.read(activeCartNotifierProvider).setFinalPayable(parsed);
      }
      editing.value = false;
    }

    return Column(
      children: [
        _BackHeader(
          title: 'Charge',
          onBack: editing.value ? () => editing.value = false : onBack,
          right: GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, size: 20, color: AppColors.textTertiary),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: editing.value
                ? const NeverScrollableScrollPhysics()
                : const AlwaysScrollableScrollPhysics(),
            child: Column(
              children: [
                const SizedBox(height: 28),
                GestureDetector(
                  onTap: editing.value ? null : startEdit,
                  child: Column(
                    children: [
                      Text(
                        'Rs ${editing.value ? amountInput.value : total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 44,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -1,
                        ),
                      ),
                      if (canEdit)
                        Text(
                          editing.value ? 'Enter amount' : 'Tap to edit amount',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                    ],
                  ),
                ),
                if (!editing.value && isQuoting)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Confirming total…',
                          style: TextStyle(fontSize: 12, color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                  )
                else if (!editing.value && quoteError != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                    child: InkWell(
                      onTap: onRetryQuote,
                      child: const Text(
                        'Could not confirm total — tap to retry.',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          decoration: TextDecoration.underline,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (editing.value) ...[
                  SizedBox(
                    height: 260,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: _FlexNumpad(
                        onKey: (k) => amountInput.value = _applyKey(amountInput.value, k),
                      ),
                    ),
                  ),
                  _BigBtn(label: 'Done', onTap: confirmEdit),
                  const SizedBox(height: 16),
                ] else ...[
                  const Padding(
                    padding: EdgeInsets.only(left: 20, bottom: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Pay with',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 0.4,
                        ),
                      ),
                    ),
                  ),
                  // Cash is the default/primary action — mirrors the "pay on
                  // iPhone" pattern of one prominent default with secondary
                  // methods underneath, rather than a flat list of equals.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _BigBtn(
                      label: 'Cash',
                      onTap: canPay ? onPickCash : null,
                      enabled: canPay,
                    ),
                  ),
                  // Owner-configured payment modes (see Settings > Payment
                  // Modes) — each just shows a QR the cashier confirms
                  // against, no gateway integration behind it.
                  Consumer(builder: (context, ref, _) {
                    final modes = ref.watch(paymentModesProvider).valueOrNull ?? const [];
                    if (modes.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                      child: Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Column(
                          children: [
                            for (final (i, mode) in modes.indexed)
                              _MethodRow(
                                icon: Icons.qr_code_rounded,
                                label: mode.name,
                                color: AppColors.primary,
                                onTap: canPay ? () => onPickMode(mode) : null,
                                showDivider: i < modes.length - 1,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                  const SizedBox(height: 16),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.showDivider,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return Column(
      children: [
        Opacity(
          opacity: enabled ? 1 : 0.4,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 18, color: color),
                  ),
                  const SizedBox(width: 14),
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: color.withValues(alpha: 0.6),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider)
          const Divider(height: 1, indent: 66, color: AppColors.surfaceVariant),
      ],
    );
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow({
    required this.customer,
    required this.onTap,
    required this.onRemove,
  });
  final CustomerModel? customer;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return GestureDetector(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(
            children: [
              Icon(
                Icons.person_add_outlined,
                size: 18,
                color: AppColors.textTertiary,
              ),
              SizedBox(width: 10),
              Text(
                'Add customer (optional)',
                style: TextStyle(fontSize: 14, color: AppColors.textTertiary),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surfaceVariant,
            child: Text(
              customer!.initials,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.black,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              customer!.fullName,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(
              Icons.close,
              size: 16,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Manual Adjustment summary row (salon checkout, read-only) ─────────────
// Mirrors the amount set via the Charge step's editable total — this step
// only displays it, since a single editable surface is easier to reason
// about than two fields that could disagree.

class _ManualAdjustmentSummaryRow extends StatelessWidget {
  const _ManualAdjustmentSummaryRow({required this.adjustment});
  final double adjustment;

  @override
  Widget build(BuildContext context) {
    final isIncrease = adjustment > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: AppColors.success.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.payments,
              size: 16,
              color: AppColors.success,
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Manual Adjustment',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.success,
              ),
            ),
          ),
          Text(
            '${isIncrease ? '+' : '-'}Rs ${adjustment.abs().toStringAsFixed(0)}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Customer Picker ──────────────────────────────────────────────────────────

// Use the shared customersProvider (no search query needed here).
final _cpProvider = customersProvider;

class _CustomerPicker extends HookConsumerWidget {
  const _CustomerPicker({required this.onSelected});
  final ValueChanged<CustomerModel?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(_cpProvider);
    final q = useState('');
    final ctrl = useTextEditingController();
    final showAddForm = useState(false);

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: showAddForm.value
          ? _QuickAddCustomerForm(
              onCancel: () => showAddForm.value = false,
              onCreated: (c) {
                onSelected(c);
                Navigator.pop(context);
              },
            )
          : Column(
        children: [
          const _Handle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(
              children: [
                const Text(
                  'Add Customer',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: ctrl,
              autofocus: true,
              onChanged: (v) => q.value = v,
              decoration: InputDecoration(
                hintText: 'Search name or phone…',
                hintStyle: const TextStyle(
                  color: AppColors.textTertiary,
                  fontSize: 14,
                ),
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(10),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 4),
          InkWell(
            onTap: () => showAddForm.value = true,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(
                      Icons.person_add_alt_1,
                      size: 18,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'Add New Customer',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 1, color: AppColors.divider),
          Expanded(
            child: all.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('$e')),
              data: (list) {
                final filtered = q.value.isEmpty
                    ? list
                    : list
                          .where(
                            (c) =>
                                c.fullName.toLowerCase().contains(
                                  q.value.toLowerCase(),
                                ) ||
                                (c.phone ?? '').contains(q.value),
                          )
                          .toList();

                return ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length + 1,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 66,
                    color: AppColors.surfaceVariant,
                  ),
                  itemBuilder: (_, i) {
                    if (i == filtered.length) {
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.surfaceVariant,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            Icons.person_outline_rounded,
                            size: 20,
                            color: AppColors.textTertiary,
                          ),
                        ),
                        title: const Text(
                          'Continue as Guest',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 14,
                          ),
                        ),
                        onTap: () {
                          onSelected(null);
                          Navigator.pop(context);
                        },
                      );
                    }
                    final c = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceVariant,
                        child: Text(
                          c.initials,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: Colors.black,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      title: Text(
                        c.fullName,
                        style: const TextStyle(fontSize: 15),
                      ),
                      subtitle: c.phone != null
                          ? Text(
                              c.phone!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textTertiary,
                              ),
                            )
                          : null,
                      trailing: Text(
                        '${c.visitCount} visits',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      onTap: () {
                        onSelected(c);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickAddCustomerForm extends HookConsumerWidget {
  const _QuickAddCustomerForm({required this.onCancel, required this.onCreated});
  final VoidCallback onCancel;
  final ValueChanged<CustomerModel> onCreated;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nameCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final saving = useState(false);
    final error = useState<String?>(null);

    Future<void> save() async {
      final name = nameCtrl.text.trim();
      if (name.isEmpty) {
        error.value = 'Enter a name';
        return;
      }
      if (saving.value) return;
      saving.value = true;
      error.value = null;
      final parts = name.split(RegExp(r'\s+'));
      try {
        final created = await ref
            .read(customersRepoProvider)
            .create(
              firstName: parts.first,
              lastName: parts.length > 1 ? parts.sublist(1).join(' ') : '',
              phone: phoneCtrl.text.trim().isEmpty ? null : phoneCtrl.text.trim(),
            );
        ref.invalidate(customersProvider);
        onCreated(created);
      } catch (e) {
        error.value = 'Failed to add customer';
      } finally {
        saving.value = false;
      }
    }

    return Column(
      children: [
        const _Handle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(
            children: [
              GestureDetector(
                onTap: onCancel,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.black,
                ),
              ),
              const Spacer(),
              const Text(
                'Add New Customer',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              const SizedBox(width: 18),
            ],
          ),
        ),
        const Divider(height: 1, color: AppColors.divider),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Name',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: nameCtrl,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Customer name',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Phone (optional)',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    hintText: 'Phone number',
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
                if (error.value != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    error.value!,
                    style: const TextStyle(fontSize: 12, color: AppColors.danger),
                  ),
                ],
              ],
            ),
          ),
        ),
        _BigBtn(label: 'Add Customer', onTap: save, isLoading: saving.value),
        const SizedBox(height: 12),
      ],
    );
  }
}

// ─── Step 2a: Cash ────────────────────────────────────────────────────────────

class _CashStep extends HookWidget {
  const _CashStep({
    required this.total,
    required this.cashInput,
    required this.tendered,
    required this.onBack,
    required this.onConfirm,
    this.isProcessing = false,
  });
  final double total;
  final ValueNotifier<String> cashInput;
  final double tendered;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final t = double.tryParse(cashInput.value) ?? 0;
    final ok = t >= total;
    final change = t - total;

    return Column(
      children: [
        _BackHeader(title: 'Cash Payment', onBack: onBack),
        // Big amount display
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          child: Column(
            children: [
              const Text(
                'Tendered',
                style: TextStyle(
                  fontSize: 12,
                  color: AppColors.textTertiary,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 4),
              SizedBox(
                width: double.infinity,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.center,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 120),
                    child: Text(
                      'Rs ${cashInput.value}',
                      key: ValueKey(cashInput.value),
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -1,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ),
              ),
              // Change / short line
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 150),
                child: ok && change > 0
                    ? Text(
                        key: const ValueKey('ch'),
                        'Change: Rs ${change.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF16A34A),
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : !ok && t > 0
                    ? Text(
                        key: const ValueKey('sh'),
                        'Short: Rs ${(-change).toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.danger,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    : const SizedBox(key: ValueKey('none'), height: 18),
              ),
            ],
          ),
        ),
        // Quick amounts
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _quickAmounts(total).map((amt) {
                final isSelected = cashInput.value == amt.toStringAsFixed(0);
                final lbl = amt == total
                    ? 'Exact'
                    : 'Rs ${amt.toStringAsFixed(0)}';
                return _Chip(
                  label: lbl,
                  selected: isSelected,
                  onTap: () => cashInput.value = amt.toStringAsFixed(0),
                );
              }).toList(),
            ),
          ),
        ),
        // Expanding numpad
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: _FlexNumpad(
              onKey: (k) => cashInput.value = _applyKey(cashInput.value, k),
            ),
          ),
        ),
        _BigBtn(
          label: ok
              ? (change > 0
                    ? 'Confirm — Change Rs ${change.toStringAsFixed(2)}'
                    : 'Confirm Payment')
              : 'Enter Amount',
          onTap: onConfirm,
          enabled: ok,
          isLoading: isProcessing,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.onTap,
    this.selected = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: selected ? Colors.white : Colors.black,
        borderRadius: BorderRadius.circular(20),
        border: selected
            ? Border.all(color: Colors.black, width: 1.5)
            : null,
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 13,
          color: selected ? Colors.black : Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
  );
}

// ─── Step 2b: Custom payment mode (eSewa, Fonepay, ...) ────────────────────
// Self-attested, same trust model as Cash — no gateway integration behind
// it. Shows the owner-uploaded QR for this mode; the cashier taps "Payment
// Received" once the customer has visibly paid.

class _CustomPaymentStep extends StatelessWidget {
  const _CustomPaymentStep({
    required this.mode,
    required this.total,
    required this.customer,
    required this.onBack,
    required this.onConfirm,
    this.isProcessing = false,
  });
  final PaymentMode mode;
  final double total;
  final CustomerModel? customer;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _BackHeader(title: mode.name, onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        mode.name.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: 220,
                        height: 220,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.divider, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              mode.qrImageUrl,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => const Center(
                                child: Icon(Icons.qr_code_2_rounded,
                                    size: 150, color: Colors.black87),
                              ),
                              loadingBuilder: (context, child, progress) =>
                                  progress == null
                                      ? child
                                      : const Center(
                                          child: SizedBox(
                                            width: 28,
                                            height: 28,
                                            child: CircularProgressIndicator(strokeWidth: 2),
                                          ),
                                        ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Rs ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (customer != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          customer!.fullName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Show this to the customer and confirm once they\'ve paid.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        _BigBtn(
          label: isProcessing ? 'Processing…' : 'Payment Received',
          onTap: isProcessing ? null : onConfirm,
          color: AppColors.primary,
          isLoading: isProcessing,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Step 3: Success ──────────────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({
    required this.total,
    required this.methodLabel,
    required this.customer,
    required this.change,
    required this.items,
    required this.subtotal,
    required this.manualAdjustment,
    required this.onNewSale,
    required this.onPrintReceipt,
    required this.isPrintingReceipt,
  });
  final double total;
  final String methodLabel;
  final CustomerModel? customer;
  final double? change;
  // Services / Subtotal / Manual Adjustment breakdown — snapshotted at the
  // moment checkout() succeeded (see ReviewSaleSheet.build's completedItems/
  // completedQuote), since the live cart is cleared right after. Empty
  // items + null subtotal means a keypad-only custom-amount sale, which has
  // no service breakdown to show.
  final List<CartItem> items;
  final double? subtotal;
  final double manualAdjustment;
  final VoidCallback onNewSale;
  final VoidCallback onPrintReceipt;
  final bool isPrintingReceipt;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                size: 44,
                color: Color(0xFF16A34A),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Payment Successful',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Rs ${total.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w200,
                letterSpacing: -1,
              ),
            ),
            const Spacer(),
            // Receipt card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.divider),
              ),
              child: Column(
                children: [
                  _Row('Method', methodLabel),
                  if (customer != null) ...[
                    const SizedBox(height: 10),
                    _Row('Customer', customer!.fullName),
                  ],
                  // Services / Subtotal / Manual Adjustment / Grand Total —
                  // omitted for a keypad-only custom charge, which has no
                  // service breakdown (subtotal == total by definition there).
                  if (items.isNotEmpty && subtotal != null) ...[
                    const Divider(height: 20, color: AppColors.divider),
                    ...items.map(
                      (item) => Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: _Row(
                          item.quantity > 1
                              ? '${item.name} ×${item.quantity}'
                              : item.name,
                          'Rs ${item.totalPrice.toStringAsFixed(0)}',
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    _Row('Subtotal', 'Rs ${subtotal!.toStringAsFixed(0)}'),
                    if (manualAdjustment.abs() >= 0.005) ...[
                      const SizedBox(height: 6),
                      _Row(
                        'Manual Adjustment',
                        '${manualAdjustment > 0 ? '+' : '-'}Rs '
                            '${manualAdjustment.abs().toStringAsFixed(0)}',
                      ),
                    ],
                    const Divider(height: 20, color: AppColors.divider),
                    _Row('Grand Total', 'Rs ${total.toStringAsFixed(2)}'),
                  ],
                  if (change != null && change! > 0) ...[
                    const Divider(height: 20, color: AppColors.divider),
                    Row(
                      children: [
                        const Text(
                          'Change Due',
                          style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'Rs ${change!.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const Spacer(),
            // Print Receipt
            _BigBtn(
              label: 'Print Receipt',
              onTap: onPrintReceipt,
              isLoading: isPrintingReceipt,
              outlined: true,
            ),
            const SizedBox(height: 8),
            _BigBtn(label: 'New Sale', onTap: onNewSale),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Text(
        label,
        style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
      ),
      const Spacer(),
      Text(
        value,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
      ),
    ],
  );
}
