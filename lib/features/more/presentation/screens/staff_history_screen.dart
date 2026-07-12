import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/staff/presentation/providers/staff_provider.dart';
import '../../../../features/transactions/domain/transaction_models.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

final _nprFmt = NumberFormat('#,##0.00', 'en_IN');

String _formatNpr(double amount) => 'Rs ${_nprFmt.format(amount)}';

String _formatTime(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$h:$m $period';
}

String _dayKey(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  if (d == today) return 'Today';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday';
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month]} ${dt.day}, ${dt.year}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class StaffHistoryScreen extends HookConsumerWidget {
  const StaffHistoryScreen({super.key, required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txState = ref.watch(staffHistoryProvider(staffId));
    final notifier = ref.read(staffHistoryProvider(staffId).notifier);
    final staffAsync = ref.watch(staffDetailProvider(staffId));

    final scrollCtrl = useScrollController();

    useEffect(() {
      void listener() {
        final pos = scrollCtrl.position;
        if (pos.pixels >= pos.maxScrollExtent - 300) {
          notifier.loadMore();
        }
      }

      scrollCtrl.addListener(listener);
      return () => scrollCtrl.removeListener(listener);
    }, [scrollCtrl]);

    final grouped = <String, List<Transaction>>{};
    for (final t in txState.items) {
      grouped.putIfAbsent(_dayKey(t.createdAt), () => []).add(t);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.pop(),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.black),
                  ),
                  const Spacer(),
                  Column(
                    children: [
                      const Text('Transaction History',
                          style: TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w600)),
                      staffAsync.when(
                        data: (s) => Text(s.fullName,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                  const Spacer(),
                  const SizedBox(width: 18),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: txState.isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : txState.error != null && txState.items.isEmpty
                      ? _ErrorState(
                          message: txState.error!,
                          onRetry: notifier.refresh,
                        )
                      : grouped.isEmpty
                          ? const _EmptyState()
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 32),
                              itemCount:
                                  _listItemCount(grouped, txState),
                              itemBuilder: (context, index) => _buildListItem(
                                  context, index, grouped, txState),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  int _listItemCount(
    Map<String, List<Transaction>> grouped,
    TransactionListState state,
  ) {
    var count = 0;
    for (final g in grouped.values) {
      count += 1 + g.length; // header + items
    }
    if (state.isLoadingMore || state.hasMore) count++;
    return count;
  }

  Widget _buildListItem(
    BuildContext context,
    int index,
    Map<String, List<Transaction>> grouped,
    TransactionListState state,
  ) {
    var i = 0;
    for (final entry in grouped.entries) {
      if (index == i) return _DayHeader(label: entry.key);
      i++;
      for (final t in entry.value) {
        if (index == i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _HistoryRow(
              transaction: t,
              onTap: () => context.push(AppRoutes.transactionDetail(t.id)),
            ),
          );
        }
        i++;
      }
    }
    if (state.isLoadingMore) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
          ),
        ),
      );
    }
    return const SizedBox.shrink();
  }
}

// ─── Day header ───────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 12, 2, 8),
        child: Text(
          label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary),
        ),
      );
}

// ─── Transaction row ────────────────────────────────────────────────────────

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.transaction, required this.onTap});
  final Transaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (transaction.status) {
      TransactionStatus.completed =>
        ('Completed', AppColors.successLight, const Color(0xFF16A34A)),
      TransactionStatus.partiallyRefunded =>
        ('Part. Refunded', const Color(0xFFFFFBEB), const Color(0xFFD97706)),
      TransactionStatus.refunded =>
        ('Refunded', AppColors.dangerLight, AppColors.danger),
      TransactionStatus.voided =>
        ('Voided', AppColors.surfaceVariant, AppColors.textSecondary),
      _ => ('Pending', AppColors.primaryLight, AppColors.primary),
    };

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(transaction.displayId,
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                      const Spacer(),
                      Text(_formatNpr(transaction.total),
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.black)),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(transaction.displayName,
                            style: const TextStyle(
                                fontSize: 13, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                            color: bg, borderRadius: BorderRadius.circular(5)),
                        child: Text(label,
                            style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: fg)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(_formatTime(transaction.createdAt),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textTertiary)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ─── Empty / error states ─────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.receipt_long_outlined,
                size: 48, color: AppColors.textTertiary),
            SizedBox(height: 14),
            Text('No transactions yet',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          ],
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 14),
            const Text('Failed to load history',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            Text(message,
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Text('Retry',
                    style: TextStyle(color: Colors.white, fontSize: 13)),
              ),
            ),
          ],
        ),
      );
}
