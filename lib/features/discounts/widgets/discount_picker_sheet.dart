import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../checkout/presentation/widgets/manual_discount_sheet.dart';
import '../../pos/domain/pos_models.dart' show DiscountEntry, DiscountEntryScope;
import '../models/discount_model.dart';
import '../providers/discounts_provider.dart';
import '../../pos/presentation/providers/cart_provider.dart';

/// Bottom sheet shown from checkout when staff taps "Add discount". Lists
/// active discounts as tappable cards, applying the tapped one straight to
/// the cart (the single source of truth is `cartProvider`'s `CartState.discount`
/// — there's no separate "applied" tracking state to drift out of sync).
class DiscountPickerSheet extends ConsumerWidget {
  const DiscountPickerSheet({super.key, required this.subtotal});
  final double subtotal;

  static Future<void> show(BuildContext context, {required double subtotal}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DiscountPickerSheet(subtotal: subtotal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final discountsAsync = ref.watch(discountsProvider);
    final cart = ref.watch(cartProvider);
    // Hide discounts scoped to a service that isn't in the cart — applying
    // one would silently compute to Rs 0 with no explanation.
    final active = discountsAsync.value
            ?.where((d) => d.isActive)
            .where((d) =>
                d.scope == DiscountScope.all ||
                cart.items.any((i) => i.service?.id == d.serviceId))
            .toList() ??
        const [];
    final applied = cart.discount;

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ────────────────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(height: 4),

          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Apply Discount',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                TextButton(
                  onPressed: () => context.push('/more/discounts'),
                  child: const Text('Manage',
                      style: TextStyle(
                          color: AppColors.accent, fontWeight: FontWeight.w500)),
                ),
              ],
            ),
          ),
          const Divider(height: 1),

          // ── Applied banner ────────────────────────────────────────────
          if (applied != null && applied.discountId != null)
            _AppliedBanner(
              discount: applied,
              onRemove: () {
                ref.read(cartProvider.notifier).clearDiscount();
                Navigator.pop(context);
              },
            ),

          // ── Manual entry ──────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.edit_outlined, color: AppColors.textSecondary),
            title: const Text('Enter a manual discount',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            onTap: () {
              Navigator.pop(context);
              ManualDiscountSheet.show(context, subtotal: subtotal);
            },
          ),
          const Divider(height: 1, indent: 16),

          // ── Discount list ─────────────────────────────────────────────
          if (active.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(Icons.local_offer_outlined,
                      size: 36, color: AppColors.textTertiary),
                  SizedBox(height: 10),
                  Text('No active discounts for this cart',
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary)),
                  SizedBox(height: 4),
                  Text('Add discounts in More → Discounts',
                      style: TextStyle(
                          fontSize: 13, color: AppColors.textTertiary)),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: active.length,
              separatorBuilder: (context, i) =>
                  const Divider(height: 1, indent: 16),
              itemBuilder: (_, i) {
                final d = active[i];
                final isApplied = applied?.discountId == d.id;
                return _DiscountTile(
                  discount: d,
                  isApplied: isApplied,
                  onTap: () {
                    if (isApplied) {
                      ref.read(cartProvider.notifier).clearDiscount();
                    } else {
                      ref.read(cartProvider.notifier).applyDiscount(
                            d.name,
                            d.value,
                            isPercentage: d.type == DiscountType.percentage,
                            discountId: d.id,
                            scope: d.scope == DiscountScope.service
                                ? DiscountEntryScope.service
                                : DiscountEntryScope.all,
                            serviceId: d.serviceId,
                          );
                    }
                    Navigator.pop(context);
                  },
                );
              },
            ),

          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Applied banner ────────────────────────────────────────────────────────────

class _AppliedBanner extends StatelessWidget {
  final DiscountEntry discount;
  final VoidCallback onRemove;

  const _AppliedBanner({required this.discount, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline,
              size: 18, color: AppColors.success),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '${discount.label} applied',
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: AppColors.success),
            ),
          ),
          GestureDetector(
            onTap: onRemove,
            child: const Text('Remove',
                style: TextStyle(
                    fontSize: 13,
                    color: AppColors.refund,
                    fontWeight: FontWeight.w500)),
          ),
        ],
      ),
    );
  }
}

// ── Discount tile ─────────────────────────────────────────────────────────────

class _DiscountTile extends StatelessWidget {
  final Discount discount;
  final bool isApplied;
  final VoidCallback onTap;

  const _DiscountTile({
    required this.discount,
    required this.isApplied,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPercentage = discount.type == DiscountType.percentage;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.success.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Icon(
                  isPercentage ? Icons.percent : Icons.currency_rupee,
                  size: 20,
                  color: AppColors.success,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(discount.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 1),
                  Text(
                    '${discount.label} · ${discount.scopeLabel}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (isApplied)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Applied',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              )
            else
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Apply',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary)),
              ),
          ],
        ),
      ),
    );
  }
}
