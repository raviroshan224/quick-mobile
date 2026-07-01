import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class AddEditCustomerScreen extends HookWidget {
  const AddEditCustomerScreen({super.key, this.customerId});
  final String? customerId;

  bool get isEditing => customerId != null;

  @override
  Widget build(BuildContext context) {
    final nameCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final emailCtrl = useTextEditingController();
    final notesCtrl = useTextEditingController();

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
                    onPressed: () => context.go(AppRoutes.customers)),
                Text(isEditing ? 'Edit Customer' : 'New Customer',
                    style: AppTextStyles.headlineMedium),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
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
                          Text('Customer Information',
                              style: AppTextStyles.titleLarge),
                          const SizedBox(height: AppSpacing.lg),
                          TextField(
                            controller: nameCtrl,
                            decoration:
                                const InputDecoration(labelText: 'Full Name *'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration:
                                const InputDecoration(labelText: 'Phone'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration:
                                const InputDecoration(labelText: 'Email'),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          TextField(
                            controller: notesCtrl,
                            maxLines: 3,
                            decoration:
                                const InputDecoration(labelText: 'Notes'),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    context.go(AppRoutes.customers),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              FilledButton(
                                onPressed: () =>
                                    context.go(AppRoutes.customers),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary),
                                child: Text(isEditing
                                    ? 'Save Changes'
                                    : 'Add Customer'),
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
