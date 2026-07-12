import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/transactions/domain/transaction_models.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

final _nprFmt = NumberFormat('#,##0.00', 'en_IN');
final _dateFmt = DateFormat('dd MMM yyyy HH:mm');

String _fmtNpr(double amount) => 'Rs ${_nprFmt.format(amount)}';
String _fmtDate(DateTime dt) => _dateFmt.format(dt);

String _displayId(RefundRecord r) {
  if (r.receiptNumber != null) return r.receiptNumber!;
  final short =
      r.transactionId.length > 8 ? r.transactionId.substring(0, 8) : r.transactionId;
  return '#${short.toUpperCase()}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RefundsScreen extends ConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final histState = ref.watch(refundHistoryProvider);
    final notifier = ref.read(refundHistoryProvider.notifier);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => context.go(AppRoutes.more),
        ),
        title: const Text('Refund History',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 16),

            // ── Content ───────────────────────────────────────────────────
            Expanded(
              child: histState.isLoading
                  ? const _RefundSkeleton()
                  : histState.error != null && histState.items.isEmpty
                      ? _ErrorState(onRetry: notifier.refresh)
                      : histState.items.isEmpty
                          ? const _EmptyState()
                          : _RefundList(
                              state: histState, notifier: notifier),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Refund list (infinite scroll) ───────────────────────────────────────────

class _RefundList extends HookWidget {
  const _RefundList({required this.state, required this.notifier});
  final RefundHistoryState state;
  final RefundHistoryNotifier notifier;

  @override
  Widget build(BuildContext context) {
    final scrollCtrl = useScrollController();

    useEffect(() {
      void listener() {
        if (scrollCtrl.position.pixels >=
            scrollCtrl.position.maxScrollExtent - 300) {
          notifier.loadMore();
        }
      }
      scrollCtrl.addListener(listener);
      return () => scrollCtrl.removeListener(listener);
    }, [scrollCtrl]);

    return ListView.builder(
      controller: scrollCtrl,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      itemCount: state.items.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (_, i) {
        if (i == state.items.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    color: Colors.black, strokeWidth: 2),
              ),
            ),
          );
        }
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _RefundRow(refund: state.items[i]),
        );
      },
    );
  }
}

// ─── Refund row ───────────────────────────────────────────────────────────────

class _RefundRow extends StatelessWidget {
  const _RefundRow({required this.refund});
  final RefundRecord refund;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetail(context, refund),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  _displayId(refund),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.4,
                  ),
                ),
                const Spacer(),
                Text(
                  _fmtNpr(refund.amount),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: AppColors.danger,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              refund.customerName ?? 'Walk-in',
              style: const TextStyle(
                  fontSize: 14, color: Colors.black87),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.notes_rounded,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    refund.reason,
                    style: const TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time_rounded,
                    size: 13, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  _fmtDate(refund.createdAt),
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textTertiary),
                ),
                if (refund.processedByName != null) ...[
                  const SizedBox(width: 6),
                  Container(
                      width: 3,
                      height: 3,
                      decoration: const BoxDecoration(
                          color: AppColors.border,
                          shape: BoxShape.circle)),
                  const SizedBox(width: 6),
                  Text(
                    refund.processedByName!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ],
                const Spacer(),
                const Icon(Icons.chevron_right_rounded,
                    size: 16, color: AppColors.textTertiary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context, RefundRecord refund) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RefundDetailSheet(refund: refund),
    );
  }
}

// ─── Refund detail sheet ──────────────────────────────────────────────────────

class _RefundDetailSheet extends StatelessWidget {
  const _RefundDetailSheet({required this.refund});
  final RefundRecord refund;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Drag handle
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Amount (hero)
              Center(
                child: Text(
                  _fmtNpr(refund.amount),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: AppColors.danger,
                  ),
                ),
              ),
              const Center(
                child: Padding(
                  padding: EdgeInsets.only(top: 4),
                  child: Text(
                    'Refund Amount',
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textTertiary),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Details card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Column(
                  children: [
                    _DetailRow(
                        label: 'Transaction',
                        value: _displayId(refund)),
                    if (refund.customerName != null) ...[
                      const SizedBox(height: 10),
                      _DetailRow(
                          label: 'Customer',
                          value: refund.customerName!),
                    ],
                    const SizedBox(height: 10),
                    _DetailRow(label: 'Reason', value: refund.reason),
                    const SizedBox(height: 10),
                    _DetailRow(
                        label: 'Date',
                        value: _fmtDate(refund.createdAt)),
                    if (refund.processedByName != null) ...[
                      const SizedBox(height: 10),
                      _DetailRow(
                          label: 'Processed by',
                          value: refund.processedByName!),
                    ],
                  ],
                ),
              ),

              // Items refunded
              if (refund.items != null && refund.items!.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'ITEMS REFUNDED',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                    letterSpacing: 0.8,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.divider),
                  ),
                  child: Column(
                    children: refund.items!
                        .map(
                          (item) => Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        item.displayName ?? 'Item',
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500),
                                      ),
                                      Text(
                                        '${_fmtNpr(item.unitPrice)} × ${item.quantity}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                                Text(
                                  _fmtNpr(item.unitPrice * item.quantity),
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 110,
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textTertiary)),
        ),
        Expanded(
          child: Text(value,
              style: const TextStyle(
                  fontSize: 13, fontWeight: FontWeight.w500)),
        ),
      ],
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _RefundSkeleton extends StatelessWidget {
  const _RefundSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.divider,
      highlightColor: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        itemCount: 8,
        itemBuilder: (_, i) => Container(
          height: 104,
          margin: const EdgeInsets.only(bottom: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.receipt_long_outlined,
              size: 48, color: AppColors.textTertiary),
          SizedBox(height: 14),
          Text('No refunds yet',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          SizedBox(height: 6),
          Text('Processed refunds will appear here',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text('Failed to load refunds',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
