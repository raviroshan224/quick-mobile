import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../features/pos/domain/pos_models.dart';
import '../../../../features/pos/presentation/providers/cart_provider.dart';
import '../../../../features/services/domain/service_colors.dart';
import '../../../../features/services/domain/service_models.dart';
import '../../../../features/services/presentation/providers/services_provider.dart';
import '../../../../features/inventory/domain/inventory_models.dart';
import '../../../../features/inventory/presentation/providers/inventory_provider.dart';
import '../../../../core/theme/app_theme.dart';
import 'review_sale_sheet.dart';
import 'calendar_tab.dart';
import '../../../../shared/widgets/pull_to_refresh.dart';

// Aliases so _ServicesView/_ItemsView don't need to know real provider names.
final _checkoutServicesProvider = activeServicesProvider;
final _checkoutCategoriesProvider = serviceCategoriesListProvider;
final _checkoutProductsProvider = productsProvider;

// ─── Root screen ─────────────────────────────────────────────────────────────

class CheckoutScreen extends HookConsumerWidget {
  const CheckoutScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = useState(0); // 0=Keypad 1=Calendar 2=Services 3=Items

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
                2 => _ServicesView(),
                _ => _ItemsView(),
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
          bottom: BorderSide(color: AppColors.divider, width: 0.5),
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
          const SizedBox(width: 6),
          Expanded(
            child: _SegTab(
              label: 'Items',
              active: selected == 3,
              onTap: () => onChanged(3),
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
          color: active ? Colors.black : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: active ? Colors.white : AppColors.textSecondary,
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
    final cart = ref.watch(activeCartProvider);

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
                'Rs ${display.value}',
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
      // A swipe-down or backdrop tap must not be able to dismiss this sheet
      // mid-payment — ReviewSaleSheet has its own explicit close buttons for
      // normal dismissal, and additionally blocks the system back gesture
      // specifically while a payment is in flight (see its PopScope).
      isDismissible: false,
      enableDrag: false,
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
          Icon(Icons.add, size: 14, color: AppColors.textSecondary),
          SizedBox(width: 4),
          Text(
            'Note',
            style: TextStyle(
              color: AppColors.textSecondary,
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
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
              color: AppColors.divider,
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
                        ref.read(activeCartNotifierProvider).setNotes(ctrl.text);
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
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: ctrl,
                  maxLines: 3,
                  maxLength: 500,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppColors.divider),
                    ),
                    contentPadding: EdgeInsets.all(12),
                    counterStyle: TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Quick add',
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
                              color: AppColors.surfaceVariant,
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
          color: enabled ? Colors.black : AppColors.border,
          borderRadius: BorderRadius.circular(26),
        ),
        child: Center(
          child: Text(
            amount > 0
                ? 'Charge Rs ${amount.toStringAsFixed(2)}'
                : 'Charge Rs 0.00',
            style: TextStyle(
              color: enabled ? Colors.white : AppColors.textTertiary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
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
        // See _showReviewSale above for why these are false.
        isDismissible: false,
        enableDrag: false,
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
                style: const TextStyle(color: AppColors.textTertiary, fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Services View (3rd tab) ──────────────────────────────────────────────────

// Deliberately more vivid than the app's default restrained olive/grey
// palette — used only for this eye-catching service selection grid.
// Each (background, accent) pair is picked by hashing the category id so
// the same category always lands on the same color.
class _ServicesView extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(_checkoutServicesProvider);
    final catsAsync = ref.watch(_checkoutCategoriesProvider);
    final searchQ = useState('');
    final searchCtrl = useTextEditingController();
    final selectedCat = useState<String?>(null);
    final cart = ref.watch(activeCartProvider);

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
                color: AppColors.textTertiary,
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
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
        const Divider(height: 1, color: AppColors.surfaceVariant),
        // Service list
        Expanded(
          child: PullToRefresh(
            onRefresh: () => Future.wait([
              ref.refresh(_checkoutServicesProvider.future),
              ref.refresh(_checkoutCategoriesProvider.future),
            ]),
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
                    style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                  ),
                );
              }

              return GridView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1,
                ),
                itemCount: filtered.length,
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  final swatch = resolveServiceColor(s);
                  return _ServiceGridCard(
                    service: s,
                    bg: swatch.bg,
                    accent: swatch.accent,
                  );
                },
              );
            },
            ),
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

// ─── Items View (4th tab, sells retail products from inventory) ──────────────

