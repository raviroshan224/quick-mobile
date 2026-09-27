import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/dashboard/presentation/providers/dashboard_provider.dart';
import '../../../../features/dashboard/models/dashboard_summary.dart';
import '../../../../features/inventory/presentation/providers/inventory_provider.dart';
import '../../../settings/presentation/providers/business_type_provider.dart';
import '../../../../features/transactions/data/transactions_repository.dart';
import '../../../../features/transactions/domain/transaction_models.dart';
import '../../../../shared/widgets/pull_to_refresh.dart';

// ─── Staff today stats provider ───────────────────────────────────────────────

final _staffTxRepoProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.read(apiClientProvider)),
);

typedef _TodayStats = ({int count, double revenue});

String _utcMs(DateTime local) {
  final u = local.toUtc();
  String p2(int n) => n.toString().padLeft(2, '0');
  String p3(int n) => n.toString().padLeft(3, '0');
  return '${u.year}-${p2(u.month)}-${p2(u.day)}'
      'T${p2(u.hour)}:${p2(u.minute)}:${p2(u.second)}.${p3(u.millisecond)}Z';
}

final _staffTodayStatsProvider =
    FutureProvider.autoDispose<_TodayStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return (count: 0, revenue: 0.0);
  final now = DateTime.now();
  final result = await ref.read(_staffTxRepoProvider).getAll(
        limit: 100,
        userId: user.id,
        from: _utcMs(DateTime(now.year, now.month, now.day)),
        to: _utcMs(DateTime(now.year, now.month, now.day, 23, 59, 59, 999)),
      );
  final revenue = result.items.fold(0.0, (s, t) {
    if (t.status == TransactionStatus.completed ||
        t.status == TransactionStatus.partiallyRefunded) {
      return s + t.total;
    }
    return s;
  });
  return (count: result.items.length, revenue: revenue);
});

