import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/customers/data/mock_customers_repository.dart';
import '../../../../features/customers/domain/customer_models.dart';
import '../../../../features/pos/domain/pos_models.dart';
import '../../../../features/pos/presentation/providers/cart_provider.dart';
import '../../../../features/staff/data/mock_staff_repository.dart';
import '../../../../features/staff/domain/staff_models.dart';

enum _Step { pick, cash, qr, split, success }

// ─── Entry point ──────────────────────────────────────────────────────────────

class ReviewSaleSheet extends HookConsumerWidget {
  const ReviewSaleSheet({super.key, required this.keypadAmount});
  final double keypadAmount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final step = useState(_Step.pick);
    final method = useState(PaymentMethod.cash);
    final customer = useState<CustomerModel?>(null);
    final staff = useState<StaffModel?>(null);
    final cashInput = useState('0');

    useEffect(() {
      final user = ref.read(currentUserProvider);
      if (user != null && !user.isOwner) {
        MockStaffRepository().getAll().then((all) {
          final match = all.where((s) => s.userId == user.id).firstOrNull;
          if (match != null) staff.value = match;
        });
      }
      return null;
    }, const []);

    final cart = ref.watch(cartProvider);
    final total = cart.items.isEmpty ? keypadAmount : cart.total;
    final tendered = double.tryParse(cashInput.value) ?? 0;

    void done() {
      ref.read(cartProvider.notifier).clear();
      step.value = _Step.success;
    }

    void go(PaymentMethod m) {
      method.value = m;
      // Pre-fill so the page opens ready to confirm: cash=exact total, split=50/50
      cashInput.value = switch (m) {
        PaymentMethod.cash => total.toStringAsFixed(0),
        PaymentMethod.split => (total / 2).toStringAsFixed(0),
        _ => '0',
      };
      step.value = switch (m) {
        PaymentMethod.cash => _Step.cash,
        PaymentMethod.fonepay => _Step.qr,
        PaymentMethod.split => _Step.split,
      };
    }

    return Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: switch (step.value) {
        _Step.pick => _PickStep(
            total: total,
            cart: cart,
            customer: customer.value,
            onCustomerChanged: (c) => customer.value = c,
            staff: staff.value,
            onStaffChanged: (s) => staff.value = s,
            onPick: go,
            onClose: () => Navigator.pop(context),
          ),
        _Step.cash => _CashStep(
            total: total,
            cashInput: cashInput,
            tendered: tendered,
            onBack: () => step.value = _Step.pick,
            onConfirm: done,
          ),
        _Step.qr => _QRStep(
            total: total,
            customer: customer.value,
            onBack: () => step.value = _Step.pick,
            onConfirm: done,
          ),
        _Step.split => _SplitStep(
            total: total,
            cashInput: cashInput,
            onBack: () => step.value = _Step.pick,
            onConfirm: done,
          ),
        _Step.success => _SuccessStep(
            total: total,
            method: method.value,
            customer: customer.value,
            staff: staff.value,
            change: method.value == PaymentMethod.cash && tendered > total
                ? tendered - total
                : null,
            cashPaid: method.value == PaymentMethod.split ? tendered : null,
            fonepayPaid: method.value == PaymentMethod.split
                ? (total - tendered).clamp(0.0, total)
                : null,
            onNewSale: () => Navigator.pop(context),
          ),
      },
    );
  }
}

// ─── Shared helpers ───────────────────────────────────────────────────────────

String _applyKey(String cur, String k) {
  if (k == 'C') return '0';
  if (k == '.' && cur.contains('.')) return cur;
  if (cur == '0' && k != '.') return k;
  if (cur.contains('.') && cur.split('.')[1].length >= 2) return cur;
  return '$cur$k';
}

List<double> _quickAmounts(double total) {
  final s = {
    total,
    (total / 50).ceil() * 50.0,
    (total / 100).ceil() * 100.0,
    (total / 500).ceil() * 500.0,
  }.toList()..sort();
  return s;
}

class _Handle extends StatelessWidget {
  const _Handle();
  @override
  Widget build(BuildContext context) => Center(
        child: Container(
          width: 36,
          height: 4,
          margin: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2)),
        ),
      );
}

