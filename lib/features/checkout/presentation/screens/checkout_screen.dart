import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/pos/domain/pos_models.dart';
import '../../../../features/pos/presentation/providers/cart_provider.dart';
import '../../../../features/services/data/mock_services_repository.dart';
import '../../../../features/services/domain/service_models.dart';
import 'review_sale_sheet.dart';
import 'calendar_tab.dart';
import '../../../../features/discounts/widgets/discount_picker_sheet.dart';
import '../../../../features/discounts/providers/discounts_provider.dart';

// ─── Services data provider ───────────────────────────────────────────────────

final _checkoutServicesProvider = FutureProvider<List<ServiceModel>>((ref) {
  return MockServicesRepository().getServices();
});

final _checkoutCategoriesProvider = FutureProvider<List<ServiceCategory>>((
  ref,
) {
  return MockServicesRepository().getCategories();
});

// ─── Root screen ─────────────────────────────────────────────────────────────

class CheckoutScreen extends HookConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = useState(0); // 0=Keypad 1=Calendar 2=Services

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            _SegmentedHeader(
              selected: tabIndex.value,
              onChanged: (i) => tabIndex.value = i,
            ),
            Expanded(
              child: switch (tabIndex.value) {
                0 => _KeypadView(),
                1 => const CalendarTab(),
                _ => _ServicesView(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 3-tab segmented header ───────────────────────────────────────────────────

class _SegmentedHeader extends StatelessWidget {
  const _SegmentedHeader({required this.selected, required this.onChanged});
  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE5E7EB), width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SegTab(
              label: 'Keypad',
              active: selected == 0,
              onTap: () => onChanged(0),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegTab(
              label: 'Calendar',
              active: selected == 1,
              onTap: () => onChanged(1),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _SegTab(
              label: 'Services',
              active: selected == 2,
              onTap: () => onChanged(2),
            ),
          ),
        ],
      ),
    );
  }
}

class _SegTab extends StatelessWidget {
  const _SegTab({
    required this.label,
    required this.active,
    required this.onTap,
  });
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: 34,
        decoration: BoxDecoration(
          color: active ? Colors.black : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : const Color(0xFF6B7280),
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Keypad View ──────────────────────────────────────────────────────────────

class _KeypadView extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = useState('0');
    final cart = ref.watch(cartProvider);

    void press(String key) {
      HapticFeedback.lightImpact();
      if (key == 'C') {
        display.value = '0';
      } else if (key == '.') {
        if (!display.value.contains('.')) {
          display.value = '${display.value}.';
        }
      } else {
        if (display.value == '0') {
          display.value = key;
        } else {
          if (display.value.contains('.')) {
            final parts = display.value.split('.');
            if (parts[1].length < 2) {
              display.value = '${display.value}$key';
            }
          } else {
            display.value = '${display.value}$key';
          }
        }
      }
    }

    final amount = double.tryParse(display.value) ?? 0;
    final hasItems = cart.items.isNotEmpty;

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'NPR ${display.value}',
                style: const TextStyle(
                  fontSize: 48,
                  fontWeight: FontWeight.w300,
                  color: Colors.black,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 8),
              _NoteButton(),
            ],
          ),
        ),
        Expanded(
          flex: 3,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              children: [
                for (final row in [
                  ['1', '2', '3'],
                  ['4', '5', '6'],
                  ['7', '8', '9'],
                  ['C', '0', '.'],
                ])
                  Expanded(
                    child: Row(
                      children: row
                          .map(
                            (k) => Expanded(
                              child: _KeypadKey(
                                label: k,
                                onTap: () => press(k),
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: _ChargeButton(
            amount: amount,
            itemCount: cart.itemCount,
            onTap: amount > 0 || hasItems
                ? () => _showReviewSale(context, ref, amount)
                : null,
          ),
        ),
      ],
    );
  }

  void _showReviewSale(BuildContext context, WidgetRef ref, double amount) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ReviewSaleSheet(keypadAmount: amount),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w300,
              color: Colors.black,
            ),
          ),
        ),
      ),
    );
  }
}

class _NoteButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => _showNoteSheet(context, ref),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.add, size: 14, color: Color(0xFF6B7280)),
          SizedBox(width: 4),
          Text(
            'Note',
            style: TextStyle(
              color: Color(0xFF6B7280),
              fontSize: 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  void _showNoteSheet(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _NoteSheet(),
    );
  }
}

