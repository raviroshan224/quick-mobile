import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/search_field.dart';
import '../../../services/domain/service_models.dart';
import '../../domain/pos_models.dart';
import '../providers/cart_provider.dart';
import '../providers/pos_data_provider.dart';
import 'checkout_sheet.dart';

class POSScreen extends HookConsumerWidget {
  const POSScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Row(
        children: [
          Expanded(child: _ServicePanel()),
          _CartPanel(),
        ],
      ),
    );
  }
}

// ─── Left: Service Panel ──────────────────────────────────────────────────────

class _ServicePanel extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categories = ref.watch(serviceCategoriesProvider);
    final selected = ref.watch(selectedCategoryProvider);
    final services = ref.watch(filteredServicesProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _POSTopBar(),
        _CategoryChips(categories: categories, selected: selected),
        Expanded(
          child: services.when(
            loading: () => const LoadingState(),
            error: (e, _) => ErrorState(message: e.toString()),
            data: (list) => list.isEmpty
                ? const EmptyState(
                    icon: Icons.content_cut_rounded,
                    title: 'No services found',
                    subtitle: 'Try a different category or search',
                  )
                : _ServicesGrid(services: list),
          ),
        ),
      ],
    );
  }
}

class _POSTopBar extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCtrl = useTextEditingController();
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Text('POS Billing', style: AppTextStyles.headlineMedium),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: AppSearchField(
              controller: searchCtrl,
              hint: 'Search services...',
              onChanged: (q) =>
                  ref.read(serviceSearchQueryProvider.notifier).state = q,
              onClear: () =>
                  ref.read(serviceSearchQueryProvider.notifier).state = '',
            ),
          ),
        ],
      ),
    );
  }
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.categories, required this.selected});
  final AsyncValue<List<ServiceCategory>> categories;
  final String? selected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      height: 52,
      color: Colors.white,
      child: categories.when(
        loading: () => const SizedBox(),
        error: (_, __) => const SizedBox(),
        data: (cats) => ListView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg, vertical: AppSpacing.sm),
          children: [
            _chip(context, ref, null, 'All'),
            ...cats.map((c) => _chip(context, ref, c.id, c.name)),
          ],
        ),
      ),
    );
  }

  Widget _chip(
      BuildContext context, WidgetRef ref, String? id, String label) {
    final isSelected = selected == id;
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.sm),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) =>
            ref.read(selectedCategoryProvider.notifier).state = id,
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary.withValues(alpha: 0.12),
        checkmarkColor: AppColors.primary,
        labelStyle: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          fontSize: 13,
        ),
        side: BorderSide(
            color: isSelected ? AppColors.primary : AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      ),
    );
  }
}

class _ServicesGrid extends ConsumerWidget {
  const _ServicesGrid({required this.services});
  final List<ServiceModel> services;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GridView.builder(
      padding: const EdgeInsets.all(AppSpacing.lg),
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 200,
        mainAxisExtent: 110,
        crossAxisSpacing: AppSpacing.sm,
        mainAxisSpacing: AppSpacing.sm,
      ),
      itemCount: services.length,
      itemBuilder: (_, i) => _ServiceCard(service: services[i]),
    );
  }
}

class _ServiceCard extends ConsumerWidget {
  const _ServiceCard({required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadius.lgBR,
      child: InkWell(
        borderRadius: AppRadius.lgBR,
        onTap: () => _showStaffPicker(context, ref),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: AppRadius.lgBR,
            border: Border.all(color: AppColors.divider),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: AppRadius.smBR,
                    ),
                    child: const Icon(Icons.content_cut_rounded,
                        size: 16, color: AppColors.primary),
                  ),
                  const Spacer(),
                  Text(service.durationLabel, style: AppTextStyles.labelSmall),
                ],
              ),
              const Spacer(),
              Text(service.name,
                  style: AppTextStyles.titleMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(service.priceLabel,
                  style: AppTextStyles.priceTag
                      .copyWith(color: AppColors.primary, fontSize: 14)),
            ],
          ),
        ),
      ),
    );
  }

  void _showStaffPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StaffPickerSheet(service: service),
    );
  }
}

