import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../providers/staff_provider.dart';

class StaffDetailScreen extends ConsumerWidget {
  const StaffDetailScreen({super.key, required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider);

    return staffAsync.when(
      loading: () => const Scaffold(body: LoadingState()),
      error: (e, _) => Scaffold(body: ErrorState(message: e.toString())),
      data: (list) {
        final member = list.where((s) => s.id == staffId).firstOrNull;
        if (member == null) {
          return const Scaffold(
              body: EmptyState(
                  icon: Icons.badge_outlined, title: 'Staff not found'));
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
                    IconButton(
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => context.go(AppRoutes.staff)),
                    const SizedBox(width: AppSpacing.sm),
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.primaryLight,
                      child: Text(member.initials,
                          style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w700,
                              fontSize: 18)),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(member.fullName,
                              style: AppTextStyles.headlineMedium),
                          if (member.phone != null)
                            Text(member.phone!,
                                style: AppTextStyles.bodyMedium),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                    color: member.isActive
                                        ? AppColors.successLight
                                        : AppColors.surfaceVariant,
                                    borderRadius: AppRadius.pillBR),
                                child: Text(
                                    member.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                        color: member.isActive
                                            ? AppColors.success
                                            : AppColors.textTertiary)),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: const Text('Edit'),
                      onPressed: () =>
                          context.go(AppRoutes.staffEdit(staffId)),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoTile(
                        label: 'Commission Rate',
                        value: member.commissionRate != null
                            ? '${member.commissionRate?.toStringAsFixed(0)}%'
                            : 'N/A'),
                    const SizedBox(width: AppSpacing.md),
                    _InfoTile(
                        label: 'Specialties',
                        value: member.specialties.isEmpty
                            ? 'None'
                            : member.specialties.join(', ')),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.lg),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadius.lgBR,
            border: Border.all(color: AppColors.divider)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppTextStyles.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: AppTextStyles.titleMedium),
          ],
        ),
      ),
    );
  }
}