class _BigBtn extends StatelessWidget {
  const _BigBtn({required this.label, this.onTap, this.enabled = true,
      this.color, this.outlined = false});
  final String label;
  final VoidCallback? onTap;
  final bool enabled;
  final Color? color;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final bg = outlined
        ? Colors.white
        : (enabled ? (color ?? Colors.black) : const Color(0xFFD1D5DB));
    final fg = outlined
        ? Colors.black
        : (enabled ? Colors.white : const Color(0xFF9CA3AF));
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: Container(
          height: 52,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(26),
            border: outlined ? Border.all(color: const Color(0xFFE5E7EB)) : null,
          ),
          child: Center(
            child: Text(label,
                style: TextStyle(
                    color: fg,
                    fontSize: 16,
                    fontWeight: FontWeight.w600)),
          ),
        ),
      ),
    );
  }
}

class _BackHeader extends StatelessWidget {
  const _BackHeader({required this.title, required this.onBack, this.right});
  final String title;
  final VoidCallback onBack;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      const _Handle(),
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: Row(children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.black),
          ),
          const Spacer(),
          Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          const Spacer(),
          right ?? const SizedBox(width: 18),
        ]),
      ),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
    ]);
  }
}

// Numpad where each row expands to fill available height (no dead zone).
class _FlexNumpad extends StatelessWidget {
  const _FlexNumpad({required this.onKey});
  final ValueChanged<String> onKey;

  static const _rows = [
    ['1', '2', '3'],
    ['4', '5', '6'],
    ['7', '8', '9'],
    ['C', '0', '.'],
  ];

  @override
  Widget build(BuildContext context) => Column(
        children: _rows
            .map((row) => Expanded(
                  child: Row(
                    children: row
                        .map((k) => Expanded(
                              child: GestureDetector(
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  onKey(k);
                                },
                                child: Container(
                                  margin: const EdgeInsets.all(3),
                                  decoration: BoxDecoration(
                                    color: k == 'C'
                                        ? const Color(0xFFFEE2E2)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(k,
                                        style: TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.w400,
                                          color: k == 'C'
                                              ? const Color(0xFFDC2626)
                                              : Colors.black,
                                        )),
                                  ),
                                ),
                              ),
                            ))
                        .toList(),
                  ),
                ))
            .toList(),
      );
}

// ─── Step 1: Pick Payment Method ──────────────────────────────────────────────

