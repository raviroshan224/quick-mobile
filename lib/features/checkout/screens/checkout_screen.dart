import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../customers/providers/customers_provider.dart';
import '../../customers/widgets/customer_picker_sheet.dart';
import '../../discounts/models/discount_model.dart';
import '../../discounts/providers/discounts_provider.dart';
import '../../discounts/widgets/discount_picker_sheet.dart';
import '../../services/models/service_model.dart';
import '../../services/providers/services_provider.dart';

final _amountCentsProvider = StateProvider<int>((ref) => 0);
final checkoutServicesProvider = StateProvider<List<Service>>((ref) => []);

class CheckoutScreen extends ConsumerStatefulWidget {
  const CheckoutScreen({super.key});

  @override
  ConsumerState<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends ConsumerState<CheckoutScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _onKey(String key) {
    final current = ref.read(_amountCentsProvider);
    if (key == 'C') {
      ref.read(_amountCentsProvider.notifier).state = 0;
    } else if (key == '+') {
      // TODO: add item to cart
    } else {
      final next = current * 10 + int.parse(key);
      if (next <= 9999999) {
        ref.read(_amountCentsProvider.notifier).state = next;
      }
    }
  }

  static String _formatRupees(double rupees) {
    if (rupees == rupees.truncateToDouble()) return 'Rs ${rupees.toInt()}';
    return 'Rs ${rupees.toStringAsFixed(2)}';
  }

  @override
  Widget build(BuildContext context) {
    final cents = ref.watch(_amountCentsProvider);
    final cartServices = ref.watch(checkoutServicesProvider);

    final servicesTotal = cartServices.fold(0.0, (sum, s) => sum + s.price);
    final subtotal = servicesTotal > 0 ? servicesTotal : cents / 100.0;

    final applied = ref.watch(checkoutDiscountProvider);
    final discount = applied != null ? applied.apply(subtotal) : 0.0;
    final total = (subtotal - discount).clamp(0.0, double.infinity);

    final subtotalStr = _formatRupees(subtotal);
    final chargeLabel =
        subtotal == 0 ? 'Charge' : 'Charge ${_formatRupees(total)}';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _SegmentedTabBar(controller: _tabController),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _KeypadTab(
                    subtotalStr: subtotalStr,
                    chargeLabel: chargeLabel,
                    onKey: _onKey,
                  ),
                  _LibraryTab(chargeLabel: chargeLabel),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Segmented tab bar ─────────────────────────────────────────────────────────

class _SegmentedTabBar extends StatelessWidget {
  final TabController controller;
  const _SegmentedTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      height: 36,
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(9)),
      child: TabBar(
        controller: controller,
        labelColor: AppColors.textPrimary,
        unselectedLabelColor: AppColors.textSecondary,
        dividerColor: Colors.transparent,
        indicator: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(7),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 4,
                offset: const Offset(0, 1))
          ],
        ),
        indicatorSize: TabBarIndicatorSize.tab,
        indicatorPadding: const EdgeInsets.all(3),
        labelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle:
            const TextStyle(fontSize: 14, fontWeight: FontWeight.w400),
        tabs: const [Tab(text: 'Keypad'), Tab(text: 'Library')],
      ),
    );
  }
}

// ── Keypad tab ────────────────────────────────────────────────────────────────

class _KeypadTab extends ConsumerWidget {
  final String subtotalStr;
  final String chargeLabel;
  final void Function(String) onKey;

  const _KeypadTab({
    required this.subtotalStr,
    required this.chargeLabel,
    required this.onKey,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applied = ref.watch(checkoutDiscountProvider);

    return Column(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                subtotalStr,
                style: const TextStyle(
                    fontSize: 52,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                    letterSpacing: -1),
              ),
              if (applied != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: _DiscountBadge(
                    discount: applied,
                    onRemove: () =>
                        ref.read(checkoutDiscountProvider.notifier).state =
                            null,
                  ),
                ),
              if (applied == null) const SizedBox(height: 4),
              TextButton.icon(
                onPressed: () => _showNoteSheet(context),
                icon: const Icon(Icons.add,
                    size: 16, color: AppColors.textSecondary),
                label: const Text('Note',
                    style: TextStyle(
                        fontSize: 14, color: AppColors.textSecondary)),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: _Keypad(onKey: onKey),
              ),
            ],
          ),
        ),
        _ChargeButton(label: chargeLabel),
      ],
    );
  }

  void _showNoteSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => const _NoteSheet(),
    );
  }
}