String _staffInitials(String name) {
  final parts = name.trim().split(' ');
  if (parts.length >= 2) return (parts[0][0] + parts[1][0]).toUpperCase();
  return name.isEmpty ? '?' : name[0].toUpperCase();
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isOwner = user?.isOwner ?? false;

    final now = DateTime.now();
    final hour = now.hour;
    final greeting = hour < 12
        ? 'Good morning'
        : hour < 17
            ? 'Good afternoon'
            : 'Good evening';
    final firstName = user?.firstName ?? 'there';

    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final dateLabel =
        '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';

    final header = Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go(AppRoutes.more),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.black),
          ),
          const Spacer(),
          const Text('Dashboard',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
          const Spacer(),
          const SizedBox(width: 18),
        ],
      ),
    );

    if (isOwner) {
      // ── Owner dashboard ──────────────────────────────────────────────────
      final dashboardAsync = ref.watch(dashboardProvider);
      return Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Column(
            children: [
              header,
              Expanded(
                child: PullToRefresh(
                  onRefresh: () {
                    ref.invalidate(expiringBatchesProvider);
                    return ref.refresh(dashboardProvider.future);
                  },
                  child: dashboardAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Failed to load dashboard.\n$e',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 14, color: AppColors.textSecondary)),
                  ),
                  data: (summary) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                    children: [
                      _GreetingRow(
                          greeting: greeting,
                          firstName: firstName,
                          dateLabel: dateLabel),
                      const SizedBox(height: 20),
                      _HeroCard(
                        label: "Today's Sales",
                        amount: summary.todaySales,
                        chips: [
                          '${summary.todayTransactionCount} transactions',
                          '${summary.customersServedToday} customers',
                          'Rs ${_formatAmount(summary.todayTips)} tips',
                        ],
                      ),
                      const SizedBox(height: 28),
                      const Text('Top Staff',
                          style: TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 12),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.divider),
                        ),
                        child: summary.topStaff.isEmpty
                            ? const Padding(
                                padding: EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 20),
                                child: Text('No completed transactions today',
                                    style: TextStyle(
                                        fontSize: 13,
                                        color: AppColors.textSecondary)),
                              )
                            : Column(
                                children: [
                                  for (int i = 0;
                                      i < summary.topStaff.length && i < 4;
                                      i++) ...[
                                    if (i > 0)
                                      const Divider(
                                          height: 1,
                                          thickness: 1,
                                          color: AppColors.surfaceVariant,
                                          indent: 56),
                                    _StaffRow(
                                        entry: summary.topStaff[i],
                                        rank: i + 1),
                                  ],
                                ],
                              ),
                      ),
                      const SizedBox(height: 28),
                      const _ExpiryAlert(),
                      if (summary.lowStockAlerts.isNotEmpty) ...[
                        const Text('Low Stock Alerts',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _LowStockCard(
                            alerts: summary.lowStockAlerts,
                            onViewAll: () =>
                                context.go(AppRoutes.moreItems)),
                        const SizedBox(height: 28),
                      ],
                      _CashDrawerCard(
                        open: summary.cashDrawerOpen,
                        balance: summary.cashDrawerBalance,
                        onManage: () => context.go(AppRoutes.moreDrawers),
                      ),
                      const SizedBox(height: 32),
                      _StartSaleButton(
                          onTap: () => context.go(AppRoutes.checkout)),
                    ],
                  ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // ── Staff dashboard ────────────────────────────────────────────────────
    final statsAsync = ref.watch(_staffTodayStatsProvider);
    final drawerAsync = ref.watch(dashboardProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            header,
            Expanded(
              child: PullToRefresh(
                onRefresh: () => Future.wait([
                  ref.refresh(_staffTodayStatsProvider.future),
                  ref.refresh(dashboardProvider.future),
                ]),
                child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                children: [
                  _GreetingRow(
                      greeting: greeting,
                      firstName: firstName,
                      dateLabel: dateLabel),
                  const SizedBox(height: 20),

                  // My today's stats
                  statsAsync.when(
                    loading: () => Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Center(
                        child: CircularProgressIndicator(color: Colors.white38),
                      ),
                    ),
                    error: (e, st) => _HeroCard(
                      label: "My Sales Today",
                      amount: 0,
                      chips: const ['— transactions'],
                    ),
                    data: (stats) => _HeroCard(
                      label: "My Sales Today",
                      amount: stats.revenue,
                      chips: ['${stats.count} transactions'],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Cash drawer (reuse from dashboard data, ignore errors)
                  drawerAsync.maybeWhen(
                    data: (summary) => Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Cash Drawer',
                            style: TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 12),
                        _CashDrawerCard(
                          open: summary.cashDrawerOpen,
                          balance: summary.cashDrawerBalance,
                          onManage: () => context.go(AppRoutes.moreDrawers),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                    orElse: () => const SizedBox.shrink(),
                  ),

                  _StartSaleButton(onTap: () => context.go(AppRoutes.checkout)),
                ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatAmount(double amount) {
  if (amount >= 1000) {
    final thousands = amount / 1000;
    if (thousands == thousands.truncateToDouble()) {
      return '${thousands.truncate()}k';
    }
    return '${thousands.toStringAsFixed(1)}k';
  }
  return amount.toStringAsFixed(0);
}

// ─── Shared sub-widgets ───────────────────────────────────────────────────────

class _GreetingRow extends StatelessWidget {
  const _GreetingRow({
    required this.greeting,
    required this.firstName,
    required this.dateLabel,
  });
  final String greeting, firstName, dateLabel;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text('$greeting, $firstName!',
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: AppColors.primaryLight,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text('Today · $dateLabel',
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primaryDark)),
          ),
        ],
      );
}

class _HeroCard extends StatelessWidget {
  const _HeroCard(
      {required this.label, required this.amount, required this.chips});
  final String label;
  final double amount;
  final List<String> chips;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    color: AppColors.textTertiary, fontSize: 13)),
            const SizedBox(height: 8),
            Text('Rs ${_formatAmount(amount)}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 34,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                )),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: chips.map((c) => _HeroChip(label: c)).toList(),
            ),
          ],
        ),
      );
}

class _CashDrawerCard extends StatelessWidget {
  const _CashDrawerCard({
    required this.open,
    required this.balance,
    required this.onManage,
  });
  final bool open;
  final double? balance;
  final VoidCallback onManage;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: open
                    ? const Color(0xFFDCFCE7)
                    : AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.point_of_sale_outlined,
                  size: 20,
                  color: open
                      ? const Color(0xFF16A34A)
                      : AppColors.textSecondary),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(open ? 'Open' : 'Closed',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: open
                              ? const Color(0xFF16A34A)
                              : Colors.black)),
                  if (open && balance != null)
                    Text('Balance: Rs ${_formatAmount(balance!)}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary))
                  else
                    const Text('No drawer session active',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                ],
              ),
            ),
            GestureDetector(
              onTap: onManage,
              child: const Text('Manage',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primary)),
            ),
          ],
        ),
      );
}