class _StaffPickerSheet extends ConsumerWidget {
  const _StaffPickerSheet({required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(activeStaffProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.5,
      expand: false,
      builder: (_, sc) => Padding(
        padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg, AppSpacing.md, AppSpacing.lg, AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: AppSpacing.md),
                  decoration: BoxDecoration(
                      color: AppColors.divider,
                      borderRadius: AppRadius.pillBR)),
            ),
            Text('Assign Staff', style: AppTextStyles.headlineMedium),
            Text('Who is performing "${service.name}"?',
                style: AppTextStyles.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            ListTile(
              leading: const CircleAvatar(
                  child: Icon(Icons.person_off_outlined, size: 18)),
              title: const Text('No staff (unassigned)'),
              onTap: () {
                ref.read(cartProvider.notifier).addService(service);
                Navigator.pop(context);
              },
            ),
            const Divider(),
            Expanded(
              child: staffAsync.when(
                loading: () => const LoadingState(),
                error: (e, _) => ErrorState(message: e.toString()),
                data: (staffList) => ListView.builder(
                  controller: sc,
                  itemCount: staffList.length,
                  itemBuilder: (_, i) {
                    final s = staffList[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor:
                            AppColors.primary.withValues(alpha: 0.1),
                        child: Text(s.initials,
                            style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                                fontSize: 13)),
                      ),
                      title: Text(s.fullName),
                      subtitle: s.commissionRate != null
                          ? Text(
                              '${s.commissionRate?.toStringAsFixed(0)}% commission')
                          : null,
                      onTap: () {
                        ref
                            .read(cartProvider.notifier)
                            .addService(service, staff: s);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Right: Cart Panel ────────────────────────────────────────────────────────

class _CartPanel extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider);

    return Container(
      width: AppSpacing.cartPanelWidth,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          _CartHeader(cart: cart),
          Expanded(
            child: cart.items.isEmpty
                ? const EmptyState(
                    icon: Icons.shopping_cart_outlined,
                    title: 'Cart is empty',
                    subtitle: 'Tap a service to add it',
                  )
                : _CartItemsList(cart: cart),
          ),
          if (cart.items.isNotEmpty) _CartSummary(cart: cart),
          _CartActions(cart: cart),
        ],
      ),
    );
  }
}

class _CartHeader extends ConsumerWidget {
  const _CartHeader({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          border:
              Border(bottom: BorderSide(color: AppColors.divider))),
      child: Row(
        children: [
          const Icon(Icons.shopping_cart_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: AppSpacing.sm),
          Text('Cart', style: AppTextStyles.titleLarge),
          const SizedBox(width: AppSpacing.xs),
          if (cart.items.isNotEmpty)
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: AppRadius.pillBR),
              child: Text('${cart.items.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700)),
            ),
          const Spacer(),
          if (cart.customerLabel != null)
            _CustomerChip(cart: cart)
          else
            TextButton.icon(
              icon: const Icon(Icons.person_add_outlined, size: 14),
              label: const Text('Customer'),
              style: TextButton.styleFrom(
                  textStyle: const TextStyle(fontSize: 12)),
              onPressed: () => _showCustomerPicker(context, ref),
            ),
        ],
      ),
    );
  }

  void _showCustomerPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CustomerPickerSheet(),
    );
  }
}

class _CustomerChip extends ConsumerWidget {
  const _CustomerChip({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => ref.read(cartProvider.notifier).clearCustomer(),
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
            color: AppColors.primaryLight,
            borderRadius: AppRadius.pillBR),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(cart.customerLabel!,
                style: const TextStyle(
                    color: AppColors.primary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const SizedBox(width: 4),
            const Icon(Icons.close, size: 12, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _CustomerPickerSheet extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Customer', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Guest Checkout'),
            subtitle: const Text('No account required'),
            onTap: () {
              ref.read(cartProvider.notifier).setGuest();
              Navigator.pop(context);
            },
          ),
          const Divider(),
          for (final name in ['Sita Thapa', 'Rina Gurung', 'Maya Sharma'])
            ListTile(
              leading: CircleAvatar(
                  backgroundColor: AppColors.primaryLight,
                  child: Text(name[0],
                      style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700))),
              title: Text(name),
              onTap: () {
                ref.read(cartProvider.notifier).setGuest(name: name);
                Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }
}

class _CartItemsList extends ConsumerWidget {
  const _CartItemsList({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      itemCount: cart.items.length,
      separatorBuilder: (_, _) => const Divider(height: 1, indent: 16),
      itemBuilder: (_, i) => _CartItemTile(item: cart.items[i]),
    );
  }
}

class _CartItemTile extends ConsumerWidget {
  const _CartItemTile({required this.item});
  final CartItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.name, style: AppTextStyles.labelLarge),
                if (item.assignedStaff != null)
                  Text(item.assignedStaff!.fullName,
                      style: AppTextStyles.bodySmall
                          .copyWith(color: AppColors.primary)),
              ],
            ),
          ),
          Row(
            children: [
              _QtyButton(
                  icon: Icons.remove,
                  onTap: () => ref
                      .read(cartProvider.notifier)
                      .decrementQuantity(item.id)),
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm),
                child: Text('${item.quantity}',
                    style: AppTextStyles.titleMedium),
              ),
              _QtyButton(
                  icon: Icons.add,
                  onTap: () => ref
                      .read(cartProvider.notifier)
                      .incrementQuantity(item.id)),
            ],
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            'NPR ${item.totalPrice.toStringAsFixed(0)}',
            style: AppTextStyles.priceTag.copyWith(fontSize: 13),
          ),
          const SizedBox(width: AppSpacing.xs),
          IconButton(
            icon: const Icon(Icons.close, size: 14),
            color: AppColors.textTertiary,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () =>
                ref.read(cartProvider.notifier).removeItem(item.id),
          ),
        ],
      ),
    );
  }
}