class _PickStep extends HookConsumerWidget {
  const _PickStep({
    required this.total,
    required this.cart,
    required this.customer,
    required this.onCustomerChanged,
    required this.staff,
    required this.onStaffChanged,
    required this.onPick,
    required this.onClose,
  });
  final double total;
  final CartState cart;
  final CustomerModel? customer;
  final ValueChanged<CustomerModel?> onCustomerChanged;
  final StaffModel? staff;
  final ValueChanged<StaffModel?> onStaffChanged;
  final ValueChanged<PaymentMethod> onPick;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(children: [
      const _Handle(),
      // Total amount
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
        child: Row(children: [
          const Spacer(),
          Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Text('NPR ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.5)),
            if (cart.items.isNotEmpty)
              Text(
                  '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF9CA3AF))),
          ]),
          const Spacer(),
          GestureDetector(
            onTap: onClose,
            child: const Icon(Icons.close, size: 22, color: Color(0xFF9CA3AF)),
          ),
        ]),
      ),
      // Items summary (if any)
      if (cart.items.isNotEmpty) ...[
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFFF9FAFB),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: cart.items
                  .map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(children: [
                          Expanded(child: Text(item.name,
                              style: const TextStyle(fontSize: 13))),
                          Text('×${item.quantity}',
                              style: const TextStyle(
                                  fontSize: 13, color: Color(0xFF9CA3AF))),
                          const SizedBox(width: 12),
                          Text('NPR ${item.totalPrice.toStringAsFixed(0)}',
                              style: const TextStyle(fontSize: 13)),
                        ]),
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
      const SizedBox(height: 12),
      // Customer row
      _CustomerRow(
        customer: customer,
        onTap: () => _pickCustomer(context),
        onRemove: () => onCustomerChanged(null),
      ),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      // Staff row — owner can pick any staff; staff sees their own name locked
      _StaffRow(
        staff: staff,
        onTap: ref.read(currentUserProvider)?.isOwner == true
            ? () => _pickStaff(context)
            : null,
        onRemove: ref.read(currentUserProvider)?.isOwner == true
            ? () => onStaffChanged(null)
            : null,
      ),
      const Divider(height: 1, color: Color(0xFFE5E7EB)),
      const SizedBox(height: 12),
      // Payment method label
      const Padding(
        padding: EdgeInsets.only(left: 20, bottom: 8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Pay with',
              style: TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.4)),
        ),
      ),
      // 3 payment method rows
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(children: [
            _MethodRow(
              icon: Icons.payments_outlined,
              label: 'Cash',
              color: Colors.black,
              onTap: () => onPick(PaymentMethod.cash),
              showDivider: true,
            ),
            _MethodRow(
              icon: Icons.qr_code_rounded,
              label: 'Fonepay QR',
              color: const Color(0xFF6BBD44),
              onTap: () => onPick(PaymentMethod.fonepay),
              showDivider: true,
            ),
            _MethodRow(
              icon: Icons.call_split_rounded,
              label: 'Split Payment',
              color: const Color(0xFF6366F1),
              onTap: () => onPick(PaymentMethod.split),
              showDivider: false,
            ),
          ]),
        ),
      ),
    ]);
  }

  void _pickCustomer(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CustomerPicker(onSelected: onCustomerChanged),
    );
  }

  void _pickStaff(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _StaffPicker(onSelected: onStaffChanged),
    );
  }
}

class _MethodRow extends StatelessWidget {
  const _MethodRow({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    required this.showDivider,
  });
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: color),
            ),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w500)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded,
                size: 14, color: color.withValues(alpha: 0.6)),
          ]),
        ),
      ),
      if (showDivider)
        const Divider(height: 1, indent: 66, color: Color(0xFFF3F4F6)),
    ]);
  }
}

class _CustomerRow extends StatelessWidget {
  const _CustomerRow(
      {required this.customer, required this.onTap, required this.onRemove});
  final CustomerModel? customer;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    if (customer == null) {
      return GestureDetector(
        onTap: onTap,
        child: const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Icon(Icons.person_add_outlined,
                size: 18, color: Color(0xFF9CA3AF)),
            SizedBox(width: 10),
            Text('Add customer (optional)',
                style:
                    TextStyle(fontSize: 14, color: Color(0xFF9CA3AF))),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF3F4F6),
          child: Text(customer!.initials,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(customer!.fullName,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        GestureDetector(
          onTap: onRemove,
          child: const Icon(Icons.close,
              size: 16, color: Color(0xFF9CA3AF)),
        ),
      ]),
    );
  }
}

// ─── Staff Row ────────────────────────────────────────────────────────────────

class _StaffRow extends StatelessWidget {
  const _StaffRow({required this.staff, this.onTap, this.onRemove});
  final StaffModel? staff;
  final VoidCallback? onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    if (staff == null) {
      return GestureDetector(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: Row(children: [
            Icon(Icons.person_outlined,
                size: 18,
                color: onTap != null
                    ? const Color(0xFF9CA3AF)
                    : const Color(0xFFD1D5DB)),
            const SizedBox(width: 10),
            Text(
              onTap != null
                  ? 'Assign staff (optional)'
                  : 'No staff assigned',
              style: TextStyle(
                  fontSize: 14,
                  color: onTap != null
                      ? const Color(0xFF9CA3AF)
                      : const Color(0xFFD1D5DB)),
            ),
          ]),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(children: [
        CircleAvatar(
          radius: 16,
          backgroundColor: const Color(0xFFF3F4F6),
          child: Text(staff!.initials,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.black)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(staff!.fullName,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
        ),
        if (onRemove != null)
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close,
                size: 16, color: Color(0xFF9CA3AF)),
          ),
      ]),
    );
  }
}