class _NoteSheet extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = useTextEditingController();
    const quickTags = ['Tip', '#cash', '#card', '#online', 'staff', 'gst'];

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: const Icon(Icons.close, size: 22),
                    ),
                    const Spacer(),
                    const Text(
                      'Add Note',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    GestureDetector(
                      onTap: () {
                        ref.read(cartProvider.notifier).setNotes(ctrl.text);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Save',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Note',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    contentPadding: EdgeInsets.all(12),
                    counterStyle: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quick add',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: quickTags
                      .map(
                        (t) => GestureDetector(
                          onTap: () {
                            ctrl.text = ctrl.text.isEmpty
                                ? t
                                : '${ctrl.text} $t';
                          },
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF3F4F6),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              t,
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ChargeButton extends StatelessWidget {
  const _ChargeButton({
    required this.amount,
    required this.itemCount,
    required this.onTap,
  });
  final double amount;
  final int itemCount;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: enabled ? Colors.black : const Color(0xFFD1D5DB),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(
          child: Text(
            amount > 0
                ? 'Charge NPR ${amount.toStringAsFixed(2)}'
                : 'Charge NPR 0.00',
            style: TextStyle(
              color: enabled ? Colors.white : const Color(0xFF9CA3AF),
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Library View ─────────────────────────────────────────────────────────────

class _LibraryView extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchCtrl = useTextEditingController();
    final searchQ = useState('');
    final cart = ref.watch(cartProvider);
    final appliedDiscount = ref.watch(checkoutDiscountProvider);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: searchCtrl,
            onChanged: (v) => searchQ.value = v,
            decoration: InputDecoration(
              hintText: 'Search',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        _LibraryRow(
          icon: Icons.spa_outlined,
          label: 'Services',
          subtitle: 'Haircut, Face Wash, Massage…',
          onTap: () => context.go(AppRoutes.moreServices),
        ),
        _LibraryRow(
          icon: Icons.inventory_2_outlined,
          label: 'Items',
          subtitle: 'Shampoo, Scissors, Blade…',
          onTap: () => context.go(AppRoutes.moreItems),
        ),
        _LibraryRow(
          icon: Icons.local_offer_outlined,
          label: 'Discounts',
          subtitle: appliedDiscount != null
              ? '${appliedDiscount.label} applied'
              : 'Add a discount to the sale',
          subtitleColor: appliedDiscount != null
              ? const Color(0xFF16A34A)
              : null,
          onTap: () => DiscountPickerSheet.show(context),
        ),
        const Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Recently Used',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: Color(0xFF6B7280),
              ),
            ),
          ),
        ),
        Expanded(child: _RecentServicesList(query: searchQ.value)),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: cart.items.isEmpty
              ? _CreateNewItemButton()
              : _ReviewSaleButton(cart: cart),
        ),
      ],
    );
  }
}

class _LibraryRow extends StatelessWidget {
  const _LibraryRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
    this.subtitleColor,
  });
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color? subtitleColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 20, color: Colors.black87),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  if (subtitle != null)
                    Text(
                      subtitle!,
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor ?? const Color(0xFF9CA3AF),
                      ),
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 20, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// Recently used services (static for now)
class _RecentServicesList extends ConsumerWidget {
  const _RecentServicesList({required this.query});
  final String query;

  static final _recent = [
    ServiceModel(id: 's-01', name: 'Haircut (Men)', price: 200, duration: 20),
    ServiceModel(id: 's-18', name: 'Face Wash', price: 200, duration: 15),
    ServiceModel(id: 's-11', name: 'Beard Trim', price: 100, duration: 10),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = query.isEmpty
        ? _recent
        : _recent
              .where((s) => s.name.toLowerCase().contains(query.toLowerCase()))
              .toList();

    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: filtered.length,
      separatorBuilder: (_, _) =>
          const Divider(height: 1, indent: 50, color: Color(0xFFF3F4F6)),
      itemBuilder: (_, i) => _ServiceTile(service: filtered[i]),
    );
  }
}

