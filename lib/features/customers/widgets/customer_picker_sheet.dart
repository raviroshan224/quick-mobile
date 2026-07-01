import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/customer_model.dart';
import '../providers/customers_provider.dart';
import '../screens/customers_screen.dart' show CustomerAvatar;

/// Bottom sheet shown in the checkout Library tab.
/// Staff search by name or phone, select an existing customer,
/// or quick-create one — all without leaving checkout.
class CustomerPickerSheet extends ConsumerStatefulWidget {
  const CustomerPickerSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => const CustomerPickerSheet(),
    );
  }

  @override
  ConsumerState<CustomerPickerSheet> createState() =>
      _CustomerPickerSheetState();
}

class _CustomerPickerSheetState extends ConsumerState<CustomerPickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(customersProvider);
    final attached = ref.watch(checkoutCustomerProvider);

    // Filter list — show recent 5 when empty, filtered when typing
    final List<Customer> list;
    if (_query.isEmpty) {
      final sorted = [...all]
        ..sort((a, b) {
          if (a.lastVisitDate == null) return 1;
          if (b.lastVisitDate == null) return -1;
          return b.lastVisitDate!.compareTo(a.lastVisitDate!);
        });
      list = sorted.take(5).toList();
    } else {
      list = all.where((c) {
        return c.name.toLowerCase().contains(_query) ||
            c.phone.contains(_query);
      }).toList();
    }

    // Check if query looks like a phone number or a new name
    final looksLikePhone = RegExp(r'^\d+$').hasMatch(_query);
    final noExactMatch =
        _query.isNotEmpty &&
        !all.any((c) => c.name.toLowerCase() == _query || c.phone == _query);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────────────
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 4, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text(
                    'Add Customer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                if (attached != null)
                  TextButton(
                    onPressed: () {
                      ref.read(checkoutCustomerProvider.notifier).state = null;
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Remove',
                      style: TextStyle(
                        color: AppColors.refund,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
          ),

          // ── Attached banner ──────────────────────────────────────────────
          if (attached != null)
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppColors.accent.withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  CustomerAvatar(name: attached.name, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          attached.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          attached.phone,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.check_circle,
                    size: 18,
                    color: AppColors.accent,
                  ),
                ],
              ),
            ),

          // ── Search ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: attached == null,
              keyboardType: TextInputType.text,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              decoration: InputDecoration(
                hintText: 'Name or phone number…',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 20,
                  color: AppColors.textTertiary,
                ),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: () {
                          _searchCtrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
              ),
            ),
          ),

          if (_query.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'RECENT',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.8,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),

          const Divider(height: 1),

          // ── Customer list ─────────────────────────────────────────────────
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.38,
            ),
            child: list.isEmpty && _query.isNotEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'No customer found for "$_query"',
                        style: const TextStyle(color: AppColors.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: list.length,
                    separatorBuilder: (context, i) =>
                        const Divider(height: 1, indent: 68),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final isAttached = attached?.id == c.id;
                      return _CustomerTile(
                        customer: c,
                        isAttached: isAttached,
                        onTap: () {
                          ref.read(checkoutCustomerProvider.notifier).state =
                              isAttached ? null : c;
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),

          // ── Quick-create row ──────────────────────────────────────────────
          if (noExactMatch) ...[
            const Divider(height: 1),
            _QuickCreateTile(
              query: _searchCtrl.text.trim(),
              looksLikePhone: looksLikePhone,
              onTap: () => _quickCreate(context),
            ),
          ],

          // ── Manage link ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.push('/customers');
              },
              child: const Text(
                'Manage all customers',
                style: TextStyle(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _quickCreate(BuildContext context) {
    final raw = _searchCtrl.text.trim();
    final looksLikePhone = RegExp(r'^\d+$').hasMatch(raw);

    // Show a tiny bottom sheet to fill missing field
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _QuickCreateSheet(
        prefillName: looksLikePhone ? null : raw,
        prefillPhone: looksLikePhone ? raw : null,
        onCreate: (name, phone) {
          final newCustomer = Customer.create(name: name, phone: phone);
          ref.read(customersProvider.notifier).add(newCustomer);
          ref.read(checkoutCustomerProvider.notifier).state = newCustomer;
          Navigator.pop(ctx); // close quick-create sheet
          Navigator.pop(context); // close picker sheet
        },
      ),
    );
  }
}

// ── Customer tile ─────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  final Customer customer;
  final bool isAttached;
  final VoidCallback onTap;

  const _CustomerTile({
    required this.customer,
    required this.isAttached,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        child: Row(
          children: [
            CustomerAvatar(name: customer.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                customer.name,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            if (isAttached)
              const Icon(Icons.check_circle, size: 20, color: AppColors.accent)
            else
              const Icon(
                Icons.add_circle_outline,
                size: 20,
                color: AppColors.textTertiary,
              ),
          ],
        ),
      ),
    );
  }
}

// ── Quick-create row (shown when no match) ────────────────────────────────────

class _QuickCreateTile extends StatelessWidget {
  final String query;
  final bool looksLikePhone;
  final VoidCallback onTap;

  const _QuickCreateTile({
    required this.query,
    required this.looksLikePhone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.accent.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.person_add_outlined,
                size: 20,
                color: AppColors.accent,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Create new customer ',
                  style: const TextStyle(fontSize: 15),
                  children: [
                    TextSpan(
                      text: looksLikePhone ? 'with phone $query' : '"$query"',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right,
              size: 18,
              color: AppColors.textTertiary,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Quick-create sheet ────────────────────────────────────────────────────────

class _QuickCreateSheet extends StatefulWidget {
  final String? prefillName;
  final String? prefillPhone;
  final void Function(String name, String phone) onCreate;

  const _QuickCreateSheet({
    this.prefillName,
    this.prefillPhone,
    required this.onCreate,
  });

  @override
  State<_QuickCreateSheet> createState() => _QuickCreateSheetState();
}

class _QuickCreateSheetState extends State<_QuickCreateSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _phoneCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.prefillName ?? '');
    _phoneCtrl = TextEditingController(text: widget.prefillPhone ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 16,
        right: 16,
        top: 16,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'New Customer',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _nameCtrl,
              autofocus: widget.prefillName == null,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'e.g. Priya Sharma',
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _phoneCtrl,
              autofocus:
                  widget.prefillPhone == null && widget.prefillName != null,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: 'e.g. 9841123456',
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                if (v.trim().length < 7) return 'Enter a valid number';
                return null;
              },
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    widget.onCreate(
                      _nameCtrl.text.trim(),
                      _phoneCtrl.text.trim(),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: const Text(
                  'Add & Attach to Sale',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
