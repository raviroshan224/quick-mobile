import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/inventory_models.dart';
import '../providers/inventory_provider.dart';

class InventoryListScreen extends ConsumerWidget {
  const InventoryListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);

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
                Text('Inventory', style: AppTextStyles.headlineMedium),
                const Spacer(),
                OutlinedButton.icon(
                  icon: const Icon(Icons.swap_vert_rounded, size: 16),
                  label: const Text('Stock Movement'),
                  onPressed: () =>
                      context.go(AppRoutes.inventoryMovement),
                ),
              ],
            ),
          ),
          Expanded(
            child: productsAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: e.toString()),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.inventory_2_outlined,
                      title: 'No products',
                      subtitle: 'Add your first product',
                    )
                  : _ProductList(products: list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.inventoryNew),
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add Product'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _ProductList extends StatelessWidget {
  const _ProductList({required this.products});
  final List<ProductModel> products;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(AppSpacing.lg),
      itemCount: products.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (_, i) => _ProductTile(product: products[i]),
    );
  }
}

class _ProductTile extends StatelessWidget {
  const _ProductTile({required this.product});
  final ProductModel product;

  @override
  Widget build(BuildContext context) {
    final isLow = product.isLowStock;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: AppRadius.lgBR,
          border: Border.all(
              color: isLow
                  ? AppColors.warning.withValues(alpha: 0.4)
                  : AppColors.divider)),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: isLow
                    ? AppColors.warningLight
                    : AppColors.surfaceVariant,
                borderRadius: AppRadius.mdBR),
            child: Icon(
              isLow
                  ? Icons.warning_amber_rounded
                  : Icons.inventory_2_outlined,
              size: 20,
              color: isLow
                  ? AppColors.warning
                  : AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: AppTextStyles.titleMedium),
                Text('NPR ${product.price.toStringAsFixed(0)}',
                    style: AppTextStyles.bodySmall),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                    color: isLow
                        ? AppColors.dangerLight
                        : AppColors.successLight,
                    borderRadius: AppRadius.pillBR),
                child: Text(
                  '${product.stock} in stock',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isLow
                          ? AppColors.danger
                          : AppColors.success),
                ),
              ),
              if (isLow)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Text(
                    'Low stock alert',
                    style: TextStyle(
                        fontSize: 11, color: AppColors.warning),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