// ─── Customer Picker ──────────────────────────────────────────────────────────

final _cpProvider = FutureProvider<List<CustomerModel>>(
  (_) => MockCustomersRepository().getAll(),
);

final _allStaffProvider = FutureProvider<List<StaffModel>>(
  (_) async => MockStaffRepository().getAll(activeOnly: true),
);

class _CustomerPicker extends HookConsumerWidget {
  const _CustomerPicker({required this.onSelected});
  final ValueChanged<CustomerModel?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(_cpProvider);
    final q = useState('');
    final ctrl = useTextEditingController();

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const _Handle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            const Text('Add Customer',
                style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(
                      fontSize: 14, color: Color(0xFF6B7280))),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: ctrl,
            autofocus: true,
            onChanged: (v) => q.value = v,
            decoration: InputDecoration(
              hintText: 'Search name or phone…',
              hintStyle: const TextStyle(
                  color: Color(0xFF9CA3AF), fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(10)),
              contentPadding:
                  const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: all.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              final filtered = q.value.isEmpty
                  ? list
                  : list.where((c) =>
                      c.fullName
                          .toLowerCase()
                          .contains(q.value.toLowerCase()) ||
                      (c.phone ?? '').contains(q.value)).toList();

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length + 1,
                separatorBuilder: (_, _) => const Divider(
                    height: 1, indent: 66, color: Color(0xFFF3F4F6)),
                itemBuilder: (_, i) {
                  if (i == filtered.length) {
                    return ListTile(
                      leading: Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Icon(Icons.person_outline_rounded,
                            size: 20, color: Color(0xFF9CA3AF)),
                      ),
                      title: const Text('Continue as Guest',
                          style: TextStyle(
                              color: Color(0xFF6B7280), fontSize: 14)),
                      onTap: () {
                        onSelected(null);
                        Navigator.pop(context);
                      },
                    );
                  }
                  final c = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF3F4F6),
                      child: Text(c.initials,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              fontSize: 14)),
                    ),
                    title: Text(c.fullName,
                        style: const TextStyle(fontSize: 15)),
                    subtitle: c.phone != null
                        ? Text(c.phone!,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF)))
                        : null,
                    trailing: Text('${c.visitCount} visits',
                        style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF))),
                    onTap: () {
                      onSelected(c);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── Staff Picker ─────────────────────────────────────────────────────────────

class _StaffPicker extends HookConsumerWidget {
  const _StaffPicker({required this.onSelected});
  final ValueChanged<StaffModel?> onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(_allStaffProvider);
    final q = useState('');
    final ctrl = useTextEditingController();

    return Container(
      height: MediaQuery.of(context).size.height * 0.60,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        const _Handle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
          child: Row(children: [
            const Text('Assign Staff',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const Spacer(),
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: const Text('Cancel',
                  style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: TextField(
            controller: ctrl,
            autofocus: true,
            onChanged: (v) => q.value = v,
            decoration: InputDecoration(
              hintText: 'Search staff…',
              hintStyle:
                  const TextStyle(color: Color(0xFF9CA3AF), fontSize: 14),
              prefixIcon: const Icon(Icons.search,
                  size: 18, color: Color(0xFF9CA3AF)),
              filled: true,
              fillColor: const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(vertical: 10),
            ),
          ),
        ),
        const SizedBox(height: 4),
        const Divider(height: 1, color: Color(0xFFE5E7EB)),
        Expanded(
          child: all.when(
            loading: () =>
                const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              final filtered = q.value.isEmpty
                  ? list
                  : list
                      .where((s) => s.fullName
                          .toLowerCase()
                          .contains(q.value.toLowerCase()))
                      .toList();

              return ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: filtered.length,
                separatorBuilder: (_, _) => const Divider(
                    height: 1, indent: 66, color: Color(0xFFF3F4F6)),
                itemBuilder: (_, i) {
                  final s = filtered[i];
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: const Color(0xFFF3F4F6),
                      child: Text(s.initials,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              color: Colors.black,
                              fontSize: 14)),
                    ),
                    title: Text(s.fullName,
                        style: const TextStyle(fontSize: 15)),
                    subtitle: s.specialties.isNotEmpty
                        ? Text(s.specialties.take(2).join(', '),
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF9CA3AF)))
                        : null,
                    onTap: () {
                      onSelected(s);
                      Navigator.pop(context);
                    },
                  );
                },
              );
            },
          ),
        ),
      ]),
    );
  }
}

