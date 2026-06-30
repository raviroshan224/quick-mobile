import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/transaction_models.dart';
import '../providers/transactions_provider.dart';
import '../../../../core/theme/app_theme.dart';

// ─── Helpers ──────────────────────────────────────────────────────────────────

final _nprFmt = NumberFormat('#,##0.00', 'en_IN');

String _formatNpr(double amount) => 'NPR ${_nprFmt.format(amount)}';

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  final t = '$h:$m $period';
  if (d == today) return 'Today · $t';
  if (d == today.subtract(const Duration(days: 1))) return 'Yesterday · $t';
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month]} ${dt.day} · $t';
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

String _shortDate(DateTime dt) {
  const months = [
    '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month]} ${dt.day}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class TransactionsScreen extends HookConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txState = ref.watch(transactionListProvider);
    final notifier = ref.read(transactionListProvider.notifier);

    final scrollCtrl = useScrollController();

    // Infinite scroll trigger
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

    // Group transactions by day
    final grouped = <String, List<Transaction>>{};
    for (final t in txState.items) {
      grouped.putIfAbsent(_dayKey(t.createdAt), () => []).add(t);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'Transactions',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    _shortDate(DateTime.now()),
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Volume card ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: const _VolumeCard(),
            ),

            const SizedBox(height: 14),

            // ── Status filter chips ─────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: txState.statusFilter == null,
                    onTap: () => notifier.setStatusFilter(null),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Completed',
                    selected: txState.statusFilter == 'COMPLETED',
                    onTap: () => notifier.setStatusFilter(
                      txState.statusFilter == 'COMPLETED' ? null : 'COMPLETED',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Refunded',
                    selected: txState.statusFilter == 'REFUNDED',
                    onTap: () => notifier.setStatusFilter(
                      txState.statusFilter == 'REFUNDED' ? null : 'REFUNDED',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Voided',
                    selected: txState.statusFilter == 'VOIDED',
                    onTap: () => notifier.setStatusFilter(
                      txState.statusFilter == 'VOIDED' ? null : 'VOIDED',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 8),

            // ── Payment + date filter row ────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _FilterChip(
                    label: 'Cash',
                    selected: txState.paymentFilter == 'CASH',
                    onTap: () => notifier.setPaymentFilter(
                      txState.paymentFilter == 'CASH' ? null : 'CASH',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Fonepay',
                    selected: txState.paymentFilter == 'FONEPAY',
                    onTap: () => notifier.setPaymentFilter(
                      txState.paymentFilter == 'FONEPAY' ? null : 'FONEPAY',
                    ),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Split',
                    selected: txState.paymentFilter == 'SPLIT',
                    onTap: () => notifier.setPaymentFilter(
                      txState.paymentFilter == 'SPLIT' ? null : 'SPLIT',
                    ),
                  ),
                  const SizedBox(width: 12),
                  _DateRangeButton(
                    dateFrom: txState.dateFrom,
                    dateTo: txState.dateTo,
                    onPick: (from, to) => notifier.setDateRange(from, to),
                    onClear: () => notifier.setDateRange(null, null),
                    context: context,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── List ─────────────────────────────────────────────────────────
            Expanded(
              child: txState.isLoading
                  ? const _LoadingSkeleton()
                  : txState.error != null && txState.items.isEmpty
                      ? _ErrorState(
                          message: txState.error!,
                          onRetry: notifier.refresh,
                        )
                      : txState.items.isEmpty
                          ? const _EmptyState()
                          : ListView.builder(
                              controller: scrollCtrl,
                              padding:
                                  const EdgeInsets.fromLTRB(20, 0, 20, 100),
                              itemCount: _listItemCount(grouped, txState),
                              itemBuilder: (context, index) {
                                return _buildListItem(
                                  context,
                                  index,
                                  grouped,
                                  txState,
                                );
                              },
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
      for (final tx in entry.value) {
        if (index == i) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _TransactionRow(
              transaction: tx,
              onTap: () => context.push(AppRoutes.transactionDetail(tx.id)),
            ),
          );
        }
        i++;
      }
    }
    // Load more indicator at the end
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

// ─── Volume card ──────────────────────────────────────────────────────────────

class _VolumeCard extends ConsumerWidget {
  const _VolumeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(todayRevenueProvider);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.circular(14),
      ),
      child: summaryAsync.when(
        loading: () => const SizedBox(
          height: 60,
          child: Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                color: Colors.white38,
                strokeWidth: 2,
              ),
            ),
          ),
        ),
        error: (_, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text(
              "Today's Volume",
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
            SizedBox(height: 6),
            Text(
              'NPR —',
              style: TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        data: (s) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Today's Volume",
              style: TextStyle(color: AppColors.textTertiary, fontSize: 13),
            ),
            const SizedBox(height: 6),
            Text(
              _formatNpr(s.revenue),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 30,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                _VolumeChip(
                    label: '${s.sales} ${s.sales == 1 ? 'Sale' : 'Sales'}'),
                if (s.refunds > 0) ...[
                  const SizedBox(width: 8),
                  _VolumeChip(
                      label:
                          '${s.refunds} ${s.refunds == 1 ? 'Refund' : 'Refunds'}'),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeChip extends StatelessWidget {
  const _VolumeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.textTertiary, fontSize: 12),
      ),
    );
  }
}

// ─── Filter chip ──────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Date range button ────────────────────────────────────────────────────────

class _DateRangeButton extends StatelessWidget {
  const _DateRangeButton({
    required this.dateFrom,
    required this.dateTo,
    required this.onPick,
    required this.onClear,
    required this.context,
  });
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final void Function(DateTime from, DateTime to) onPick;
  final VoidCallback onClear;
  final BuildContext context;

  String _label() {
    if (dateFrom == null) return 'Date Range';
    const months = [
      '', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final from = '${months[dateFrom!.month]} ${dateFrom!.day}';
    if (dateTo == null || dateTo == dateFrom) return from;
    final to = '${months[dateTo!.month]} ${dateTo!.day}';
    return '$from – $to';
  }

  @override
  Widget build(BuildContext context) {
    final isActive = dateFrom != null;
    return GestureDetector(
      onTap: () async {
        final range = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2024),
          lastDate: DateTime.now(),
          initialDateRange: dateFrom != null
              ? DateTimeRange(
                  start: dateFrom!,
                  end: dateTo ?? dateFrom!,
                )
              : null,
          builder: (ctx, child) => Theme(
            data: ThemeData.light().copyWith(
              colorScheme: const ColorScheme.light(primary: Colors.black),
            ),
            child: child!,
          ),
        );
        if (range != null) onPick(range.start, range.end);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isActive ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? Colors.black : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.calendar_today_rounded,
              size: 13,
              color: isActive ? Colors.white : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              _label(),
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: isActive ? Colors.white : AppColors.textSecondary,
              ),
            ),
            if (isActive) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: const Icon(
                  Icons.close_rounded,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Day header ───────────────────────────────────────────────────────────────

class _DayHeader extends StatelessWidget {
  const _DayHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 6),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Transaction row ──────────────────────────────────────────────────────────

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.transaction,
    required this.onTap,
  });
  final Transaction transaction;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            _StatusDot(status: transaction.status),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        transaction.displayId,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        _formatNpr(transaction.total),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          transaction.displayName,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _StatusBadge(status: transaction.status),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Text(
                        _formatDate(transaction.createdAt),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      _PaymentBadge(method: transaction.paymentMethod),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.chevron_right_rounded,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Status dot ───────────────────────────────────────────────────────────────

class _StatusDot extends StatelessWidget {
  const _StatusDot({required this.status});
  final TransactionStatus status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      TransactionStatus.completed => const Color(0xFF10B981),
      TransactionStatus.partiallyRefunded => const Color(0xFFF59E0B),
      TransactionStatus.refunded => AppColors.danger,
      TransactionStatus.voided => AppColors.textTertiary,
      _ => AppColors.textSecondary,
    };
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
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
        ('Part. Refunded', const Color(0xFFFFFBEB), const Color(0xFFD97706)),
      TransactionStatus.refunded =>
        ('Refunded', AppColors.dangerLight, AppColors.danger),
      TransactionStatus.voided =>
        ('Voided', AppColors.surfaceVariant, AppColors.textSecondary),
      _ => ('Pending', AppColors.primaryLight, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
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
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: fg),
      ),
    );
  }
}

// ─── Loading skeleton ─────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.divider,
      highlightColor: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        itemCount: 8,
        itemBuilder: (_, i) => i % 4 == 0
            ? Container(
                height: 18,
                width: 80,
                margin: const EdgeInsets.fromLTRB(0, 12, 0, 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(6),
                ),
              )
            : Container(
                height: 82,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
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
          Icon(Icons.receipt_long_outlined, size: 48, color: AppColors.textTertiary),
          SizedBox(height: 14),
          Text(
            'No transactions found',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: 6),
          Text(
            'Try adjusting your filters',
            style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 14),
          const Text(
            'Failed to load transactions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            style: const TextStyle(fontSize: 12, color: AppColors.textTertiary),
            textAlign: TextAlign.center,
          ),
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
              child: const Text(
                'Retry',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