/// Owner dashboard banner for expired / soon-expiring batches. Hidden when
/// there are none, for salons, and if the lookup fails (it's a nudge, not
/// the source of truth — that's the Expiring Stock screen).
class _ExpiryAlert extends ConsumerWidget {
  const _ExpiryAlert();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(businessTypeProvider).hasExpiryTracking) {
      return const SizedBox.shrink();
    }
    final batches = ref.watch(expiringBatchesProvider).value ?? const [];
    final expired = batches.where((b) => b.isExpired).length;
    final soon = batches
        .where((b) => !b.isExpired && (b.daysToExpiry ?? 999) <= 30)
        .length;
    if (expired == 0 && soon == 0) return const SizedBox.shrink();

    final parts = [
      if (expired > 0) '$expired batch${expired == 1 ? '' : 'es'} expired',
      if (soon > 0) '$soon expiring within 30 days',
    ];
    final urgent = expired > 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: GestureDetector(
        onTap: () => context.go(AppRoutes.moreExpiringStock),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: urgent ? const Color(0xFFFEE2E2) : const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(Icons.event_busy_outlined,
                  size: 18,
                  color: urgent
                      ? const Color(0xFFB91C1C)
                      : const Color(0xFFD97706)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(parts.join(' · '),
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: urgent
                            ? const Color(0xFF991B1B)
                            : const Color(0xFF92400E))),
              ),
              Icon(Icons.chevron_right_rounded,
                  size: 18,
                  color: urgent
                      ? const Color(0xFFB91C1C)
                      : const Color(0xFFD97706)),
            ],
          ),
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.alerts, required this.onViewAll});
  final List<LowStockProduct> alerts;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: const BoxDecoration(
                color: Color(0xFFFEF3C7),
                borderRadius:
                    BorderRadius.vertical(top: Radius.circular(14)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      size: 16, color: Color(0xFFD97706)),
                  const SizedBox(width: 8),
                  Text(
                      '${alerts.length} item${alerts.length == 1 ? '' : 's'} running low',
                      style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF92400E))),
                  const Spacer(),
                  GestureDetector(
                    onTap: onViewAll,
                    child: const Text('View all',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFFD97706))),
                  ),
                ],
              ),
            ),
            for (int i = 0; i < alerts.length; i++) ...[
              if (i > 0)
                const Divider(
                    height: 1,
                    thickness: 1,
                    color: AppColors.surfaceVariant,
                    indent: 16),
              _LowStockRow(product: alerts[i]),
            ],
          ],
        ),
      );
}

class _StartSaleButton extends StatelessWidget {
  const _StartSaleButton({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: Colors.black,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('Start New Sale',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      );
}

// ── Hero chip ──────────────────────────────────────────────────────────────────

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.textPrimary,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppColors.border,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// ── Staff row ─────────────────────────────────────────────────────────────────

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.entry, required this.rank});
  final TopStaffEntry entry;
  final int rank;

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      const Color(0xFFFFD700), // gold
      const Color(0xFFB0B0B0), // silver
      const Color(0xFFCD7F32), // bronze
    ];
    final rankEmojis = ['🥇', '🥈', '🥉'];

    final isTop3 = rank <= 3;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          // Rank badge
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: isTop3
                  ? rankColors[rank - 1].withValues(alpha: 0.15)
                  : AppColors.surfaceVariant,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: isTop3
                ? Text(
                    rankEmojis[rank - 1],
                    style: const TextStyle(fontSize: 14),
                  )
                : Text(
                    '$rank',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(width: 10),
          // Avatar
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.surfaceVariant,
            child: Text(
              _staffInitials(entry.staffName),
              style: const TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Name + service count
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.staffName,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Rs ${_formatAmount(entry.totalSales)} sales',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      final thousands = amount / 1000;
      if (thousands == thousands.truncateToDouble()) {
        return '${thousands.truncate()}k';
      }
      return '${thousands.toStringAsFixed(1)}k';
    }
    return amount.toStringAsFixed(0);
  }
}

// ── Low stock row ─────────────────────────────────────────────────────────────

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.product});
  final LowStockProduct product;

  @override
  Widget build(BuildContext context) {
    final isCritical = product.stock <= 2;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              product.name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: isCritical
                  ? AppColors.dangerLight
                  : const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${product.stock} left',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isCritical
                    ? AppColors.danger
                    : const Color(0xFFD97706),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