class _Keypad extends StatelessWidget {
  final void Function(String) onKey;
  const _Keypad({required this.onKey});

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['C', '0', '+'],
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: _rows.map((row) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: row.map((k) {
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: _Key(label: k, onTap: () => onKey(k)),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }
}

class _Key extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _Key({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.keypadKey,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 64,
          child: Center(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w400,
                    color: AppColors.textPrimary)),
          ),
        ),
      ),
    );
  }
}

// ── Library tab ───────────────────────────────────────────────────────────────

class _LibraryTab extends ConsumerStatefulWidget {
  final String chargeLabel;
  const _LibraryTab({required this.chargeLabel});

  @override
  ConsumerState<_LibraryTab> createState() => _LibraryTabState();
}

class _LibraryTabState extends ConsumerState<_LibraryTab>
    with SingleTickerProviderStateMixin {
  late final List<String> _categories;
  late final TabController _categoryController;

  @override
  void initState() {
    super.initState();
    final services = ref.read(servicesProvider);
    final active = services.where((s) => s.isActive);
    final usedCats = active.map((s) => s.category).toSet();
    _categories = serviceCategories
        .where((c) => c == 'All' || usedCats.contains(c))
        .toList();
    _categoryController =
        TabController(length: _categories.length, vsync: this);
  }

  @override
  void dispose() {
    _categoryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final applied = ref.watch(checkoutDiscountProvider);
    final customer = ref.watch(checkoutCustomerProvider);
    final cartServices = ref.watch(checkoutServicesProvider);
    final services = ref.watch(servicesProvider);
    final active = services.where((s) => s.isActive).toList();

    return Column(
      children: [
        // Customer + Discount action row
        Container(
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _LibraryAction(
                  icon: Icons.person_outline,
                  label: customer?.name ?? 'Customer',
                  isActive: customer != null,
                  activeColor: AppColors.accent,
                  onTap: () => CustomerPickerSheet.show(context),
                  onRemove: customer != null
                      ? () => ref
                          .read(checkoutCustomerProvider.notifier)
                          .state = null
                      : null,
                ),
              ),
              Container(width: 1, height: 44, color: AppColors.divider),
              Expanded(
                child: _LibraryAction(
                  icon: Icons.local_offer_outlined,
                  label: applied?.name ?? 'Discount',
                  isActive: applied != null,
                  activeColor: AppColors.success,
                  onTap: () => DiscountPickerSheet.show(context),
                  onRemove: applied != null
                      ? () => ref
                          .read(checkoutDiscountProvider.notifier)
                          .state = null
                      : null,
                ),
              ),
            ],
          ),
        ),
        // Category tabs
        TabBar(
          controller: _categoryController,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          labelColor: AppColors.textPrimary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          indicatorSize: TabBarIndicatorSize.label,
          dividerColor: AppColors.divider,
          labelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          unselectedLabelStyle:
              const TextStyle(fontSize: 13, fontWeight: FontWeight.w400),
          tabs: _categories.map((c) => Tab(text: c)).toList(),
        ),
        // Services per category
        Expanded(
          child: TabBarView(
            controller: _categoryController,
            children: _categories.map((cat) {
              final list = cat == 'All'
                  ? active
                  : active.where((s) => s.category == cat).toList();
              return ListView.separated(
                itemCount: list.length,
                separatorBuilder: (_, _) =>
                    const Divider(height: 1, indent: 16),
                itemBuilder: (_, i) {
                  final s = list[i];
                  final inCart = cartServices.any((c) => c.id == s.id);
                  return _ServiceTile(
                    service: s,
                    inCart: inCart,
                    onTap: () {
                      final notifier =
                          ref.read(checkoutServicesProvider.notifier);
                      if (inCart) {
                        notifier.state = [
                          ...cartServices.where((c) => c.id != s.id)
                        ];
                      } else {
                        notifier.state = [...cartServices, s];
                      }
                    },
                  );
                },
              );
            }).toList(),
          ),
        ),
        if (cartServices.isNotEmpty) _CartStrip(services: cartServices),
        _ChargeButton(label: widget.chargeLabel),
      ],
    );
  }
}

