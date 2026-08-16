import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/reports/domain/reports_models.dart';
import '../../../../features/reports/presentation/providers/reports_provider.dart';
import 'settings_screen.dart' show salonSettingsProvider;
import '../../../../shared/widgets/pull_to_refresh.dart';

// ─── Formatting ───────────────────────────────────────────────────────────────

String _npr(double v) {
  if (v == 0) return 'Rs 0';
  final whole = v.abs().toInt();
  final str = whole.toString();
  final buf = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buf.write(',');
    buf.write(str[i]);
    count++;
  }
  return 'Rs ${v < 0 ? '-' : ''}${buf.toString().split('').reversed.join()}';
}

String _pct(double part, double total) {
  if (total == 0) return '0%';
  return '${(part / total * 100).toStringAsFixed(1)}%';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportsScreen extends HookConsumerWidget {
  const ReportsScreen({super.key});

  static const _tabs = ['Sales', 'Staff', 'Services', 'Inventory'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isOwnerProvider);

    // Redirect staff away — runs after build
    useEffect(() {
      if (!isOwner) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          context.go(AppRoutes.dashboard);
        });
      }
      return null;
    }, [isOwner]);

    if (!isOwner) return const SizedBox.shrink();

    final commissionEnabled =
        ref.watch(salonSettingsProvider).commissionEnabled;
    final state = ref.watch(reportsProvider);
    final notifier = ref.read(reportsProvider.notifier);
    final tabIndex = useState(state.activeTab.index);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.more),
                    child: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.black),
                  ),
                  const Spacer(),
                  const Text('Reports',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  const SizedBox(width: 18),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Date range chips ──────────────────────────────────────────
            SizedBox(
              height: 36,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _PeriodChip(
                    label: 'Today',
                    selected: state.period == ReportsPeriod.today,
                    onTap: () => notifier.setPeriod(ReportsPeriod.today),
                  ),
                  const SizedBox(width: 6),
                  _PeriodChip(
                    label: 'This Week',
                    selected: state.period == ReportsPeriod.thisWeek,
                    onTap: () => notifier.setPeriod(ReportsPeriod.thisWeek),
                  ),
                  const SizedBox(width: 6),
                  _PeriodChip(
                    label: 'This Month',
                    selected: state.period == ReportsPeriod.thisMonth,
                    onTap: () => notifier.setPeriod(ReportsPeriod.thisMonth),
                  ),
                  const SizedBox(width: 6),
                  _PeriodChip(
                    label: state.period == ReportsPeriod.custom
                        ? _formatCustomRange(state.dateRange)
                        : 'Custom',
                    selected: state.period == ReportsPeriod.custom,
                    onTap: () => _pickCustomRange(context, ref, state),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 10),

            // ── Tab chips ─────────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _TopTab(
                  label: _tabs[i],
                  selected: tabIndex.value == i,
                  onTap: () {
                    tabIndex.value = i;
                    notifier.setTab(ReportsTab.values[i]);
                  },
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: PullToRefresh(
                onRefresh: notifier.refresh,
                child: _TabBody(
                  tabIndex: tabIndex.value,
                  state: state,
                  onRetry: notifier.retry,
                  commissionEnabled: commissionEnabled,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatCustomRange(DateTimeRange r) {
    String fmt(DateTime d) => '${d.month}/${d.day}';
    return '${fmt(r.start)}–${fmt(r.end)}';
  }

  Future<void> _pickCustomRange(
      BuildContext context, WidgetRef ref, ReportsState state) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      initialDateRange: state.dateRange,
      builder: (ctx, child) => Theme(
        data: ThemeData.light().copyWith(
          colorScheme: const ColorScheme.light(primary: Colors.black),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      ref.read(reportsProvider.notifier).setPeriod(
            ReportsPeriod.custom,
            custom: picked,
          );
    }
  }
}

// ─── Tab body dispatcher ──────────────────────────────────────────────────────

class _TabBody extends StatelessWidget {
  const _TabBody({
    required this.tabIndex,
    required this.state,
    required this.onRetry,
    required this.commissionEnabled,
  });

  final int tabIndex;
  final ReportsState state;
  final VoidCallback onRetry;
  final bool commissionEnabled;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.black));
    }
    if (state.error != null) {
      return _ErrorView(message: state.error!, onRetry: onRetry);
    }
    return switch (tabIndex) {
      0 => _SalesTab(summary: state.salesSummary),
      1 => _StaffTab(
          rows: state.staffPerformance, commissionEnabled: commissionEnabled),
      2 => _ServicesTab(rows: state.servicePopularity),
      _ => _InventoryTab(report: state.inventoryReport),
    };
  }
}