// ─── Step 2a: Cash ────────────────────────────────────────────────────────────

class _CashStep extends HookWidget {
  const _CashStep({
    required this.total,
    required this.cashInput,
    required this.tendered,
    required this.onBack,
    required this.onConfirm,
  });
  final double total;
  final ValueNotifier<String> cashInput;
  final double tendered;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final t = double.tryParse(cashInput.value) ?? 0;
    final ok = t >= total;
    final change = t - total;

    return Column(children: [
      _BackHeader(title: 'Cash Payment', onBack: onBack),
      // Big amount display
      Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        child: Column(children: [
          const Text('Tendered',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF), letterSpacing: 0.3)),
          const SizedBox(height: 4),
          SizedBox(
            width: double.infinity,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 120),
                child: Text(
                  'NPR ${cashInput.value}',
                  key: ValueKey(cashInput.value),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -1,
                    color: ok ? const Color(0xFF16A34A) : Colors.black,
                  ),
                ),
              ),
            ),
          ),
          // Change / short line
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: ok && change > 0
                ? Text(
                    key: const ValueKey('ch'),
                    'Change: NPR ${change.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w500),
                  )
                : !ok && t > 0
                    ? Text(
                        key: const ValueKey('sh'),
                        'Short: NPR ${(-change).toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 14,
                            color: Color(0xFFDC2626),
                            fontWeight: FontWeight.w500),
                      )
                    : const SizedBox(key: ValueKey('none'), height: 18),
          ),
        ]),
      ),
      // Quick amounts
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: _quickAmounts(total).map((amt) {
              final isSelected = cashInput.value == amt.toStringAsFixed(0);
              final lbl = amt == total ? 'Exact' : 'NPR ${amt.toStringAsFixed(0)}';
              return _Chip(
                label: lbl,
                selected: isSelected,
                onTap: () => cashInput.value = amt.toStringAsFixed(0),
              );
            }).toList(),
          ),
        ),
      ),
      // Expanding numpad
      Expanded(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: _FlexNumpad(
              onKey: (k) => cashInput.value = _applyKey(cashInput.value, k)),
        ),
      ),
      _BigBtn(
        label: ok
            ? (change > 0 ? 'Confirm — Change NPR ${change.toStringAsFixed(2)}' : 'Confirm Payment')
            : 'Enter Amount',
        onTap: onConfirm,
        enabled: ok,
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.label, required this.onTap, this.selected = false});
  final String label;
  final VoidCallback onTap;
  final bool selected;
  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? const Color(0xFF16A34A) : Colors.black,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(label,
              style: const TextStyle(
                  fontSize: 13,
                  color: Colors.white,
                  fontWeight: FontWeight.w500)),
        ),
      );
}

// ─── Step 2b: Fonepay QR ──────────────────────────────────────────────────────

class _QRStep extends HookWidget {
  const _QRStep({
    required this.total,
    required this.customer,
    required this.onBack,
    required this.onConfirm,
  });
  final double total;
  final CustomerModel? customer;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final pulse = useAnimationController(
        duration: const Duration(milliseconds: 1000))
      ..repeat(reverse: true);

