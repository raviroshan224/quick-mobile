import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/stat_card.dart';
import '../../../dashboard/data/mock_dashboard_repository.dart';
import '../providers/dashboard_provider.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(dashboardProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: asyncData.when(
        loading: () => const LoadingState(),
        error: (e, _) => ErrorState(message: e.toString()),
        data: (summary) => _DashboardContent(summary: summary),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardHeader(),
          const SizedBox(height: AppSpacing.lg),
          _KpiRow(summary: summary),
          const SizedBox(height: AppSpacing.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: _TopStaffCard(entries: summary.topStaff)),
              const SizedBox(width: AppSpacing.lg),
              Expanded(flex: 2, child: Column(
                children: [
                  _CashDrawerCard(
                    isOpen: summary.cashDrawerOpen,
                    balance: summary.cashDrawerBalance,
                  ),
                  if (summary.lowStockAlerts.isNotEmpty) ...[
                    const SizedBox(height: AppSpacing.lg),
                    _LowStockCard(products: summary.lowStockAlerts),
                  ],
                ],
              )),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Dashboard', style: AppTextStyles.displayLarge),
              const SizedBox(height: 2),
              Text("Today's overview", style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.pos),
          icon: const Icon(Icons.point_of_sale_rounded, size: 16),
          label: const Text('New Sale'),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: AppSpacing.sm),
          ),
        ),
      ],
    );
  }
}

class _KpiRow extends StatelessWidget {
  const _KpiRow({required this.summary});
  final DashboardSummary summary;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: StatCard(
            label: "Today's Sales",
            value: 'NPR ${_fmt(summary.todaySales)}',
            icon: Icons.attach_money_rounded,
            iconColor: AppColors.success,
            trend: '+12%',
            trendPositive: true,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Total Tips',
            value: 'NPR ${_fmt(summary.todayTips)}',
            icon: Icons.volunteer_activism_rounded,
            iconColor: const Color(0xFF8B5CF6),
            trend: '+5%',
            trendPositive: true,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Transactions',
            value: summary.todayTransactionCount.toString(),
            icon: Icons.receipt_long_rounded,
            iconColor: AppColors.primary,
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: StatCard(
            label: 'Customers Served',
            value: summary.customersServedToday.toString(),
            icon: Icons.people_alt_rounded,
            iconColor: const Color(0xFFF59E0B),
          ),
        ),
      ],
    );
  }

  String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _TopStaffCard extends StatelessWidget {
  const _TopStaffCard({required this.entries});
  final List<TopStaffEntry> entries;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBR,
        side: BorderSide(color: AppColors.divider),
      ),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text("Top Staff Today", style: AppTextStyles.titleLarge),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go(AppRoutes.staff),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            ...entries.asMap().entries.map((e) => _TopStaffRow(
                  rank: e.key + 1,
                  entry: e.value,
                )),
          ],
        ),
      ),
    );
  }
}

class _TopStaffRow extends StatelessWidget {
  const _TopStaffRow({required this.rank, required this.entry});
  final int rank;
  final TopStaffEntry entry;

  @override
  Widget build(BuildContext context) {
    final rankColors = [
      const Color(0xFFFFB800),
      const Color(0xFF94A3B8),
      const Color(0xFFCD7F32),
      AppColors.textSecondary,
    ];
    final color = rank <= rankColors.length ? rankColors[rank - 1] : AppColors.textSecondary;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
      child: Row(
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.primary.withValues(alpha: 0.1),
            child: Text(
              entry.staff.initials,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary),
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.staff.fullName,
                    style: AppTextStyles.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                Text('${entry.serviceCount} services',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(
            'NPR ${entry.totalSales.toStringAsFixed(0)}',
            style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ],
      ),
    );
  }
}

class _CashDrawerCard extends StatelessWidget {
  const _CashDrawerCard({required this.isOpen, required this.balance});
  final bool isOpen;
  final double? balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBR,
        side: BorderSide(color: isOpen ? AppColors.success.withValues(alpha: 0.3) : AppColors.divider),
      ),
      color: isOpen ? AppColors.success.withValues(alpha: 0.04) : Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: (isOpen ? AppColors.success : AppColors.textSecondary).withValues(alpha: 0.1),
                borderRadius: AppRadius.mdBR,
              ),
              child: Icon(
                isOpen ? Icons.lock_open_rounded : Icons.lock_rounded,
                size: 20,
                color: isOpen ? AppColors.success : AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Cash Drawer', style: AppTextStyles.labelMedium),
                  Text(
                    isOpen ? 'Open — NPR ${balance?.toStringAsFixed(0) ?? "—"}' : 'Closed',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: isOpen ? AppColors.success : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => context.go(AppRoutes.cashDrawer),
              child: Text(isOpen ? 'Manage' : 'Open'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LowStockCard extends StatelessWidget {
  const _LowStockCard({required this.products});
  final List<dynamic> products;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: AppRadius.lgBR,
        side: BorderSide(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      color: AppColors.warning.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 18, color: AppColors.warning),
                const SizedBox(width: AppSpacing.xs),
                Text('Low Stock Alerts', style: AppTextStyles.titleMedium),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go(AppRoutes.inventory),
                  child: const Text('View all'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.sm),
            ...products.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      const Icon(Icons.circle, size: 6, color: AppColors.warning),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(p.name, style: AppTextStyles.bodyMedium)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.1),
                          borderRadius: AppRadius.pillBR,
                        ),
                        child: Text(
                          '${p.stock} left',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
