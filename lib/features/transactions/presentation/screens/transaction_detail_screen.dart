import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../data/transactions_repository.dart';
import '../../domain/transaction_models.dart';
import '../providers/transactions_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/pull_to_refresh.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

final _nprFmt = NumberFormat('#,##0.00', 'en_IN');
final _dtFmt = DateFormat('dd MMM yyyy HH:mm');

String _formatNpr(double amount) => 'Rs ${_nprFmt.format(amount)}';
String _formatDateTime(DateTime dt) => _dtFmt.format(dt);

final _detailRepoProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.read(apiClientProvider)),
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class TransactionDetailScreen extends HookConsumerWidget {
  const TransactionDetailScreen({super.key, required this.transactionId});
  final String transactionId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(transactionDetailProvider(transactionId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: PullToRefresh(
          onRefresh: () =>
              ref.refresh(transactionDetailProvider(transactionId).future),
          child: txAsync.when(
          loading: () => Column(
            children: [
              _Header(title: 'Transaction', onBack: () => Navigator.of(context).pop()),
              const Expanded(child: _DetailSkeleton()),
            ],
          ),
          error: (e, _) => Column(
            children: [
              _Header(title: 'Transaction', onBack: () => Navigator.of(context).pop()),
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 48, color: AppColors.textTertiary),
                      const SizedBox(height: 12),
                      const Text('Failed to load transaction',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      Text(e.toString(),
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textTertiary),
                          textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      GestureDetector(
                        onTap: () => ref.invalidate(
                          transactionDetailProvider(transactionId),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Text('Retry',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          data: (tx) => _DetailBody(transaction: tx),
          ),
        ),
      ),
    );
  }
}

// ─── Detail body ──────────────────────────────────────────────────────────────

class _DetailBody extends HookConsumerWidget {
  const _DetailBody({required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _Header(
          title: transaction.displayId,
          onBack: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Status + date ──────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          _StatusBadge(status: transaction.status),
                          const Spacer(),
                          _PaymentBadge(method: transaction.paymentMethod),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _InfoRow(
                          label: 'Customer',
                          value: transaction.displayName),
                      if (transaction.processedByDisplayName != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(
                            label: 'Processed by',
                            value: transaction.processedByDisplayName!),
                      ],
                      const SizedBox(height: 8),
                      _InfoRow(
                          label: 'Date',
                          value: _formatDateTime(transaction.createdAt)),
                      if (transaction.notes != null) ...[
                        const SizedBox(height: 8),
                        _InfoRow(label: 'Notes', value: transaction.notes!),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // ── Pending Fonepay payment ────────────────────────────────
                // Safety net for "the app closed/crashed while this sale was
                // still awaiting Fonepay confirmation" — without this, a
                // PENDING transaction is only actionable from the checkout
                // sheet's own local state, which doesn't survive a restart.
                // Reachable here any time from the transaction list/detail,
                // independent of how the app got here.
                if (transaction.status == TransactionStatus.pending &&
                    transaction.paymentMethod == TxPaymentMethod.fonepay) ...[
                  _PendingFonepayPanel(transaction: transaction),
                  const SizedBox(height: 14),
                ],

                // ── Items ──────────────────────────────────────────────────
                if (transaction.items != null &&
                    transaction.items!.isNotEmpty) ...[
                  const _SectionLabel(text: 'ITEMS'),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(
                      children: transaction.items!
                          .map((item) => _ItemRow(item: item))
                          .toList(),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // ── Payment breakdown ──────────────────────────────────────
                const _SectionLabel(text: 'PAYMENT SUMMARY'),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: [
                      if (transaction.subtotal != null &&
                          transaction.subtotal != transaction.total) ...[
                        _SummaryRow(
                            label: 'Subtotal',
                            value: _formatNpr(transaction.subtotal!)),
                        const SizedBox(height: 6),
                      ],
                      if (transaction.discountAmount != null &&
                          transaction.discountAmount! > 0) ...[
                        _SummaryRow(
                          label: 'Discount',
                          value: '– ${_formatNpr(transaction.discountAmount!)}',
                          valueColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (transaction.hasManualAdjustment) ...[
                        _SummaryRow(
                          label: 'Manual Adjustment',
                          value:
                              '${transaction.manualAdjustment! > 0 ? '+' : '–'} '
                              '${_formatNpr(transaction.manualAdjustment!.abs())}',
                          valueColor: const Color(0xFF16A34A),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (transaction.tipAmount != null &&
                          transaction.tipAmount! > 0) ...[
                        _SummaryRow(
                            label: 'Tip',
                            value: _formatNpr(transaction.tipAmount!)),
                        const SizedBox(height: 6),
                      ],
                      if (transaction.refundAmount != null &&
                          transaction.refundAmount! > 0) ...[
                        _SummaryRow(
                          label: 'Refunded',
                          value:
                              '– ${_formatNpr(transaction.refundAmount!)}',
                          valueColor: AppColors.danger,
                        ),
                        const SizedBox(height: 6),
                      ],
                      const Divider(height: 16, color: AppColors.divider),
                      Row(
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _formatNpr(transaction.total),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: Colors.black,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                if (transaction.isRefundable) ...[
                  const SizedBox(height: 10),
                  GestureDetector(
                    onTap: () => _showRefundSheet(context, transaction),
                    child: Container(
                      height: 50,
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                            color: AppColors.danger
                                .withValues(alpha: 0.3)),
                      ),
                      alignment: Alignment.center,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.keyboard_return_rounded,
                              size: 18, color: AppColors.danger),
                          SizedBox(width: 8),
                          Text(
                            'Issue Refund',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  void _showRefundSheet(BuildContext context, Transaction tx) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RefundSheet(transaction: tx),
    );
  }
}

// ─── Pending Fonepay action panel ─────────────────────────────────────────────

class _PendingFonepayPanel extends HookConsumerWidget {
  const _PendingFonepayPanel({required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refCtrl = useTextEditingController();
    final verifying = useState(false);
    final cancelling = useState(false);
    final error = useState<String?>(null);

    void refreshAfterResolution() {
      ref.invalidate(transactionDetailProvider(transaction.id));
      ref.invalidate(transactionListProvider);
      ref.invalidate(refundHistoryProvider);
      ref.invalidate(todayRevenueProvider);
      ref.invalidate(dashboardProvider);
    }

    Future<void> verify() async {
      final reference = refCtrl.text.trim();
      if (reference.isEmpty) {
        error.value = 'Enter the Fonepay reference number';
        return;
      }
      verifying.value = true;
      error.value = null;
      try {
        await ref
            .read(_detailRepoProvider)
            .verifyFonepay(transaction.id, reference);
        if (!context.mounted) return;
        refreshAfterResolution();
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Payment verified'),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
        ));
      } catch (e) {
        error.value = e.toString();
      } finally {
        if (context.mounted) verifying.value = false;
      }
    }

    Future<void> cancel() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cancel this sale?'),
          content: const Text(
              'This releases the held stock. Only do this if the customer never actually paid.'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Back'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancel Sale',
                  style: TextStyle(color: AppColors.danger)),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      cancelling.value = true;
      error.value = null;
      try {
        await ref.read(_detailRepoProvider).cancelPendingFonepay(transaction.id);
        if (!context.mounted) return;
        refreshAfterResolution();
      } catch (e) {
        error.value = e.toString();
      } finally {
        if (context.mounted) cancelling.value = false;
      }
    }

    final busy = verifying.value || cancelling.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF6BBD44).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.hourglass_top_rounded, size: 16, color: Color(0xFF6BBD44)),
              SizedBox(width: 6),
              Text('Awaiting Fonepay payment',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 4),
          const Text(
            'This sale is still pending — it has no receipt and isn\'t counted as '
            'revenue until verified. Enter the Fonepay reference number once the '
            'customer has paid.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: refCtrl,
            enabled: !busy,
            textCapitalization: TextCapitalization.characters,
            decoration: InputDecoration(
              hintText: 'Fonepay reference number',
              filled: true,
              fillColor: Colors.white,
              errorText: error.value,
              isDense: true,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: busy ? null : cancel,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                  child: cancelling.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Cancel Sale'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: busy ? null : verify,
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF6BBD44)),
                  child: verifying.value
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Verify Payment'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Refund sheet ─────────────────────────────────────────────────────────────

class _RefundSheet extends HookConsumerWidget {
  const _RefundSheet({required this.transaction});
  final Transaction transaction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = transaction.items ?? [];
    final refundQtys =
        useState<List<int>>(List.filled(items.length, 0));
    final fullRefund = useState(false);
    final reasonCtrl = useTextEditingController();
    final reasonError = useState<String?>(null);
    final processing = useState(false);

    void toggleFull(bool val) {
      fullRefund.value = val;
      refundQtys.value = val
          ? items.map((i) => i.maxRefundable).toList()
          : List.filled(items.length, 0);
    }

    void setQty(int idx, int qty) {
      final list = List<int>.from(refundQtys.value);
      list[idx] = qty.clamp(0, items[idx].maxRefundable);
      refundQtys.value = list;
      fullRefund.value = items.isEmpty
          ? false
          : list.asMap().entries
              .every((e) => e.value == items[e.key].maxRefundable);
    }

    // Rough local estimate — used only to decide whether there's anything
    // to preview at all. Never shown to the user or submitted; the real
    // amount (tax- and discount-accurate) comes from the server preview
    // below, since raw unitPrice sums can't account for either.
    bool hasAnySelection() =>
        fullRefund.value || refundQtys.value.any((q) => q > 0);

    // Authoritative refund amount from the server — refetched whenever the
    // selection changes, exactly mirroring the checkout quote pattern (see
    // ReviewSaleSheet): the client cannot itself compute tax/discount
    // proration, so "Confirm Refund" is gated on this being fresh and
    // successful rather than ever letting the cashier confirm a guessed
    // number.
    final preview = useState<double?>(null);
    final previewing = useState(false);
    final previewError = useState<String?>(null);

    useEffect(() {
      if (!hasAnySelection()) {
        preview.value = null;
        previewError.value = null;
        previewing.value = false;
        return null;
      }
      var cancelled = false;
      previewing.value = true;
      preview.value = null;
      previewError.value = null;
      final timer = Timer(const Duration(milliseconds: 350), () {
        final requestItems = fullRefund.value && items.isEmpty
            ? const <({String transactionItemId, int quantity})>[]
            : items
                .asMap()
                .entries
                .where((e) => refundQtys.value[e.key] > 0)
                .map((e) => (
                      transactionItemId: e.value.id,
                      quantity: refundQtys.value[e.key],
                    ))
                .toList();
        ref
            .read(_detailRepoProvider)
            .previewRefund(transaction.id, requestItems)
            .then((amount) {
          if (cancelled) return;
          preview.value = amount;
          previewing.value = false;
        }).catchError((dynamic e) {
          if (cancelled) return;
          previewError.value = e.toString();
          previewing.value = false;
        });
      });
      return () {
        cancelled = true;
        timer.cancel();
      };
    }, [fullRefund.value, refundQtys.value]);

    Future<void> confirm() async {
      if (processing.value) return;
      final reason = reasonCtrl.text.trim();
      if (reason.length < 5) {
        reasonError.value = 'Reason must be at least 5 characters';
        return;
      }

      final hasSelection = fullRefund.value ||
          refundQtys.value.any((q) => q > 0);
      if (!hasSelection) {
        reasonError.value =
            'Select at least one item or enable Full Refund';
        return;
      }
      // Never submit against a stale/unconfirmed amount — if the preview
      // hasn't resolved yet (or failed), there's nothing accurate to show
      // the cashier a receipt for.
      final confirmedAmount = preview.value;
      if (confirmedAmount == null || previewing.value) return;
      processing.value = true;
      try {
        final dto = CreateRefundDto(
          reason: reason,
          items: fullRefund.value
              ? []
              : items
                  .asMap()
                  .entries
                  .where((e) => refundQtys.value[e.key] > 0)
                  .map((e) => (
                        transactionItemId: e.value.id,
                        quantity: refundQtys.value[e.key],
                      ))
                  .toList(),
        );
        await ref
            .read(_detailRepoProvider)
            .createRefund(transaction.id, dto);
        if (!context.mounted) return;
        ref.invalidate(transactionDetailProvider(transaction.id));
        ref.invalidate(transactionListProvider);
        ref.invalidate(refundHistoryProvider);
        ref.invalidate(todayRevenueProvider);
        ref.invalidate(dashboardProvider);
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              'Refund of ${_formatNpr(confirmedAmount)} processed'),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ));
      } catch (e) {
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Refund failed: $e'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ));
      } finally {
        if (context.mounted) processing.value = false;
      }
    }

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12, bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                // Title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text('Issue Refund',
                      style: TextStyle(
                          fontSize: 19, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    '${transaction.displayId} · ${transaction.displayName}',
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textTertiary),
                  ),
                ),
                const SizedBox(height: 16),

                // Mode toggle
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      const Text('Full Refund',
                          style: TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600)),
                      const Spacer(),
                      Switch(
                        value: fullRefund.value,
                        onChanged: toggleFull,
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.black,
                      ),
                    ],
                  ),
                ),
                // Items
                if (items.isNotEmpty) ...[
                  const Divider(height: 1, color: AppColors.divider),
                  ...items.asMap().entries.map((e) {
                    final item = e.value;
                    final idx = e.key;
                    final qty = refundQtys.value[idx];
                    final max = item.maxRefundable;
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(item.displayName,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                Text(
                                  _formatNpr(item.unitPrice),
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondary),
                                ),
                                if ((item.refundedQty ?? 0) > 0)
                                  Text(
                                    '${item.refundedQty} already refunded',
                                    style: const TextStyle(
                                        fontSize: 11,
                                        color: Color(0xFFF59E0B)),
                                  ),
                              ],
                            ),
                          ),
                          // Stepper
                          Row(
                            children: [
                              _StepperBtn(
                                icon: Icons.remove,
                                onTap: max == 0
                                    ? null
                                    : () => setQty(idx, qty - 1),
                              ),
                              SizedBox(
                                width: 32,
                                child: Text(
                                  '$qty',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              ),
                              _StepperBtn(
                                icon: Icons.add,
                                onTap: max == 0 || qty >= max
                                    ? null
                                    : () => setQty(idx, qty + 1),
                              ),
                            ],
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 80,
                            child: Text(
                              _formatNpr(qty * item.unitPrice),
                              textAlign: TextAlign.end,
                              style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 14),
                  const Divider(height: 1, color: AppColors.divider),
                ],

                // Reason
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('REASON',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                            letterSpacing: 0.8,
                          )),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: reasonError.value != null
                                ? AppColors.danger
                                : AppColors.divider,
                          ),
                        ),
                        child: TextField(
                          controller: reasonCtrl,
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(fontSize: 15),
                          onChanged: (_) => reasonError.value = null,
                          decoration: const InputDecoration(
                            hintText: 'Enter reason for refund…',
                            hintStyle: TextStyle(
                                fontSize: 15,
                                color: AppColors.textTertiary),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(14),
                          ),
                        ),
                      ),
                      if (reasonError.value != null) ...[
                        const SizedBox(height: 6),
                        Text(reasonError.value!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger)),
                      ],
                    ],
                  ),
                ),

                // Summary
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                  child: Row(
                    children: [
                      const Text('Refund Total',
                          style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600)),
                      const Spacer(),
                      if (previewing.value)
                        const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (previewError.value != null)
                        const Text('Could not confirm amount',
                            style: TextStyle(
                                fontSize: 13, color: AppColors.danger))
                      else
                        Text(
                          preview.value != null
                              ? _formatNpr(preview.value!)
                              : '—',
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: AppColors.danger,
                          ),
                        ),
                    ],
                  ),
                ),

                // Confirm button
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: GestureDetector(
                    onTap: (processing.value ||
                            previewing.value ||
                            preview.value == null)
                        ? null
                        : confirm,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: (processing.value ||
                                previewing.value ||
                                preview.value == null)
                            ? AppColors.textSecondary
                            : Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: processing.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    color: Colors.white, strokeWidth: 2),
                              )
                            : const Text('Confirm Refund',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                )),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Stepper button ───────────────────────────────────────────────────────────

