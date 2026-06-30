import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/services/presentation/providers/services_provider.dart';
import '../../../../features/inventory/presentation/providers/inventory_provider.dart';
import '../../../../features/customers/presentation/providers/customers_provider.dart';

// Tracks which optional steps the user has manually marked done.
final _dismissedProvider = StateProvider<Set<int>>((_) => {});

// ─── Screen ───────────────────────────────────────────────────────────────────

class SetupGuideScreen extends ConsumerWidget {
  const SetupGuideScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final serviceCount = ref.watch(servicesListProvider).valueOrNull?.length ?? 0;
    final itemCount = ref.watch(productsProvider).valueOrNull?.length ?? 0;
    final customerCount = ref.watch(customersProvider).valueOrNull?.length ?? 0;
    final dismissed = ref.watch(_dismissedProvider);

    final steps = _buildSteps(
        context, ref, dismissed, serviceCount, itemCount, customerCount);
    final doneCount = steps.where((s) => s.done).length;
    final total = steps.length;
    final progress = doneCount / total;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go(AppRoutes.more),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.black),
              ),
              const Spacer(),
              const Text('Setup Guide',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              const SizedBox(width: 18),
            ]),
          ),
          const SizedBox(height: 20),
          // ── Progress hero ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Get your salon ready',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '$doneCount of $total steps complete',
                    style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.55),
                        fontSize: 13),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: Colors.white.withValues(alpha: 0.18),
                      valueColor: const AlwaysStoppedAnimation<Color>(
                          AppColors.success),
                    ),
                  ),
                  const SizedBox(height: 8),
                  doneCount == total
                      ? const Row(children: [
                          Icon(Icons.check_circle_rounded,
                              size: 14, color: AppColors.success),
                          SizedBox(width: 6),
                          Text('All done — you\'re ready to go!',
                              style: TextStyle(
                                  color: AppColors.success,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ])
                      : Text(
                          '${total - doneCount} step${total - doneCount == 1 ? '' : 's'} remaining',
                          style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.45),
                              fontSize: 12),
                        ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // ── Steps list ──────────────────────────────────────────────────
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              itemCount: steps.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (_, i) => _StepCard(
                step: steps[i],
                onMarkDone: () => ref
                    .read(_dismissedProvider.notifier)
                    .update((s) => {...s, i}),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<_GuideStep> _buildSteps(
    BuildContext context,
    WidgetRef ref,
    Set<int> dismissed,
    int serviceCount,
    int itemCount,
    int customerCount,
  ) {
    return [
      _GuideStep(
        icon: Icons.person_rounded,
        iconColor: AppColors.primary,
        title: 'Create your account',
        description: 'Sign in to start managing your salon.',
        done: true,
        autoComplete: true,
      ),
      _GuideStep(
        icon: Icons.spa_outlined,
        iconColor: AppColors.primary,
        title: 'Add your services',
        description: serviceCount > 0
            ? '$serviceCount services ready — Hair, Nails, Skin, Makeup & Massage.'
            : 'Add the treatments your salon offers.',
        done: serviceCount > 0,
        autoComplete: serviceCount > 0,
        actionLabel: 'View Services',
        onAction: () => context.go(AppRoutes.moreServices),
      ),
      _GuideStep(
        icon: Icons.inventory_2_outlined,
        iconColor: const Color(0xFFF59E0B),
        title: 'Add inventory items',
        description: itemCount > 0
            ? '$itemCount products ready — shampoos, scissors, blades & more.'
            : 'Add retail products you sell at the counter.',
        done: itemCount > 0,
        autoComplete: itemCount > 0,
        actionLabel: 'View Items',
        onAction: () => context.go(AppRoutes.moreItems),
      ),
      _GuideStep(
        icon: Icons.person_add_outlined,
        iconColor: const Color(0xFF10B981),
        title: 'Add your first customer',
        description: customerCount > 0
            ? '$customerCount customers in your directory.'
            : 'Build a client list to track visits and preferences.',
        done: customerCount > 0 || dismissed.contains(3),
        autoComplete: customerCount > 0,
        actionLabel: 'View Customers',
        onAction: () => context.go(AppRoutes.moreCustomers),
        skippable: true,
      ),
      _GuideStep(
        icon: Icons.local_offer_outlined,
        iconColor: AppColors.textSecondary,
        title: 'Create a discount',
        description: 'Offer percentage or fixed discounts on services and items.',
        done: dismissed.contains(4),
        autoComplete: false,
        actionLabel: 'Set Up Discounts',
        onAction: () => context.go(AppRoutes.moreDiscounts),
        skippable: true,
      ),
      _GuideStep(
        icon: Icons.point_of_sale_outlined,
        iconColor: AppColors.primary,
        title: 'Open your cash drawer',
        description: 'Record your opening float before the first sale of the day.',
        done: dismissed.contains(5),
        autoComplete: false,
        actionLabel: 'Open Drawer',
        onAction: () => context.go(AppRoutes.moreDrawers),
        skippable: true,
      ),
      _GuideStep(
        icon: Icons.shopping_cart_checkout_rounded,
        iconColor: Colors.black,
        title: 'Make your first sale',
        description: 'Charge a customer and confirm your first payment.',
        done: dismissed.contains(6),
        autoComplete: false,
        actionLabel: 'Go to Checkout',
        onAction: () => context.go(AppRoutes.checkout),
        skippable: true,
      ),
    ];
  }
}

// ─── Data model ───────────────────────────────────────────────────────────────

class _GuideStep {
  const _GuideStep({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.description,
    required this.done,
    required this.autoComplete,
    this.actionLabel,
    this.onAction,
    this.skippable = false,
  });
  final IconData icon;
  final Color iconColor;
  final String title;
  final String description;
  final bool done;
  final bool autoComplete;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool skippable;
}

// ─── Step card ────────────────────────────────────────────────────────────────

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step, required this.onMarkDone});
  final _GuideStep step;
  final VoidCallback onMarkDone;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: step.done ? AppColors.background : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: step.done
              ? AppColors.divider
              : AppColors.border,
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Step indicator
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: step.done
                ? const Color(0xFFDCFCE7)
                : step.iconColor.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: step.done
              ? const Icon(Icons.check_rounded, size: 20, color: Color(0xFF16A34A))
              : Icon(step.icon, size: 20, color: step.iconColor),
        ),
        const SizedBox(width: 14),
        // Content
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(
                  step.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: step.done ? AppColors.textTertiary : Colors.black,
                    decoration:
                        step.done ? TextDecoration.lineThrough : null,
                    decorationColor: AppColors.textTertiary,
                  ),
                ),
              ),
              if (step.done)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDCFCE7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text('Done',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF16A34A))),
                ),
            ]),
            const SizedBox(height: 3),
            Text(step.description,
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
            if (!step.done) ...[
              const SizedBox(height: 12),
              Row(children: [
                if (step.actionLabel != null)
                  GestureDetector(
                    onTap: step.onAction,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(step.actionLabel!,
                          style: const TextStyle(
                              fontSize: 13,
                              color: Colors.white,
                              fontWeight: FontWeight.w500)),
                    ),
                  ),
                if (step.skippable) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: onMarkDone,
                    child: const Text('Mark done',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textTertiary,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.textTertiary)),
                  ),
                ],
              ]),
            ],
          ]),
        ),
      ]),
    );
  }
}
