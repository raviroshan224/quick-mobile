import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../domain/staff_models.dart';
import '../providers/staff_provider.dart';

class StaffListScreen extends ConsumerWidget {
  const StaffListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            color: Colors.white,
            child: Row(
              children: [
                Text('Staff', style: AppTextStyles.headlineMedium),
              ],
            ),
          ),
          Expanded(
            child: staffAsync.when(
              loading: () => const LoadingState(),
              error: (e, _) => ErrorState(message: e.toString()),
              data: (list) => list.isEmpty
                  ? const EmptyState(
                      icon: Icons.badge_outlined,
                      title: 'No staff members',
                      subtitle: 'Add your first staff member',
                    )
                  : _StaffGrid(staff: list),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go(AppRoutes.staffNew),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('Add Staff'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _StaffGrid extends StatelessWidget {
  const _StaffGrid({required this.staff});
  final List<StaffModel> staff;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 280,
        mainAxisExtent: 160,
        crossAxisSpacing: AppSpacing.md,
        mainAxisSpacing: AppSpacing.md,
      ),
      itemCount: staff.length,
      itemBuilder: (_, i) => _StaffCard(member: staff[i]),
    );
  }
}

class _StaffCard extends StatelessWidget {
  const _StaffCard({required this.member});
  final StaffModel member;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.lgBR,
      child: InkWell(
        borderRadius: AppRadius.lgBR,
        onTap: () => context.go(AppRoutes.staffDetail(member.id)),
        child: Container(
          decoration: BoxDecoration(
              borderRadius: AppRadius.lgBR,
              border: Border.all(
                  color: member.isActive
                      ? AppColors.divider
                      : AppColors.divider.withValues(alpha: 0.5))),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: member.isActive
                        ? AppColors.primaryLight
                        : AppColors.surfaceVariant,
                    child: Text(member.initials,
                        style: TextStyle(
                            color: member.isActive
                                ? AppColors.primary
                                : AppColors.textTertiary,
                            fontWeight: FontWeight.w700,
                            fontSize: 18)),
                  ),
                  if (!member.isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                            color: AppColors.textTertiary,
                            shape: BoxShape.circle),
                      ),
                    ),
                  if (member.isActive)
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        width: 14,
                        height: 14,
                        decoration: const BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(member.fullName,
                  style: AppTextStyles.titleMedium,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis),
              if (member.commissionRate != null)
                Text(
                    '${member.commissionRate?.toStringAsFixed(0)}% commission',
                    style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}
