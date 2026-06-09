import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../providers/customers_provider.dart';

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customers = ref.watch(customersProvider);

    return customers.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(body: ErrorState(message: e.toString())),
      data: (list) {
        final customer =
            list.where((c) => c.id == customerId).firstOrNull;
        if (customer == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Customer')),
            body: const EmptyState(
                icon: Icons.person_off_outlined,
                title: 'Customer not found'),
          );
        }
        return Scaffold(
          backgroundColor: AppColors.background,
          body: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(customer.initials,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w800,
                              fontSize: 24)),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(customer.fullName,
                              style: AppTextStyles.headlineMedium),
                          if (customer.phone != null)
                            Text(customer.phone!,
                                style: AppTextStyles.bodyMedium),
                          if (customer.email != null)
                            Text(customer.email!,
                                style: AppTextStyles.bodyMedium),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      onPressed: () =>
                          context.go(AppRoutes.customerEdit(customerId)),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: _StatCard(
                            label: 'Total Visits',
                            value: '${customer.visitCount}',
                            icon: Icons.calendar_today_outlined),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatCard(
                            label: 'Total Spent',
                            value:
                                'NPR ${customer.totalSpent.toStringAsFixed(0)}',
                            icon: Icons.attach_money_rounded),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: _StatCard(
                            label: 'Last Visit',
                            value: customer.lastVisitLabel,
                            icon: Icons.access_time_rounded),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon});
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgBR,
          border: Border.all(color: AppColors.divider)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(height: AppSpacing.sm),
          Text(value, style: AppTextStyles.titleLarge),
          Text(label, style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