class _QtyButton extends StatelessWidget {
  const _QtyButton({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 24,
        height: 24,
        decoration: BoxDecoration(
            border: Border.all(color: AppColors.divider),
            borderRadius: AppRadius.smBR),
        child: Icon(icon, size: 14, color: AppColors.textSecondary),
      ),
    );
  }
}

class _CartSummary extends ConsumerWidget {
  const _CartSummary({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
          border: Border(
              top: BorderSide(color: AppColors.divider),
              bottom: BorderSide(color: AppColors.divider))),
      child: Column(
        children: [
          _row('Subtotal', 'NPR ${cart.subtotal.toStringAsFixed(0)}'),
          if (cart.discountAmount > 0)
            _row('Discount',
                '- NPR ${cart.discountAmount.toStringAsFixed(0)}',
                color: AppColors.success),
          if (cart.tipAmount > 0)
            _row('Tip', 'NPR ${cart.tipAmount.toStringAsFixed(0)}'),
          const SizedBox(height: AppSpacing.xs),
          Row(
            children: [
              Text('Total', style: AppTextStyles.titleLarge),
              const Spacer(),
              Text(
                'NPR ${cart.total.toStringAsFixed(0)}',
                style: AppTextStyles.titleLarge
                    .copyWith(color: AppColors.primary, fontSize: 18),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              _SmallAction(
                icon: Icons.discount_outlined,
                label: 'Discount',
                onTap: () => _showDiscountSheet(context, ref),
              ),
              const SizedBox(width: AppSpacing.sm),
              _SmallAction(
                icon: Icons.volunteer_activism_outlined,
                label: 'Tip',
                onTap: () => _showTipSheet(context, ref),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, {Color? color}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          children: [
            Text(label, style: AppTextStyles.bodyMedium),
            const Spacer(),
            Text(value,
                style: AppTextStyles.bodyMedium.copyWith(
                    color: color ?? AppColors.textPrimary,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      );

  void _showDiscountSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DiscountSheet(),
    );
  }

  void _showTipSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TipSheet(),
    );
  }
}

class _SmallAction extends StatelessWidget {
  const _SmallAction(
      {required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(icon, size: 14),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 6),
          side: BorderSide(color: AppColors.divider),
          foregroundColor: AppColors.textSecondary,
        ),
      ),
    );
  }
}

class _CartActions extends ConsumerWidget {
  const _CartActions({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: cart.items.isEmpty
                  ? null
                  : () => showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        builder: (_) => const CheckoutSheet(),
                      ),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.md),
              ),
              child: Text(
                cart.items.isEmpty
                    ? 'Charge'
                    : 'Charge  NPR ${cart.total.toStringAsFixed(0)}',
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: cart.items.isEmpty
                  ? null
                  : () => ref.read(cartProvider.notifier).clear(),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppColors.divider),
                foregroundColor: AppColors.textSecondary,
                padding:
                    const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              ),
              child: const Text('Clear Cart'),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Discount Sheet ───────────────────────────────────────────────────────────

class _DiscountSheet extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = useTextEditingController();
    final isPercent = useState(true);

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Apply Discount', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: true, label: Text('Percentage %')),
              ButtonSegment(value: false, label: Text('Fixed Amount')),
            ],
            selected: {isPercent.value},
            onSelectionChanged: (s) => isPercent.value = s.first,
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: isPercent.value ? 'e.g. 10' : 'Amount in NPR',
              prefixText: isPercent.value ? '' : 'NPR ',
              suffixText: isPercent.value ? '%' : '',
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: FilledButton(
                  onPressed: () {
                    final v = double.tryParse(ctrl.text);
                    if (v != null && v > 0) {
                      ref.read(cartProvider.notifier).applyDiscount(
                          isPercent.value ? '$v% off' : 'NPR $v off',
                          v,
                          isPercentage: isPercent.value);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Apply'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Tip Sheet ────────────────────────────────────────────────────────────────

class _TipSheet extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = useTextEditingController();
    const tips = [100.0, 200.0, 500.0];

    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Add Tip', style: AppTextStyles.headlineMedium),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: tips
                .map((t) => Padding(
                      padding:
                          const EdgeInsets.only(right: AppSpacing.sm),
                      child: OutlinedButton(
                        onPressed: () =>
                            ctrl.text = t.toStringAsFixed(0),
                        child: Text('NPR ${t.toStringAsFixed(0)}'),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: AppSpacing.md),
          TextField(
            controller: ctrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
                hintText: 'Custom tip amount',
                prefixText: 'NPR '),
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () {
                final v = double.tryParse(ctrl.text) ?? 0;
                ref.read(cartProvider.notifier).setTip(v);
                Navigator.pop(context);
              },
              child: const Text('Apply Tip'),
            ),
          ),
        ],
      ),
    );
  }
}
