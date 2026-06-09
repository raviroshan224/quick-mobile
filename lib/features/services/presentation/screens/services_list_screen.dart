import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/service_models.dart';
import '../providers/services_provider.dart';

class ServicesListScreen extends ConsumerWidget {
  const ServicesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            height: 60,
            padding:
                const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            color: Colors.white,
            child: Row(
              children: [
                Text('Services', style: AppTextStyles.headlineMedium),
              ],
            ),
          ),
          Expanded(
            child: servicesAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: e.toString()),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.content_cut_rounded,
                      title: 'No services',
                      subtitle: 'Add your first service to get started',
                    )
                  : _ServicesList(services: list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.serviceNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Service'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _ServicesList extends StatelessWidget {
  const _ServicesList({required this.services});
  final List<ServiceModel> services;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: services.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ServiceTile(service: services[i]),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgBR,
          border: Border.all(color: AppColors.divider)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: AppRadius.mdBR),
            child: const Icon(Icons.content_cut_rounded,
                size: 20, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service.name, style: AppTextStyles.titleMedium),
                Text(service.durationLabel,
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Text(service.priceLabel, style: AppTextStyles.priceTag),
          const SizedBox(width: AppSpacing.md),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 18),
            onPressed: () =>
                context.go(AppRoutes.serviceEdit(service.id)),
            color: AppColors.textSecondary,
          ),
        ],
      ),
    );
  }
}