// ─── Error / empty ────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 40, color: AppColors.danger),
              const SizedBox(height: 12),
              const Text('Failed to load report',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              const SizedBox(height: 6),
              Text(message,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: onRetry,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
}

class _EmptyView extends StatelessWidget {
  const _EmptyView({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.bar_chart_rounded,
                  size: 28, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
          ],
        ),
      );
}

// ─── Shared widgets ───────────────────────────────────────────────────────────

class _PeriodChip extends StatelessWidget {
  const _PeriodChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
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
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: selected ? Colors.white : AppColors.textSecondary,
            ),
          ),
        ),
      );
}

class _TopTab extends StatelessWidget {
  const _TopTab(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
          decoration: BoxDecoration(
            color: selected ? Colors.black : Colors.white,
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: selected ? Colors.black : AppColors.divider),
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

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      );
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color, this.height = 8});
  final double fraction;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (_, constraints) => Stack(
          children: [
            Container(
              height: height,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            Container(
              height: height,
              width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SALES TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _SalesTab extends StatelessWidget {
  const _SalesTab({required this.summary});
  final SalesSummary? summary;

  @override
  Widget build(BuildContext context) {
    if (summary == null) {
      return const _EmptyView(label: 'No sales data for this period');
    }
    final s = summary!;
    final total = s.totalRevenue;
    final cash = s.byPaymentMethod['CASH'] ?? 0.0;
    final fonepay = s.byPaymentMethod['FONEPAY'] ?? 0.0;
    final split = s.byPaymentMethod['SPLIT'] ?? 0.0;

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // ── Revenue hero ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Revenue',
                  style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
              const SizedBox(height: 6),
              Text(_npr(total),
                  style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      color: Colors.white)),
              const SizedBox(height: 16),
              Row(children: [
                Expanded(
                  child: _SummaryMetric(
                      label: 'Transactions',
                      value: '${s.transactionCount}'),
                ),
                Container(
                    width: 1, height: 32, color: AppColors.textSecondary),
                Expanded(
                  child: _SummaryMetric(
                      label: 'Avg Ticket', value: _npr(s.avgTicket)),
                ),
                Container(
                    width: 1, height: 32, color: AppColors.textSecondary),
                Expanded(
                  child: _SummaryMetric(
                      label: 'Refunds', value: _npr(s.refundTotal)),
                ),
                Container(
                    width: 1, height: 32, color: AppColors.textSecondary),
                Expanded(
                  child: _SummaryMetric(
                      label: 'Discounts', value: _npr(s.totalDiscounts)),
                ),
              ]),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Salon checkout: Service Value / Manual Adjustments / Final
        // Collected — kept as its own section, separate from "Discounts"
        // in the hero card above. A manual adjustment (the cashier-entered
        // Final Payable Amount) is a different mechanism from a catalog
        // discount and is never mixed into that figure.
        if (s.serviceValue != 0 || s.manualAdjustments != 0) ...[
          const _SectionLabel('Salon Checkout'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LightMetric(
                    label: 'Service Value',
                    value: _npr(s.serviceValue),
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.divider),
                Expanded(
                  child: _LightMetric(
                    label: 'Manual Adjustments',
                    value: '${s.manualAdjustments > 0 ? '+' : '-'}'
                        '${_npr(s.manualAdjustments.abs())}',
                  ),
                ),
                Container(width: 1, height: 32, color: AppColors.divider),
                Expanded(
                  child: _LightMetric(
                    label: 'Final Collected',
                    value: _npr(s.finalCollectedAmount),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── Payment method breakdown ──────────────────────────────────────
        const _SectionLabel('Payment Methods'),
        Row(children: [
          Expanded(
              child: _MethodCard(
                  label: 'Cash',
                  amount: cash,
                  pct: _pct(cash, total),
                  color: AppColors.success)),
          const SizedBox(width: 10),
          Expanded(
              child: _MethodCard(
                  label: 'Fonepay',
                  amount: fonepay,
                  pct: _pct(fonepay, total),
                  color: AppColors.primaryDark)),
          const SizedBox(width: 10),
          Expanded(
              child: _MethodCard(
                  label: 'Split',
                  amount: split,
                  pct: _pct(split, total),
                  color: const Color(0xFFF59E0B))),
        ]),

        const SizedBox(height: 20),

        // ── Bar chart ─────────────────────────────────────────────────────
        const _SectionLabel('Revenue by Method'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              _MethodBar(
                  label: 'Cash', value: cash, total: total,
                  color: AppColors.success),
              const SizedBox(height: 14),
              _MethodBar(
                  label: 'Fonepay', value: fonepay, total: total,
                  color: AppColors.primaryDark),
              const SizedBox(height: 14),
              _MethodBar(
                  label: 'Split', value: split, total: total,
                  color: const Color(0xFFF59E0B)),
            ],
          ),
        ),
      ],
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
      );
}

// Same layout as _SummaryMetric, but dark text for a light card background
// (the hero card above is black; the "Salon Checkout" card is not).
class _LightMetric extends StatelessWidget {
  const _LightMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
        ],
      );
}

class _MethodCard extends StatelessWidget {
  const _MethodCard(
      {required this.label,
      required this.amount,
      required this.pct,
      required this.color});
  final String label;
  final double amount;
  final String pct;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration:
                  BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(height: 8),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary)),
            const SizedBox(height: 2),
            Text(pct,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700)),
            Text(_npr(amount),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
          ],
        ),
      );
}

