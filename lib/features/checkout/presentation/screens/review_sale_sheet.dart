import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/customers/domain/customer_models.dart';
import '../../../../features/discounts/widgets/discount_picker_sheet.dart';
import '../../../../features/customers/presentation/providers/customers_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../features/pos/domain/pos_models.dart';
import '../../../../features/pos/presentation/providers/cart_provider.dart';
import '../../../../features/pos/presentation/providers/salon_sessions_provider.dart';
import '../../../../features/transactions/data/transactions_repository.dart';
import '../widgets/session_strip.dart' show pickStaffMember;
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../../../core/theme/app_theme.dart';

enum _Step { currentSale, charge, cash, qr, split, success }

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
    final customer = useState<CustomerModel?>(null);
    final cashInput = useState('0');
    final isProcessing = useState(false);
    // Snapshot of what was actually charged, captured the moment checkout()
    // succeeds — the cart itself is cleared right after, so the Success step
    // (which renders a receipt-style breakdown) reads from these instead of
    // the now-empty live cart.
    final completedItems = useState<List<CartItem>>(const []);
    final completedQuote = useState<CartQuote?>(null);

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

      // Captured once, up front — this sheet is modal (isDismissible:
      // false) for its entire lifetime, so the selected session can't
      // change out from under it, but reading it explicitly here (rather
      // than re-deriving inside the success handler) makes that assumption
      // visible instead of implicit.
      final sessionId = ref.read(selectedSessionIdProvider);
      final checkoutCart = ref.read(activeCartProvider);

      final splitCash = method.value == PaymentMethod.split
          ? double.tryParse(cashInput.value)
          : null;
      final splitFonepay = splitCash != null
          ? (confirmedQuote.total - splitCash).clamp(0.0, confirmedQuote.total)
          : null;

      ref
          .read(_reviewRepoProvider)
          .checkout(
            cart: checkoutCart,
            paymentMethod: method.value,
            splitCash: splitCash,
            splitFonepay: splitFonepay,
            discountId: checkoutCart.discount?.discountId,
            keypadAmount: checkoutCart.items.isEmpty ? keypadAmount : null,
            primaryStaffId: ref.read(selectedSalonSessionProvider).primaryStaff?.id,
          )
          .then((_) {
            if (!context.mounted) return;
            completedItems.value = checkoutCart.items;
            completedQuote.value = confirmedQuote;
            // Removes only this session (clearing its cart as part of
            // that) — every other concurrently open session is untouched.
            // If this was the only session, a fresh empty one is created
            // and selected automatically (see SalonSessionsNotifier).
            ref.read(salonSessionsProvider.notifier).completeSession(sessionId);
            ref.read(transactionListProvider.notifier).refresh();
            ref.invalidate(dashboardProvider);
            ref.invalidate(todayRevenueProvider);
            isProcessing.value = false;
            step.value = _Step.success;
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

    // ─── Fonepay: create-pending → verify (see _QRStep) ───────────────────────
    // Fonepay is never self-attested: entering this step creates a real
    // PENDING transaction (with a real, signed QR — see checkout()/create()
    // server-side) that only becomes COMPLETED, gets a receipt, and counts
    // as revenue once fonepay-verify independently confirms it. Cash/Split
    // are unaffected and still go through done() as before.
    final pendingFonepayId = useState<String?>(null);
    final pendingQrData = useState<String?>(null);
    final creatingPending = useState(false);
    final pendingCreateError = useState<String?>(null);
    final verifying = useState(false);
    final verifyError = useState<String?>(null);

    Future<void> cancelPendingIfAny() async {
      final id = pendingFonepayId.value;
      if (id == null) return;
      pendingFonepayId.value = null;
      pendingQrData.value = null;
      try {
        await ref.read(_reviewRepoProvider).cancelPendingFonepay(id);
      } catch (_) {
        // Best-effort — an abandoned PENDING transaction with no receipt
        // never counts as revenue regardless, so a failed cancel here just
        // means stock restoration is delayed rather than lost data.
      }
    }

    Future<void> createPendingFonepay() async {
      final confirmedQuote = quote.value;
      if (confirmedQuote == null || creatingPending.value) return;
      creatingPending.value = true;
      pendingCreateError.value = null;
      try {
        final cartAtSubmit = ref.read(activeCartProvider);
        final result = await ref.read(_reviewRepoProvider).checkout(
              cart: cartAtSubmit,
              paymentMethod: PaymentMethod.fonepay,
              discountId: cartAtSubmit.discount?.discountId,
              keypadAmount: cartAtSubmit.items.isEmpty ? keypadAmount : null,
              primaryStaffId:
                  ref.read(selectedSalonSessionProvider).primaryStaff?.id,
            );
        pendingFonepayId.value = result['id'] as String?;
        pendingQrData.value = result['qrData'] as String?;
        completedItems.value = cartAtSubmit.items;
        completedQuote.value = confirmedQuote;
      } catch (e) {
        pendingCreateError.value = e.toString();
      } finally {
        creatingPending.value = false;
      }
    }

    Future<void> verifyFonepayPayment(String reference) async {
      final id = pendingFonepayId.value;
      if (id == null || verifying.value) return;
      verifying.value = true;
      verifyError.value = null;
      try {
        await ref.read(_reviewRepoProvider).verifyFonepay(id, reference);
        if (!context.mounted) return;
        pendingFonepayId.value = null;
        pendingQrData.value = null;
        // Payment is now actually confirmed — only now does this session
        // get removed (clearing its cart as part of that). Every other
        // concurrently open session is untouched.
        ref
            .read(salonSessionsProvider.notifier)
            .completeSession(ref.read(selectedSessionIdProvider));
        ref.read(transactionListProvider.notifier).refresh();
        ref.invalidate(dashboardProvider);
        ref.invalidate(todayRevenueProvider);
        verifying.value = false;
        step.value = _Step.success;
      } catch (e) {
        verifying.value = false;
        verifyError.value = e.toString();
      }
    }

    void go(PaymentMethod m) {
      // Defensive re-check — the Pick step already disables these taps
      // while unquoted, but a payment method must never be reachable
      // without a confirmed, current total to charge.
      if (quote.value == null) return;
      method.value = m;
      // Pre-fill so the page opens ready to confirm: cash=exact total, split=50/50
      cashInput.value = switch (m) {
        PaymentMethod.cash => total.toStringAsFixed(0),
        PaymentMethod.split => (total / 2).toStringAsFixed(0),
        _ => '0',
      };
      step.value = switch (m) {
        PaymentMethod.cash => _Step.cash,
        PaymentMethod.fonepay => _Step.qr,
        PaymentMethod.split => _Step.split,
      };
      if (m == PaymentMethod.fonepay) createPendingFonepay();
    }

    void backFromQr() {
      cancelPendingIfAny();
      pendingCreateError.value = null;
      verifyError.value = null;
      step.value = _Step.charge;
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
      // Block the system back gesture specifically while a payment/verify
      // request is in flight — swiping/backing out mid-submit must not be
      // able to leave the cart in limbo after a sale may have already gone
      // through server-side. Normal navigation (including at every other
      // step) is unaffected.
      canPop: !isProcessing.value && !creatingPending.value && !verifying.value,
      onPopInvokedWithResult: (didPop, _) {
        // The system back gesture (unlike the explicit back-arrow, which
        // calls backFromQr() directly) doesn't step between _Steps — it
        // dismisses the whole sheet. If that happens while a PENDING
        // Fonepay transaction exists, it must still be cancelled rather
        // than left orphaned.
        if (didPop) cancelPendingIfAny();
      },
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
          onPick: go,
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
        _Step.qr => _QRStep(
          total: total,
          customer: customer.value,
          onBack: backFromQr,
          qrData: pendingQrData.value,
          creatingPending: creatingPending.value,
          createError: pendingCreateError.value,
          onRetryCreate: createPendingFonepay,
          onVerify: verifyFonepayPayment,
          isVerifying: verifying.value,
          verifyError: verifyError.value,
        ),
        _Step.split => _SplitStep(
          total: total,
          cashInput: cashInput,
          onBack: () => step.value = _Step.charge,
          onConfirm: done,
          isProcessing: isProcessing.value,
        ),
        _Step.success => _SuccessStep(
          total: total,
          method: method.value,
          customer: customer.value,
          change: method.value == PaymentMethod.cash && tendered > total
              ? tendered - total
              : null,
          cashPaid: method.value == PaymentMethod.split ? tendered : null,
          fonepayPaid: method.value == PaymentMethod.split
              ? (total - tendered).clamp(0.0, total)
              : null,
          items: completedItems.value,
          subtotal: completedQuote.value?.subtotal,
          manualAdjustment: completedQuote.value?.manualAdjustment ?? 0,
          onNewSale: () => Navigator.pop(context),
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
                ? const SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      valueColor: AlwaysStoppedAnimation(Colors.white),
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
                            // Per-service staff override — defaults to the
                            // session's primary staff (shown as an implied
                            // default in a lighter style) until explicitly
                            // overridden. Reuses the same picker sheet
                            // session creation/reassignment uses, rather
                            // than a second implementation.
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
                                        : (ref.watch(selectedSalonSessionProvider)
                                                .primaryStaff
                                                ?.firstName ??
                                            'Assign staff'),
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
// action with Fonepay/Split as secondary options underneath.

class _ChargeStep extends HookConsumerWidget {
  const _ChargeStep({
    required this.total,
    required this.cart,
    required this.onBack,
    required this.onClose,
    required this.onPick,
    required this.isQuoting,
    required this.quoteError,
    required this.onRetryQuote,
  });
  final double total;
  final CartState cart;
  final VoidCallback onBack;
  final VoidCallback onClose;
  final ValueChanged<PaymentMethod> onPick;
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
                      onTap: canPay ? () => onPick(PaymentMethod.cash) : null,
                      enabled: canPay,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Column(
                        children: [
                          _MethodRow(
                            icon: Icons.qr_code_rounded,
                            label: 'Fonepay QR',
                            color: const Color(0xFF6BBD44),
                            onTap: canPay ? () => onPick(PaymentMethod.fonepay) : null,
                            showDivider: true,
                          ),
                          _MethodRow(
                            icon: Icons.call_split_rounded,
                            label: 'Split Payment',
                            color: AppColors.primary,
                            onTap: canPay ? () => onPick(PaymentMethod.split) : null,
                            showDivider: false,
                          ),
                        ],
                      ),
                    ),
                  ),
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

// ─── Step 2b: Fonepay QR ──────────────────────────────────────────────────────

class _QRStep extends HookWidget {
  const _QRStep({
    required this.total,
    required this.customer,
    required this.onBack,
    required this.qrData,
    required this.creatingPending,
    required this.createError,
    required this.onRetryCreate,
    required this.onVerify,
    required this.isVerifying,
    required this.verifyError,
  });
  final double total;
  final CustomerModel? customer;
  final VoidCallback onBack;
  // Real, signed Fonepay QR payload from the backend — null while it's
  // still being created or if creation failed. There is deliberately no
  // "Payment Received" self-attest button anymore: the only way past this
  // step is entering the Fonepay reference number below and having
  // fonepay-verify independently confirm it.
  final String? qrData;
  final bool creatingPending;
  final String? createError;
  final VoidCallback onRetryCreate;
  final ValueChanged<String> onVerify;
  final bool isVerifying;
  final String? verifyError;

  @override
  Widget build(BuildContext context) {
    final pulse = useAnimationController(
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    final refCtrl = useTextEditingController();

    return Column(
      children: [
        _BackHeader(title: 'Fonepay QR', onBack: onBack),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                // QR card
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(28),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF0FDF4),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: const Color(0xFF6BBD44).withValues(alpha: 0.25),
                    ),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: const BoxDecoration(
                              color: Color(0xFF6BBD44),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Text(
                            'FONEPAY',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF6BBD44),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // QR code box
                      Container(
                        width: 190,
                        height: 190,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: AppColors.divider,
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: creatingPending
                            ? const Center(
                                child: SizedBox(
                                  width: 28,
                                  height: 28,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                ),
                              )
                            : createError != null
                                ? Center(
                                    child: IconButton(
                                      icon: const Icon(Icons.refresh_rounded,
                                          color: AppColors.danger, size: 32),
                                      onPressed: onRetryCreate,
                                      tooltip: 'Retry generating QR',
                                    ),
                                  )
                                : qrData != null
                                    ? Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: QrImageView(
                                          data: qrData!,
                                          size: 174,
                                          backgroundColor: Colors.white,
                                        ),
                                      )
                                    : const Icon(Icons.qr_code_2_rounded,
                                        size: 150, color: Colors.black87),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Rs ${total.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF6BBD44),
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
                if (createError != null)
                  Text(
                    'Could not generate QR: $createError',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 13, color: AppColors.danger),
                  )
                else if (creatingPending)
                  const Text(
                    'Generating secure QR code…',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                  )
                else ...[
                  // Waiting pulse
                  AnimatedBuilder(
                    animation: pulse,
                    builder: (_, child) =>
                        Opacity(opacity: 0.4 + 0.6 * pulse.value, child: child),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: const Color(0xFF6BBD44),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Waiting for payment…',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Steps
                  ...[
                    ('1', 'Open Fonepay app'),
                    ('2', 'Tap "Scan QR" and point camera here'),
                    ('3', 'Confirm Rs ${total.toStringAsFixed(2)} in the app'),
                  ].map(
                    (s) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 20,
                            height: 20,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceVariant,
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: Text(
                                s.$1,
                                style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              s.$2,
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // The cashier reads this off the Fonepay payment
                  // notification/app after the customer pays — this is what
                  // fonepay-verify actually checks against, replacing what
                  // used to be an unchecked "Payment Received" tap.
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'FONEPAY REFERENCE NUMBER',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: refCtrl,
                    enabled: !isVerifying,
                    textCapitalization: TextCapitalization.characters,
                    decoration: InputDecoration(
                      hintText: 'e.g. FP24081512345',
                      filled: true,
                      fillColor: AppColors.background,
                      errorText: verifyError,
                      border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
        _BigBtn(
          label: isVerifying ? 'Verifying…' : 'Verify Payment',
          onTap: (qrData == null || isVerifying)
              ? null
              : () {
                  final ref = refCtrl.text.trim();
                  if (ref.isEmpty) return;
                  onVerify(ref);
                },
          color: const Color(0xFF6BBD44),
          isLoading: isVerifying,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

// ─── Step 2c: Split ───────────────────────────────────────────────────────────

class _SplitStep extends HookWidget {
  const _SplitStep({
    required this.total,
    required this.cashInput,
    required this.onBack,
    required this.onConfirm,
    this.isProcessing = false,
  });
  final double total;
  final ValueNotifier<String> cashInput;
  final VoidCallback onBack;
  final VoidCallback onConfirm;
  final bool isProcessing;

  @override
  Widget build(BuildContext context) {
    final cash = double.tryParse(cashInput.value) ?? 0;
    final fonepay = (total - cash).clamp(0.0, total);
    final ok = cash > 0 && fonepay > 0 && cash <= total;

    return Column(
      children: [
        _BackHeader(
          title: 'Split Payment',
          onBack: onBack,
          right: Text(
            'Rs ${total.toStringAsFixed(2)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Cash input tile
                _SplitTile(
                  icon: Icons.payments_outlined,
                  label: 'Cash',
                  valueText: cashInput.value == '0'
                      ? '—'
                      : 'Rs ${cashInput.value}',
                  isActive: true,
                  color: Colors.black,
                ),
                const SizedBox(height: 8),
                // Fonepay tile (auto)
                _SplitTile(
                  icon: Icons.qr_code_rounded,
                  label: 'Fonepay QR',
                  valueText: cash > 0
                      ? 'Rs ${fonepay.toStringAsFixed(2)}'
                      : '—',
                  isActive: false,
                  color: const Color(0xFF6BBD44),
                  note: 'Auto-calculated',
                ),
                if (cash > total)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Row(
                      children: [
                        Icon(
                          Icons.warning_amber_rounded,
                          size: 14,
                          color: AppColors.danger,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Exceeds total',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                // Quick split chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip(
                        label: '50 / 50',
                        onTap: () =>
                            cashInput.value = (total / 2).toStringAsFixed(0),
                      ),
                      _Chip(
                        label: '25 cash',
                        onTap: () =>
                            cashInput.value = (total * 0.25).toStringAsFixed(0),
                      ),
                      _Chip(
                        label: '75 cash',
                        onTap: () =>
                            cashInput.value = (total * 0.75).toStringAsFixed(0),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: _FlexNumpad(
                    onKey: (k) =>
                        cashInput.value = _applyKey(cashInput.value, k),
                  ),
                ),
              ],
            ),
          ),
        ),
        _BigBtn(
          label: ok ? 'Process Split Payment' : 'Enter Cash Amount',
          onTap: onConfirm,
          enabled: ok,
          isLoading: isProcessing,
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}

class _SplitTile extends StatelessWidget {
  const _SplitTile({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.isActive,
    required this.color,
    this.note,
  });
  final IconData icon;
  final String label;
  final String valueText;
  final bool isActive;
  final Color color;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: isActive ? Colors.white : AppColors.background,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: isActive ? color : AppColors.divider,
        width: isActive ? 1.5 : 1,
      ),
    ),
    child: Row(
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              if (note != null)
                Text(
                  note!,
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textTertiary,
                  ),
                ),
            ],
          ),
        ),
        Text(
          valueText,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ],
    ),
  );
}

// ─── Step 3: Success ──────────────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({
    required this.total,
    required this.method,
    required this.customer,
    required this.change,
    required this.cashPaid,
    required this.fonepayPaid,
    required this.items,
    required this.subtotal,
    required this.manualAdjustment,
    required this.onNewSale,
  });
  final double total;
  final PaymentMethod method;
  final CustomerModel? customer;
  final double? change;
  final double? cashPaid;
  final double? fonepayPaid;
  // Services / Subtotal / Manual Adjustment breakdown — snapshotted at the
  // moment checkout() succeeded (see ReviewSaleSheet.build's completedItems/
  // completedQuote), since the live cart is cleared right after. Empty
  // items + null subtotal means a keypad-only custom-amount sale, which has
  // no service breakdown to show.
  final List<CartItem> items;
  final double? subtotal;
  final double manualAdjustment;
  final VoidCallback onNewSale;

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
                  _Row('Method', switch (method) {
                    PaymentMethod.cash => 'Cash',
                    PaymentMethod.fonepay => 'Fonepay QR',
                    PaymentMethod.split => 'Split',
                  }),
                  if (customer != null) ...[
                    const SizedBox(height: 10),
                    _Row('Customer', customer!.fullName),
                  ],
                  if (method == PaymentMethod.split &&
                      cashPaid != null &&
                      fonepayPaid != null) ...[
                    const SizedBox(height: 10),
                    _Row('Cash', 'Rs ${cashPaid!.toStringAsFixed(2)}'),
                    const SizedBox(height: 6),
                    _Row('Fonepay', 'Rs ${fonepayPaid!.toStringAsFixed(2)}'),
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
            _BigBtn(label: 'Print Receipt', onTap: () {}, outlined: true),
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
