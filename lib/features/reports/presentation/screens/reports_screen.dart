import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import '../../../../core/theme/app_theme.dart';

class ReportsScreen extends HookWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tabCtrl = useTabController(initialLength: 4);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            color: Colors.white,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg, AppSpacing.md, AppSpacing.lg, 0),
                  child: Text('Reports & Analytics',
                      style: AppTextStyles.headlineMedium),
                ),
                TabBar(
                  controller: tabCtrl,
                  isScrollable: true,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textSecondary,
                  indicatorColor: AppColors.primary,
                  tabs: const [
                    Tab(text: 'Daily Sales'),
                    Tab(text: 'Staff Performance'),
                    Tab(text: 'Service Popularity'),
                    Tab(text: 'Inventory'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: tabCtrl,
              children: const [
                _DailySalesTab(),
                _StaffPerformanceTab(),
                _ServicePopularityTab(),
                _InventoryReportTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DailySalesTab extends StatelessWidget {
  const _DailySalesTab();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Row(
            children: [
              _KpiCard(label: 'Total Revenue', value: 'NPR 34,800'),
              const SizedBox(width: AppSpacing.md),
              _KpiCard(label: 'Transactions', value: '18'),
              const SizedBox(width: AppSpacing.md),
              _KpiCard(label: 'Avg. Ticket', value: 'NPR 1,933'),
              const SizedBox(width: AppSpacing.md),
              _KpiCard(label: 'Tips Collected', value: 'NPR 1,800'),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          _PlaceholderChart(title: 'Hourly Revenue'),
        ],
      ),
    );
  }
}

class _StaffPerformanceTab extends StatelessWidget {
  const _StaffPerformanceTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _PlaceholderChart(title: 'Staff Revenue Breakdown'),
    );
  }
}

class _ServicePopularityTab extends StatelessWidget {
  const _ServicePopularityTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _PlaceholderChart(title: 'Top Services by Revenue'),
    );
  }
}

class _InventoryReportTab extends StatelessWidget {
  const _InventoryReportTab();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: _PlaceholderChart(title: 'Stock Levels'),
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.lgBR,
            border: Border.all(color: AppColors.divider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.labelMedium),
            const SizedBox(height: 6),
            Text(value, style: AppTextStyles.kpiValue.copyWith(fontSize: 22)),
          ],
        ),
      ),
    );
  }
}

class _PlaceholderChart extends StatelessWidget {
  const _PlaceholderChart({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 320,
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgBR,
          border: Border.all(color: AppColors.divider)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.bar_chart_rounded,
                size: 64, color: AppColors.textTertiary),
            const SizedBox(height: AppSpacing.md),
            Text(title, style: AppTextStyles.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text('Chart coming soon',
                style: AppTextStyles.bodyMedium),
          ],
        ),
      ),
    );
  }
}