    return Column(children: [
      _BackHeader(title: 'Fonepay QR', onBack: onBack),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(children: [
            const SizedBox(height: 20),
            // QR card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: const Color(0xFF6BBD44).withValues(alpha: 0.25)),
              ),
              child: Column(children: [
                // Header
                Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  Container(
                    width: 8, height: 8,
                    decoration: const BoxDecoration(
                        color: Color(0xFF6BBD44), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  const Text('FONEPAY',
                      style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF6BBD44),
                          letterSpacing: 1.5)),
                ]),
                const SizedBox(height: 20),
                // QR code box
                Container(
                  width: 190,
                  height: 190,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: const Color(0xFFE5E7EB), width: 2),
                    boxShadow: [
                      BoxShadow(
                          color: Colors.black.withValues(alpha: 0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 3)),
                    ],
                  ),
                  child: const Icon(Icons.qr_code_2_rounded,
                      size: 150, color: Colors.black87),
                ),
                const SizedBox(height: 20),
                Text('NPR ${total.toStringAsFixed(2)}',
                    style: const TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF6BBD44),
                        letterSpacing: -0.5)),
                if (customer != null) ...[
                  const SizedBox(height: 4),
                  Text(customer!.fullName,
                      style: const TextStyle(
                          fontSize: 13, color: Color(0xFF6B7280))),
                ],
              ]),
            ),
            const SizedBox(height: 24),
            // Waiting pulse
            AnimatedBuilder(
              animation: pulse,
              builder: (_, child) =>
                  Opacity(opacity: 0.4 + 0.6 * pulse.value, child: child),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                SizedBox(
                  width: 14, height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: const Color(0xFF6BBD44)),
                ),
                const SizedBox(width: 10),
                const Text('Waiting for payment…',
                    style: TextStyle(
                        fontSize: 13, color: Color(0xFF6B7280))),
              ]),
            ),
            const SizedBox(height: 20),
            // Steps
            ...[
              ('1', 'Open Fonepay app'),
              ('2', 'Tap "Scan QR" and point camera here'),
              ('3', 'Confirm NPR ${total.toStringAsFixed(2)} in the app'),
            ].map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: [
                    Container(
                      width: 20, height: 20,
                      decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          shape: BoxShape.circle),
                      child: Center(
                          child: Text(s.$1,
                              style: const TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w700))),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(s.$2,
                            style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF6B7280)))),
                  ]),
                )),
          ]),
        ),
      ),
      _BigBtn(
        label: '✓  Payment Received',
        onTap: onConfirm,
        color: const Color(0xFF6BBD44),
      ),
      const SizedBox(height: 16),
    ]);
  }
}

// ─── Step 2c: Split ───────────────────────────────────────────────────────────

class _SplitStep extends HookWidget {
  const _SplitStep({
    required this.total,
    required this.cashInput,
    required this.onBack,
    required this.onConfirm,
  });
  final double total;
  final ValueNotifier<String> cashInput;
  final VoidCallback onBack;
  final VoidCallback onConfirm;

  @override
  Widget build(BuildContext context) {
    final cash = double.tryParse(cashInput.value) ?? 0;
    final fonepay = (total - cash).clamp(0.0, total);
    final ok = cash > 0 && fonepay > 0 && cash <= total;

    return Column(children: [
      _BackHeader(
        title: 'Split Payment',
        onBack: onBack,
        right: Text('NPR ${total.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w600)),
      ),
      Expanded(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(children: [
            const SizedBox(height: 16),
            // Cash input tile
            _SplitTile(
              icon: Icons.payments_outlined,
              label: 'Cash',
              valueText: cashInput.value == '0'
                  ? '—'
                  : 'NPR ${cashInput.value}',
              isActive: true,
              color: Colors.black,
            ),
            const SizedBox(height: 8),
            // Fonepay tile (auto)
            _SplitTile(
              icon: Icons.qr_code_rounded,
              label: 'Fonepay QR',
              valueText: cash > 0
                  ? 'NPR ${fonepay.toStringAsFixed(2)}'
                  : '—',
              isActive: false,
              color: const Color(0xFF6BBD44),
              note: 'Auto-calculated',
            ),
            if (cash > total)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 14, color: Color(0xFFDC2626)),
                  SizedBox(width: 6),
                  Text('Exceeds total',
                      style: TextStyle(
                          fontSize: 12, color: Color(0xFFDC2626))),
                ]),
              ),
            const SizedBox(height: 10),
            // Quick split chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(children: [
                _Chip(
                    label: '50 / 50',
                    onTap: () => cashInput.value =
                        (total / 2).toStringAsFixed(0)),
                _Chip(
                    label: '25 cash',
                    onTap: () => cashInput.value =
                        (total * 0.25).toStringAsFixed(0)),
                _Chip(
                    label: '75 cash',
                    onTap: () => cashInput.value =
                        (total * 0.75).toStringAsFixed(0)),
              ]),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _FlexNumpad(
                  onKey: (k) => cashInput.value =
                      _applyKey(cashInput.value, k)),
            ),
          ]),
        ),
      ),
      _BigBtn(
        label: ok ? 'Process Split Payment' : 'Enter Cash Amount',
        onTap: onConfirm,
        enabled: ok,
      ),
      const SizedBox(height: 16),
    ]);
  }
}

