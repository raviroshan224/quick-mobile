import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class AddEditServiceScreen extends HookWidget {
  const AddEditServiceScreen({super.key, this.serviceId});
  final String? serviceId;

  bool get isEditing => serviceId != null;

  @override
  Widget build(BuildContext context) {
    final nameCtrl = useTextEditingController();
    final priceCtrl = useTextEditingController();
    final durationCtrl = useTextEditingController();

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
                IconButton(
                    icon: const Icon(Icons.arrow_back_rounded),
                    onPressed: () => context.go(AppRoutes.services)),
                Text(isEditing ? 'Edit Service' : 'New Service',
                    style: AppTextStyles.headlineMedium),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 560),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: AppRadius.lgBR,
                        side: BorderSide(color: AppColors.divider)),
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.xxl),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Service Details',
                              style: AppTextStyles.titleLarge),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: nameCtrl,
                            decoration: const InputDecoration(
                                labelText: 'Service Name *'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: priceCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Price (NPR) *',
                                      prefixText: 'NPR '),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: TextField(
                                  controller: durationCtrl,
                                  keyboardType: TextInputType.number,
                                  decoration: const InputDecoration(
                                      labelText: 'Duration (min)',
                                      suffixText: 'min'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment:
                                MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    context.go(AppRoutes.services),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              FilledButton(
                                onPressed: () =>
                                    context.go(AppRoutes.services),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary),
                                child: Text(isEditing
                                    ? 'Save Changes'
                                    : 'Add Service'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
