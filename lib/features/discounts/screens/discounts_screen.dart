import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../features/auth/presentation/providers/auth_provider.dart';
import '../models/discount_model.dart';
import '../providers/discounts_provider.dart';

class DiscountsScreen extends ConsumerWidget {
  const DiscountsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isOwnerProvider);
    final discounts = ref.watch(discountsProvider);
    final active = discounts.where((d) => d.isActive).toList();
    final inactive = discounts.where((d) => !d.isActive).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Discounts')),
      body: discounts.isEmpty
          ? _EmptyState(onAdd: isOwner ? () => context.push('/more/discounts/new') : null)
          : ListView(
              padding: const EdgeInsets.only(bottom: 100),
              children: [
                if (active.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Active',
                    count: active.length,
                  ),
                  ...active.map(
                    (d) => _DiscountRow(
                      discount: d,
                      onTap: isOwner ? () => context.push('/more/discounts/${d.id}') : null,
                    ),
                  ),
                ],
                if (inactive.isNotEmpty) ...[
                  _SectionHeader(
                    label: 'Inactive',
                    count: inactive.length,
                  ),
                  ...inactive.map(
                    (d) => _DiscountRow(
                      discount: d,
                      onTap: isOwner ? () => context.push('/more/discounts/${d.id}') : null,
                    ),
                  ),
                ],
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                  child: Text(
                    'Staff can apply one discount per transaction from the checkout Library tab.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: isOwner ? () => context.push('/more/discounts/new') : null,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.add),
        label: const Text('New Discount',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 6),
      child: Text(
        '${label.toUpperCase()}  $count',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.textSecondary),
      ),
    );
  }
}

// ── Discount row ──────────────────────────────────────────────────────────────

class _DiscountRow extends StatelessWidget {
  final Discount discount;
  final VoidCallback? onTap;

  const _DiscountRow({required this.discount, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isPercentage = discount.type == DiscountType.percentage;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _DiscountAvatar(discount: discount),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    discount.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: discount.isActive
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${isPercentage ? 'Percentage' : 'Fixed'} · ${discount.scopeLabel}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            Text(
              discount.label,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: discount.isActive
                    ? AppColors.success
                    : AppColors.textTertiary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _DiscountAvatar extends StatelessWidget {
  final Discount discount;
  const _DiscountAvatar({required this.discount});

  @override
  Widget build(BuildContext context) {
    final isPercentage = discount.type == DiscountType.percentage;
    final color = discount.isActive ? AppColors.success : AppColors.textTertiary;
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Center(
        child: Icon(
          isPercentage ? Icons.percent : Icons.currency_rupee,
          size: 20,
          color: color,
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback? onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.local_offer_outlined,
                  size: 32, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            const Text('No discounts yet',
                style:
                    TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Create discount presets that staff can\napply with one tap at checkout.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create First Discount',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