class _ServiceTile extends ConsumerWidget {
  const _ServiceTile({required this.service});
  final ServiceModel service;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(cartProvider.notifier).addService(service);
        HapticFeedback.selectionClick();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.spa_outlined,
                size: 16,
                color: Color(0xFF6B7280),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(service.name, style: const TextStyle(fontSize: 15)),
                  Text(
                    service.durationLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'NPR ${service.price.toStringAsFixed(0)}',
              style: const TextStyle(fontSize: 15, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateNewItemButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: const Center(
        child: Text(
          'Create a new item',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w500,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}

class _ReviewSaleButton extends StatelessWidget {
  const _ReviewSaleButton({required this.cart});
  final CartState cart;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => const ReviewSaleSheet(keypadAmount: 0),
      ),
      child: Container(
        width: double.infinity,
        height: 52,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Review Sale',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                style: const TextStyle(color: Color(0xFF9CA3AF), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Services View (3rd tab) ──────────────────────────────────────────────────

class _ServicesView extends HookConsumerWidget {
  static const _catColors = {
    'cat-1': Color(0xFFDBEAFE),
    'cat-2': Color(0xFFFCE7F3),
    'cat-3': Color(0xFFD1FAE5),
    'cat-4': Color(0xFFEDE9FE),
    'cat-5': Color(0xFFFFEDD5),
  };
  static const _catIcons = {
    'cat-1': Icons.content_cut_rounded,
    'cat-2': Icons.back_hand_outlined,
    'cat-3': Icons.face_retouching_natural,
    'cat-4': Icons.auto_awesome,
    'cat-5': Icons.self_improvement,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(_checkoutServicesProvider);
    final catsAsync = ref.watch(_checkoutCategoriesProvider);
    final searchQ = useState('');
    final searchCtrl = useTextEditingController();
    final selectedCat = useState<String?>(null);
    final cart = ref.watch(cartProvider);

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: searchCtrl,
            onChanged: (v) => searchQ.value = v,
            decoration: InputDecoration(
              hintText: 'Search services',
              hintStyle: const TextStyle(
                color: Color(0xFF9CA3AF),
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: Color(0xFF9CA3AF),
              ),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        // Category chips
        SizedBox(
          height: 44,
          child: catsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (cats) => ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                _CatChip(
                  label: 'All',
                  selected: selectedCat.value == null,
                  onTap: () => selectedCat.value = null,
                ),
                ...cats.map(
                  (c) => _CatChip(
                    label: c.name,
                    selected: selectedCat.value == c.id,
                    onTap: () => selectedCat.value = c.id,
                  ),
                ),
              ],
            ),
          ),
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),
        // Service list
        Expanded(
          child: servicesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (services) {
              final filtered = services.where((s) {
                final matchCat =
                    selectedCat.value == null ||
                    s.category?.id == selectedCat.value;
                final matchSearch =
                    searchQ.value.isEmpty ||
                    s.name.toLowerCase().contains(searchQ.value.toLowerCase());
                return matchCat && matchSearch;
              }).toList();

              if (filtered.isEmpty) {
                return const Center(
                  child: Text(
                    'No services found',
                    style: TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
                  ),
                );
              }

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  indent: 62,
                  color: Color(0xFFF3F4F6),
                ),
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  final catId = s.category?.id ?? '';
                  return _ServiceListTile(
                    service: s,
                    iconBg: _catColors[catId] ?? const Color(0xFFF3F4F6),
                    icon: _catIcons[catId] ?? Icons.spa_outlined,
                  );
                },
              );
            },
          ),
        ),
        // Charge / Review button
        if (cart.items.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            child: _ReviewSaleButton(cart: cart),
          ),
      ],
    );
  }
}

class _CatChip extends StatelessWidget {
  const _CatChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.black : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

class _ServiceListTile extends ConsumerWidget {
  const _ServiceListTile({
    required this.service,
    required this.iconBg,
    required this.icon,
  });
  final ServiceModel service;
  final Color iconBg;
  final IconData icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () {
        ref.read(cartProvider.notifier).addService(service);
        HapticFeedback.selectionClick();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${service.name} added'),
            duration: const Duration(milliseconds: 1200),
            behavior: SnackBarBehavior.floating,
            backgroundColor: Colors.black,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: Colors.black54),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    service.durationLabel,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'NPR ${service.price.toStringAsFixed(0)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.black,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