class _StepperBtn extends StatelessWidget {
  const _StepperBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 28,
        height: 28,
        decoration: BoxDecoration(
          color: onTap == null
              ? AppColors.surfaceVariant
              : AppColors.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.divider),
        ),
        child: Icon(icon,
            size: 14,
            color: onTap == null
                ? AppColors.border
                : Colors.black),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

// ─── Detail skeleton ──────────────────────────────────────────────────────────

class _DetailSkeleton extends StatelessWidget {
  const _DetailSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.divider,
      highlightColor: AppColors.background,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        child: Column(
          children: [
            Container(
              height: 110,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 160,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              height: 130,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
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
          const SizedBox(width: 18),
        ],
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.8,
      ),
    );
  }
}

// ─── Info row ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textTertiary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Item row ─────────────────────────────────────────────────────────────────

class _ItemRow extends StatelessWidget {
  const _ItemRow({required this.item});
  final TransactionItem item;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.displayName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                ),
                if (item.staffName != null)
                  Text(
                    item.staffName!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textTertiary,
                    ),
                  ),
                Text(
                  '${_formatNpr(item.unitPrice)} × ${item.quantity}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            _formatNpr(item.total),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary row ──────────────────────────────────────────────────────────────

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
  });
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: valueColor ?? AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

// ─── Status badge ─────────────────────────────────────────────────────────────

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      TransactionStatus.completed =>
        ('Completed', AppColors.successLight, const Color(0xFF16A34A)),
      TransactionStatus.partiallyRefunded =>
        ('Partially Refunded', const Color(0xFFFFFBEB), const Color(0xFFD97706)),
      TransactionStatus.refunded =>
        ('Refunded', AppColors.dangerLight, AppColors.danger),
      TransactionStatus.voided =>
        ('Voided', AppColors.surfaceVariant, AppColors.textSecondary),
      _ => ('Pending', AppColors.primaryLight, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─── Payment badge ────────────────────────────────────────────────────────────

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.method});
  final TxPaymentMethod method;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (method) {
      TxPaymentMethod.fonepay =>
        ('Fonepay', const Color(0xFFE8EDD6), const Color(0xFF4D5A2C)),
      TxPaymentMethod.split =>
        ('Split', AppColors.primaryLight, AppColors.primaryDark),
      _ => ('Cash', AppColors.successLight, const Color(0xFF16A34A)),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}
