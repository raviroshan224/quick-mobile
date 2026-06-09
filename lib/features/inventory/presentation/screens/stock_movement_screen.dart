import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/inventory_models.dart';
import '../providers/inventory_provider.dart';

class StockMovementScreen extends HookConsumerWidget {
  const StockMovementScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(productsProvider);
    final logsAsync = ref.watch(inventoryLogsProvider);
    final selectedProduct = useState<ProductModel?>(null);
    final type = useState(InventoryMovementType.stockIn);
    final qtyCtrl = useTextEditingController();
    final reasonCtrl = useTextEditingController();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          // Left: form
          Expanded(
            flex: 2,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      IconButton(
                          icon: const Icon(Icons.arrow_back_rounded),
                          onPressed: () =>
                              context.go(AppRoutes.inventory)),
                      Text('Stock Movement',
                          style: AppTextStyles.headlineMedium),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.lgBR,
                        side: BorderSide(color: AppColors.divider)),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Movement Type',
                              style: AppTextStyles.titleMedium),
                          const SizedBox(height: AppSpacing.sm),
                          SegmentedButton<InventoryMovementType>(
                            segments: const [
                              ButtonSegment(
                                  value: InventoryMovementType.stockIn,
                                  label: Text('Stock In'),
                                  icon: Icon(Icons.add_rounded)),
                              ButtonSegment(
                                  value: InventoryMovementType.stockOut,
                                  label: Text('Stock Out'),
                                  icon: Icon(Icons.remove_rounded)),
                              ButtonSegment(
                                  value: InventoryMovementType.adjustment,
                                  label: Text('Adjustment'),
                                  icon: Icon(Icons.tune_rounded)),
                            ],
                            selected: {type.value},
                            onSelectionChanged: (s) =>
                                type.value = s.first,
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text('Product',
                              style: AppTextStyles.titleMedium),
                          const SizedBox(height: AppSpacing.sm),
                          productsAsync.when(
                            loading: () => const CircularProgressIndicator(),
                            error: (e, _) =>
                                ErrorState(message: e.toString()),
                            data: (products) =>
                                DropdownButtonFormField<ProductModel>(
                              hint: const Text('Select a product'),
                              items: products
                                  .map((p) => DropdownMenuItem(
                                      value: p, child: Text(p.name)))
                                  .toList(),
                              onChanged: (p) =>
                                  selectedProduct.value = p,
                              decoration: const InputDecoration(
                                  border: OutlineInputBorder()),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: qtyCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Quantity *'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: reasonCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Reason / Notes'),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton(
                              onPressed: () =>
                                  context.go(AppRoutes.inventory),
                              style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary),
                              child: const Text('Record Movement'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Right: logs
          Expanded(
            flex: 3,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Text('Movement History',
                      style: AppTextStyles.titleLarge),
                ),
                Expanded(
                  child: logsAsync.when(
                    loading: () => const LoadingState(),
                    error: (e, _) => ErrorState(message: e.toString()),
                    data: (logs) => logs.isEmpty
                        ? const EmptyState(
                            icon: Icons.history_rounded,
                            title: 'No movements yet')
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppSpacing.lg),
                            itemCount: logs.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (_, i) =>
                                _LogTile(log: logs[i]),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});
  final InventoryLogEntry log;

  @override
  Widget build(BuildContext context) {
    final isIn = log.type == InventoryMovementType.stockIn;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
            color: isIn ? AppColors.successLight : AppColors.dangerLight,
            shape: BoxShape.circle),
        child: Icon(
          isIn ? Icons.add_rounded : Icons.remove_rounded,
          color: isIn ? AppColors.success : AppColors.danger,
          size: 18,
        ),
      ),
      title: Text(log.productName, style: AppTextStyles.titleMedium),
      subtitle: Text(log.reason,
          style: AppTextStyles.bodySmall),
      trailing: Text(
        '${isIn ? '+' : '-'}${log.quantity}',
        style: TextStyle(
            color: isIn ? AppColors.success : AppColors.danger,
            fontWeight: FontWeight.w700,
            fontSize: 16),
      ),
    );
  }
}