class _MethodBar extends StatelessWidget {
  const _MethodBar(
      {required this.label,
      required this.value,
      required this.total,
      required this.color});
  final String label;
  final double value;
  final double total;
  final Color color;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w500)),
          ),
          Expanded(
              child: _Bar(
                  fraction: total == 0 ? 0 : value / total, color: color)),
          const SizedBox(width: 10),
          SizedBox(
            width: 48,
            child: Text(_pct(value, total),
                textAlign: TextAlign.right,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
        ],
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAFF TAB
// ═══════════════════════════════════════════════════════════════════════════════

enum _StaffSort { revenue, services, hours, commission }

class _StaffTab extends HookWidget {
  const _StaffTab({required this.rows, required this.commissionEnabled});
  final List<StaffPerformance>? rows;
  final bool commissionEnabled;

  @override
  Widget build(BuildContext context) {
    final sortBy = useState(_StaffSort.revenue);
    final sortAsc = useState(false);

    if (rows == null || rows!.isEmpty) {
      return const _EmptyView(label: 'No staff data for this period');
    }

    final sorted = [...rows!]..sort((a, b) {
        final cmp = switch (sortBy.value) {
          _StaffSort.revenue => a.totalRevenue.compareTo(b.totalRevenue),
          _StaffSort.services => a.serviceCount.compareTo(b.serviceCount),
          _StaffSort.hours => a.totalHours.compareTo(b.totalHours),
          _StaffSort.commission => a.commission.compareTo(b.commission),
        };
        return sortAsc.value ? cmp : -cmp;
      });

    void tap(_StaffSort col) {
      if (sortBy.value == col) {
        sortAsc.value = !sortAsc.value;
      } else {
        sortBy.value = col;
        sortAsc.value = false;
      }
    }

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              // Header row
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                child: Row(
                  children: [
                    const SizedBox(width: 24, child: Text('#', style: _hdr)),
                    const SizedBox(width: 8),
                    const Expanded(
                        child: Text('Name', style: _hdr)),
                    _SortHeader(
                      label: 'Svcs',
                      active: sortBy.value == _StaffSort.services,
                      asc: sortAsc.value,
                      onTap: () => tap(_StaffSort.services),
                      width: 36,
                    ),
                    const SizedBox(width: 6),
                    _SortHeader(
                      label: 'Revenue',
                      active: sortBy.value == _StaffSort.revenue,
                      asc: sortAsc.value,
                      onTap: () => tap(_StaffSort.revenue),
                      width: 72,
                    ),
                    if (commissionEnabled) ...[
                      const SizedBox(width: 6),
                      _SortHeader(
                        label: 'Comm.',
                        active: sortBy.value == _StaffSort.commission,
                        asc: sortAsc.value,
                        onTap: () => tap(_StaffSort.commission),
                        width: 60,
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.divider),
              ...sorted.asMap().entries.map((entry) => _StaffRow(
                  rank: entry.key + 1,
                  data: entry.value,
                  showCommission: commissionEnabled)),
            ],
          ),
        ),
      ],
    );
  }

  static const _hdr = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.5,
  );
}

