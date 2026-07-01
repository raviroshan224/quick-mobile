import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';

class RefundsScreen extends HookConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCtrl = useTextEditingController();

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
                Text('Refunds', style: AppTextStyles.headlineMedium),
                const SizedBox(width: AppSpacing.lg),
                Expanded(
                  child: TextField(
                    controller: searchCtrl,
                    decoration: const InputDecoration(
                        hintText: 'Search transaction by ID or customer...',
                        prefixIcon: Icon(Icons.search_rounded, size: 20)),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const EmptyState(
                    icon: Icons.undo_rounded,
                    title: 'No refunds yet',
                    subtitle:
                        'Search for a transaction above to process a refund',
                  ),
                  const SizedBox(height: AppSpacing.lg),
                  _InfoCard(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 400,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
          color: AppColors.infoLight,
          borderRadius: AppRadius.lgBR,
          border:
              Border.all(color: AppColors.info.withValues(alpha: 0.3))),
      child: Row(
        children: [
          const Icon(Icons.info_outline_rounded,
              color: AppColors.info, size: 20),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Refunds are cash-only and require a mandatory reason. The amount is automatically added to the cash drawer as a Pay Out.',
              style:
                  AppTextStyles.bodyMedium.copyWith(color: AppColors.info),
            ),
          ),
        ],
      ),
    );
  }
}
