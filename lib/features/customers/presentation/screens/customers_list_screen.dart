import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../domain/customer_models.dart';
import '../providers/customers_provider.dart';

class CustomersListScreen extends HookConsumerWidget {
  const CustomersListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCtrl = useTextEditingController();
    final customers = ref.watch(customersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          _TopBar(searchCtrl: searchCtrl),
          Expanded(
            child: customers.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: e.toString()),
              data: (list) {
                final q = searchCtrl.value.text.toLowerCase();
                final filtered = q.isEmpty
                    ? list
                    : list
                        .where((c) =>
                            c.fullName.toLowerCase().contains(q) ||
                            (c.phone?.contains(q) ?? false) ||
                            (c.email?.toLowerCase().contains(q) ?? false))
                        .toList();
                return filtered.isEmpty
                    ? const EmptyState(
                        icon: Icons.people_alt_outlined,
                        title: 'No customers found',
                        subtitle: 'Add your first customer to get started',
                      )
                    : _CustomerGrid(customers: filtered);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.customerNew),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Customer'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _TopBar extends HookWidget {
  const _TopBar({required this.searchCtrl});
  final TextEditingController searchCtrl;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
          color: Colors.white,
          border: Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          Text('Customers', style: AppTextStyles.headlineMedium),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: AppSearchField(
              controller: searchCtrl,
              hint: 'Search by name, phone or email...',
              onClear: () {},
            ),
          ),
        ],
      ),
    );
  }
}

class _CustomerGrid extends StatelessWidget {
  const _CustomerGrid({required this.customers});
  final List<CustomerModel> customers;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 140,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: customers.length,
      itemBuilder: (_, i) => _CustomerCard(customer: customers[i]),
    );
  }
}

class _CustomerCard extends StatelessWidget {
  const _CustomerCard({required this.customer});
  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.lgBR,
      child: InkWell(
        borderRadius: AppRadius.lgBR,
        onTap: () => context.go(AppRoutes.customerDetail(customer.id)),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: AppRadius.lgBR,
              border: Border.all(color: AppColors.divider)),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: AppColors.primaryLight,
                child: Text(customer.initials,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 16)),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(customer.fullName,
                        style: AppTextStyles.titleMedium,
                        overflow: TextOverflow.ellipsis),
                    if (customer.phone != null)
                      Text(customer.phone!,
                          style: AppTextStyles.bodySmall),
                    const SizedBox(height: 4),
                    Text('${customer.visitCount} visits',
                        style: AppTextStyles.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