class _SortHeader extends StatelessWidget {
  const _SortHeader({
    required this.label,
    required this.active,
    required this.asc,
    required this.onTap,
    required this.width,
  });
  final String label;
  final bool active;
  final bool asc;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(label,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: active ? Colors.black : AppColors.textSecondary,
                    letterSpacing: 0.5,
                  )),
              if (active) ...[
                const SizedBox(width: 2),
                Icon(
                  asc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  size: 10,
                  color: Colors.black,
                ),
              ],
            ],
          ),
        ),
      );
}

class _StaffRow extends StatelessWidget {
  const _StaffRow({
    required this.rank,
    required this.data,
    this.showCommission = true,
  });
  final int rank;
  final StaffPerformance data;
  final bool showCommission;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            SizedBox(
              width: 24,
              child: Text('$rank',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textTertiary)),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: AppColors.surfaceVariant,
                    child: Text(
                      data.staffName.isNotEmpty ? data.staffName[0] : '?',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.black),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(data.staffName,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w500)),
                  ),
                ],
              ),
            ),
            SizedBox(
              width: 36,
              child: Text('${data.serviceCount}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 6),
            SizedBox(
              width: 72,
              child: Text(_npr(data.totalRevenue),
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
            ),
            if (showCommission) ...[
              const SizedBox(width: 6),
              SizedBox(
                width: 60,
                child: Text(_npr(data.commission),
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.success)),
              ),
            ],
          ],
        ),
      );
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICES TAB
// ═══════════════════════════════════════════════════════════════════════════════

enum _ServiceSort { revenue, bookings }

class _ServicesTab extends HookWidget {
  const _ServicesTab({required this.rows});
  final List<ServicePopularity>? rows;