class _SplitTile extends StatelessWidget {
  const _SplitTile({
    required this.icon,
    required this.label,
    required this.valueText,
    required this.isActive,
    required this.color,
    this.note,
  });
  final IconData icon;
  final String label;
  final String valueText;
  final bool isActive;
  final Color color;
  final String? note;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(
            horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isActive ? Colors.white : const Color(0xFFF9FAFB),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: isActive ? color : const Color(0xFFE5E7EB),
              width: isActive ? 1.5 : 1),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280))),
                if (note != null)
                  Text(note!,
                      style: const TextStyle(
                          fontSize: 11,
                          color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Text(valueText,
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isActive ? Colors.black : const Color(0xFF6B7280))),
        ]),
      );
}

// ─── Step 3: Success ──────────────────────────────────────────────────────────

class _SuccessStep extends StatelessWidget {
  const _SuccessStep({
    required this.total,
    required this.method,
    required this.customer,
    required this.staff,
    required this.change,
    required this.cashPaid,
    required this.fonepayPaid,
    required this.onNewSale,
  });
  final double total;
  final PaymentMethod method;
  final CustomerModel? customer;
  final StaffModel? staff;
  final double? change;
  final double? cashPaid;
  final double? fonepayPaid;
  final VoidCallback onNewSale;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            Container(
              width: 80, height: 80,
              decoration: const BoxDecoration(
                  color: Color(0xFFDCFCE7), shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  size: 44, color: Color(0xFF16A34A)),
            ),
            const SizedBox(height: 16),
            const Text('Payment Successful',
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('NPR ${total.toStringAsFixed(2)}',
                style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w200,
                    letterSpacing: -1)),
            const Spacer(),
            // Receipt card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(children: [
                _Row('Method', switch (method) {
                  PaymentMethod.cash => 'Cash',
                  PaymentMethod.fonepay => 'Fonepay QR',
                  PaymentMethod.split => 'Split',
                }),
                if (customer != null) ...[
                  const SizedBox(height: 10),
                  _Row('Customer', customer!.fullName),
                ],
                if (staff != null) ...[
                  const SizedBox(height: 10),
                  _Row('Staff', staff!.fullName),
                ],
                if (method == PaymentMethod.split &&
                    cashPaid != null &&
                    fonepayPaid != null) ...[
                  const SizedBox(height: 10),
                  _Row('Cash',
                      'NPR ${cashPaid!.toStringAsFixed(2)}'),
                  const SizedBox(height: 6),
                  _Row('Fonepay',
                      'NPR ${fonepayPaid!.toStringAsFixed(2)}'),
                ],
                if (change != null && change! > 0) ...[
                  const Divider(height: 20, color: Color(0xFFE5E7EB)),
                  Row(children: [
                    const Text('Change Due',
                        style: TextStyle(
                            fontSize: 15,
                            color: Color(0xFF16A34A),
                            fontWeight: FontWeight.w600)),
                    const Spacer(),
                    Text('NPR ${change!.toStringAsFixed(2)}',
                        style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF16A34A))),
                  ]),
                ],
              ]),
            ),
            const Spacer(),
            // Print Receipt
            _BigBtn(
              label: 'Print Receipt',
              onTap: () {},
              outlined: true,
            ),
            const SizedBox(height: 8),
            _BigBtn(label: 'New Sale', onTap: onNewSale),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Row(children: [
        Text(label,
            style: const TextStyle(
                fontSize: 14, color: Color(0xFF6B7280))),
        const Spacer(),
        Text(value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w500)),
      ]);
}
