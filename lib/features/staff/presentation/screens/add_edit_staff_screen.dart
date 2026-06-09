import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class AddEditStaffScreen extends HookWidget {
  const AddEditStaffScreen({super.key, this.staffId});
  final String? staffId;

  bool get isEditing => staffId != null;

  @override
  Widget build(BuildContext context) {
    final firstCtrl = useTextEditingController();
    final lastCtrl = useTextEditingController();
    final phoneCtrl = useTextEditingController();
    final commissionCtrl = useTextEditingController();

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
                    onPressed: () => context.go(AppRoutes.staff)),
                Text(isEditing ? 'Edit Staff' : 'New Staff Member',
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
                          Text('Staff Information',
                              style: AppTextStyles.titleLarge),
                          const SizedBox(height: AppSpacing.lg),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: firstCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'First Name *'),
                                ),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              Expanded(
                                child: TextField(
                                  controller: lastCtrl,
                                  decoration: const InputDecoration(
                                      labelText: 'Last Name *'),
                                ),
                              ),
                            ],
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
                            controller: commissionCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                                labelText: 'Commission Rate (%)',
                                hintText: 'e.g. 15'),
                          ),
                          const SizedBox(height: AppSpacing.xl),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              OutlinedButton(
                                onPressed: () =>
                                    context.go(AppRoutes.staff),
                                child: const Text('Cancel'),
                              ),
                              const SizedBox(width: AppSpacing.md),
                              FilledButton(
                                onPressed: () =>
                                    context.go(AppRoutes.staff),
                                style: FilledButton.styleFrom(
                                    backgroundColor: AppColors.primary),
                                child: Text(isEditing
                                    ? 'Save Changes'
                                    : 'Add Staff Member'),
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