class _ItemsView extends HookConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final productsAsync = ref.watch(_checkoutProductsProvider);
    final searchQ = useState('');
    final searchCtrl = useTextEditingController();
    final selectedCat = useState<String?>(null);
    final cart = ref.watch(activeCartProvider);

    return Column(
      children: [
        // Search
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: TextField(
            controller: searchCtrl,
            onChanged: (v) => searchQ.value = v,
            decoration: InputDecoration(
              hintText: 'Search items',
              hintStyle: const TextStyle(
                color: AppColors.textTertiary,
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.search,
                size: 18,
                color: AppColors.textTertiary,
              ),
              filled: true,
              fillColor: AppColors.surfaceVariant,
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(10),
              ),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        Expanded(
          child: PullToRefresh(
            onRefresh: () => ref.refresh(_checkoutProductsProvider.future),
            child: productsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (products) {
              final categories = (products.map((p) => p.category).whereType<String>().toSet().toList()..sort());

              final filtered = products.where((p) {
                final matchCat = selectedCat.value == null || p.category == selectedCat.value;
                final matchSearch =
                    searchQ.value.isEmpty ||
                    p.name.toLowerCase().contains(searchQ.value.toLowerCase());
                return matchCat && matchSearch;
              }).toList();

              return Column(
                children: [
                  if (categories.isNotEmpty)
                    SizedBox(
                      height: 44,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        children: [
                          _CatChip(
                            label: 'All',
                            selected: selectedCat.value == null,
                            onTap: () => selectedCat.value = null,
                          ),
                          ...categories.map(
                            (c) => _CatChip(
                              label: c,
                              selected: selectedCat.value == c,
                              onTap: () => selectedCat.value = c,
                            ),
                          ),
                        ],
                      ),
                    ),
                  if (categories.isNotEmpty)
                    const Divider(height: 1, color: AppColors.surfaceVariant),
                  Expanded(
                    child: filtered.isEmpty
                        ? const Center(
                            child: Text(
                              'No items found',
                              style: TextStyle(color: AppColors.textTertiary, fontSize: 14),
                            ),
                          )
                        : GridView.builder(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 3,
                              crossAxisSpacing: 10,
                              mainAxisSpacing: 10,
                              childAspectRatio: 1,
                            ),
                            itemCount: filtered.length,
                            itemBuilder: (_, i) {
                              final p = filtered[i];
                              // Products have no owner-chosen color (only
                              // services do) — always the deterministic
                              // auto-assigned swatch.
                              final swatch = autoServiceColorFor(p.category ?? p.id);
                              return _ProductGridCard(
                                product: p,
                                bg: swatch.bg,
                                accent: swatch.accent,
                              );
                            },
                          ),
                  ),
                ],
              );
            },
            ),
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
          color: selected ? Colors.black : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

class _ServiceGridCard extends ConsumerWidget {
  const _ServiceGridCard({
    required this.service,
    required this.bg,
    required this.accent,
  });
  final ServiceModel service;
  final Color bg;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(activeCartProvider);
    final matching = cart.items.where((i) => i.service?.id == service.id).toList();
    final inCartCount = matching.length;
    final inCart = inCartCount > 0;

    void showToast(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    void addOne() {
      HapticFeedback.selectionClick();
      ref.read(activeCartNotifierProvider).addService(service);
      showToast('${service.name} added');
    }

    void removeOne() {
      HapticFeedback.selectionClick();
      ref.read(activeCartNotifierProvider).removeItem(matching.last.id);
      showToast('${service.name} removed');
    }

    return GestureDetector(
      // Tapping the whole card always adds another instance — this is how
      // you add the same service multiple times. Removing one uses the
      // distinct badge below so it never conflicts with adding more.
      onTap: addOne,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
          border: inCart ? Border.all(color: accent, width: 2) : null,
        ),
        child: Stack(
          children: [
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      service.name,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Rs ${service.price.toStringAsFixed(0)}',
                      style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (inCart)
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  onTap: removeOne,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                    decoration: BoxDecoration(
                      color: accent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$inCartCount',
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 2),
                        // Minus, not a checkmark — this pill is the remove
                        // control (tap the card body to add instead), and a
                        // checkmark read as "added" rather than "tap to
                        // remove one".
                        const Icon(Icons.remove_rounded,
                            size: 12, color: Colors.white),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductGridCard extends ConsumerWidget {
  const _ProductGridCard({
    required this.product,
    required this.bg,
    required this.accent,
  });
  final ProductModel product;
  final Color bg;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(activeCartProvider);
    final matching = cart.items.where((i) => i.product?.id == product.id).toList();
    final inCartCount = matching.length;
    final inCart = inCartCount > 0;
    final outOfStock = product.stock - inCartCount <= 0;

    void showToast(String message) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(milliseconds: 1200),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black,
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
    }

    void addOne() {
      if (outOfStock) {
        showToast('${product.name} is out of stock');
        return;
      }
      HapticFeedback.selectionClick();
      ref.read(activeCartNotifierProvider).addProduct(product);
      showToast('${product.name} added');
    }

    void removeOne() {
      HapticFeedback.selectionClick();
      ref.read(activeCartNotifierProvider).removeItem(matching.last.id);
      showToast('${product.name} removed');
    }

    return GestureDetector(
      onTap: addOne,
      child: Opacity(
        opacity: outOfStock ? 0.45 : 1,
        child: Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(18),
            border: inCart ? Border.all(color: accent, width: 2) : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        product.name,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                          height: 1.2,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        outOfStock
                            ? 'Out of stock'
                            : 'Rs ${product.price.toStringAsFixed(0)}',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: outOfStock
                              ? AppColors.textTertiary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (inCart)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: removeOne,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 3),
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$inCartCount',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.remove_rounded,
                              size: 12, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