  @override
  Widget build(BuildContext context) {
    final sortBy = useState(_ServiceSort.revenue);
    final sortAsc = useState(false);

    if (rows == null || rows!.isEmpty) {
      return const _EmptyView(label: 'No service data for this period');
    }

    final sorted = [...rows!]..sort((a, b) {
        final cmp = sortBy.value == _ServiceSort.revenue
            ? a.revenue.compareTo(b.revenue)
            : a.bookingCount.compareTo(b.bookingCount);
        return sortAsc.value ? cmp : -cmp;
      });

    final maxRevenue =
        sorted.map((s) => s.revenue).fold(0.0, (m, v) => v > m ? v : m);
    final maxBookings =
        sorted.map((s) => s.bookingCount).fold(0, (m, v) => v > m ? v : m);

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // Sort toggle
        Row(
          children: [
            const Text('Sort by:',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            const SizedBox(width: 8),
            _SortChip(
              label: 'Revenue',
              selected: sortBy.value == _ServiceSort.revenue,
              onTap: () {
                if (sortBy.value == _ServiceSort.revenue) {
                  sortAsc.value = !sortAsc.value;
                } else {
                  sortBy.value = _ServiceSort.revenue;
                  sortAsc.value = false;
                }
              },
            ),
            const SizedBox(width: 6),
            _SortChip(
              label: 'Bookings',
              selected: sortBy.value == _ServiceSort.bookings,
              onTap: () {
                if (sortBy.value == _ServiceSort.bookings) {
                  sortAsc.value = !sortAsc.value;
                } else {
                  sortBy.value = _ServiceSort.bookings;
                  sortAsc.value = false;
                }
              },
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            children: [
              for (final (i, svc) in sorted.indexed) ...[
                if (i > 0)
                  const Divider(height: 1, indent: 16, endIndent: 16,
                      color: AppColors.surfaceVariant),
                _ServiceRow(
                  rank: i + 1,
                  svc: svc,
                  maxRevenue: maxRevenue,
                  maxBookings: maxBookings,
                  sortBy: sortBy.value,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SortChip extends StatelessWidget {
  const _SortChip(
      {required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
          decoration: BoxDecoration(
            color: selected ? Colors.black : AppColors.surfaceVariant,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary,
              )),
        ),
      );
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.rank,
    required this.svc,
    required this.maxRevenue,
    required this.maxBookings,
    required this.sortBy,
  });
  final int rank;
  final ServicePopularity svc;
  final double maxRevenue;
  final int maxBookings;
  final _ServiceSort sortBy;

  @override
  Widget build(BuildContext context) {
    final fraction = sortBy == _ServiceSort.revenue
        ? (maxRevenue == 0 ? 0.0 : svc.revenue / maxRevenue)
        : (maxBookings == 0 ? 0.0 : svc.bookingCount / maxBookings);

    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: rank == 1 ? Colors.black : AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text('$rank',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: rank == 1 ? Colors.white : AppColors.textSecondary,
                  )),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(svc.serviceName,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 4),
                _Bar(fraction: fraction, color: AppColors.primary,
                    height: 5),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${svc.bookingCount} bookings',
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600)),
              Text(_npr(svc.revenue),
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
            ],
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVENTORY TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _InventoryTab extends StatelessWidget {
  const _InventoryTab({required this.report});
  final InventoryReport? report;

  @override
  Widget build(BuildContext context) {
    if (report == null) {
      return const _EmptyView(label: 'No inventory data');
    }
    final r = report!;
    final critical = r.products.where((p) => p.status == 'critical').toList();
    final low = r.products.where((p) => p.status == 'low').toList();

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // ── Critical alert ────────────────────────────────────────────────
        if (critical.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppColors.danger.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.warning_amber_rounded,
                    size: 18, color: AppColors.danger),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '${critical.length} item${critical.length == 1 ? '' : 's'} critically low or out of stock',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Low stock items ───────────────────────────────────────────────
        if (critical.isNotEmpty || low.isNotEmpty) ...[
          const _SectionLabel('Low Stock'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                for (final (i, p) in [...critical, ...low].indexed) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16,
                        color: AppColors.surfaceVariant),
                  _ProductRow(product: p),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
        ],

        // ── All products table ────────────────────────────────────────────
        const _SectionLabel('All Products'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: r.products.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text('No products',
                        style: TextStyle(
                            color: AppColors.textTertiary, fontSize: 14)),
                  ),
                )
              : Column(
                  children: [
                    for (final (i, p) in r.products.indexed) ...[
                      if (i > 0)
                        const Divider(height: 1, indent: 16, endIndent: 16,
                            color: AppColors.surfaceVariant),
                      _ProductRow(product: p),
                    ],
                  ],
                ),
        ),

        // ── Recent movements ──────────────────────────────────────────────
        if (r.recentMovements.isNotEmpty) ...[
          const SizedBox(height: 20),
          const _SectionLabel('Recent Movements'),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.divider),
            ),
            child: Column(
              children: [
                for (final (i, mv) in r.recentMovements.indexed) ...[
                  if (i > 0)
                    const Divider(height: 1, indent: 16, endIndent: 16,
                        color: AppColors.surfaceVariant),
                  _MovementRow(movement: mv),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product});
  final InventoryProduct product;

  @override
  Widget build(BuildContext context) {
    final (statusColor, statusBg, statusLabel) = switch (product.status) {
      'critical' => (
          AppColors.danger,
          const Color(0xFFFEF2F2),
          product.stock <= 0 ? 'Out' : 'Critical'
        ),
      'low' => (
          const Color(0xFFF59E0B),
          const Color(0xFFFFFBEB),
          'Low'
        ),
      _ => (
          AppColors.success,
          const Color(0xFFDCFCE7),
          'OK'
        ),
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text('${product.stock} / ${product.lowStockThreshold} threshold',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(statusLabel,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: statusColor)),
          ),
        ],
      ),
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement});
  final InventoryMovement movement;

  @override
  Widget build(BuildContext context) {
    final isIn = movement.type == 'in';
    final color = isIn ? AppColors.success : AppColors.danger;
    final bg = isIn ? const Color(0xFFDCFCE7) : const Color(0xFFFEE2E2);

    // Parse date for display
    String dateLabel = '';
    try {
      final dt = DateTime.parse(movement.date).toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final d = DateTime(dt.year, dt.month, dt.day);
      if (d == today) {
        dateLabel = 'Today';
      } else if (d == yesterday) {
        dateLabel = 'Yesterday';
      } else {
        dateLabel = '${dt.month}/${dt.day}';
      }
    } catch (_) {
      dateLabel = movement.date;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(
              isIn
                  ? Icons.arrow_downward_rounded
                  : Icons.arrow_upward_rounded,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(movement.item,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w500)),
                Text(movement.note,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${isIn ? '+' : '-'}${movement.qty}',
                  style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: color)),
              Text(dateLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary)),
            ],
          ),
        ],
      ),
    );
  }
}