// ── Library action button (Customer / Discount) ───────────────────────────────

class _LibraryAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final Color activeColor;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  const _LibraryAction({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.activeColor,
    required this.onTap,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? activeColor : AppColors.textSecondary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight:
                      isActive ? FontWeight.w500 : FontWeight.w400,
                  color: color,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (onRemove != null)
              GestureDetector(
                onTap: onRemove,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4),
                  child: Icon(Icons.close, size: 14, color: color),
                ),
              )
            else
              Icon(Icons.chevron_right,
                  size: 16, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Service tile ──────────────────────────────────────────────────────────────

class _ServiceTile extends StatelessWidget {
  final Service service;
  final bool inCart;
  final VoidCallback onTap;

  const _ServiceTile({
    required this.service,
    required this.inCart,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${service.durationLabel} · Rs ${service.price.toInt()}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: inCart ? AppColors.primary : AppColors.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                inCart ? Icons.check : Icons.add,
                size: 15,
                color: inCart ? Colors.white : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Cart strip (selected services summary) ────────────────────────────────────

class _CartStrip extends ConsumerWidget {
  final List<Service> services;
  const _CartStrip({required this.services});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = services.fold(0.0, (sum, s) => sum + s.price);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 20,
            height: 20,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                '${services.length}',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              services.map((s) => s.name).join(', '),
              style: const TextStyle(fontSize: 13, color: AppColors.textPrimary),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'Rs ${total.toInt()}',
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            onTap: () =>
                ref.read(checkoutServicesProvider.notifier).state = [],
            child: const Icon(Icons.close,
                size: 16, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Discount badge (keypad tab) ───────────────────────────────────────────────

class _DiscountBadge extends StatelessWidget {
  final Discount discount;
  final VoidCallback onRemove;

  const _DiscountBadge({required this.discount, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onRemove,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppColors.success.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.local_offer, size: 13, color: AppColors.success),
            const SizedBox(width: 5),
            Text(
              '${discount.name} applied',
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.success),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.close, size: 13, color: AppColors.success),
          ],
        ),
      ),
    );
  }
}

// ── Charge button ─────────────────────────────────────────────────────────────

class _ChargeButton extends StatelessWidget {
  final String label;
  const _ChargeButton({required this.label});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: () {},
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

// ── Note sheet ────────────────────────────────────────────────────────────────

class _NoteSheet extends StatefulWidget {
  const _NoteSheet();

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  final _ctrl = TextEditingController();
  static const _tags = ['tip', 'invoice', 'docent', 'sde', 'golduppp'];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
                const Expanded(
                    child: Center(
                        child: Text('Add Note',
                            style: TextStyle(
                                fontSize: 17, fontWeight: FontWeight.w600)))),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Save',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary)),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 8),
            const Text('Note',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            TextField(
                controller: _ctrl,
                maxLines: 3,
                decoration:
                    const InputDecoration(hintText: 'Add a note...')),
            const SizedBox(height: 12),
            const Text('Quick add',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: _tags
                  .map((t) => ActionChip(
                        label:
                            Text(t, style: const TextStyle(fontSize: 12)),
                        onPressed: () => setState(() => _ctrl.text += t),
                        backgroundColor: AppColors.surface,
                        side: BorderSide.none,
                        padding:
                            const EdgeInsets.symmetric(horizontal: 4),
                      ))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}
