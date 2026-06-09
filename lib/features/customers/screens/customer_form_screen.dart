import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/customer_model.dart';
import '../providers/customers_provider.dart';
import 'customers_screen.dart' show CustomerAvatar;

class CustomerFormScreen extends ConsumerStatefulWidget {
  final String? customerId;
  const CustomerFormScreen({super.key, this.customerId});

  bool get isEditing => customerId != null;

  @override
  ConsumerState<CustomerFormScreen> createState() =>
      _CustomerFormScreenState();
}

class _CustomerFormScreenState extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  DateTime? _birthday;
  Customer? _original;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  void _load() {
    final c = ref
        .read(customersProvider)
        .where((c) => c.id == widget.customerId)
        .firstOrNull;
    if (c == null) return;
    _original = c;
    _nameCtrl.text = c.name;
    _phoneCtrl.text = c.phone;
    _notesCtrl.text = c.notes ?? '';
    setState(() => _birthday = c.birthday);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;

    if (widget.isEditing && _original != null) {
      ref.read(customersProvider.notifier).update(
            _original!.copyWith(
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              birthday: _birthday,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            ),
          );
    } else {
      ref.read(customersProvider.notifier).add(
            Customer.create(
              name: _nameCtrl.text.trim(),
              phone: _phoneCtrl.text.trim(),
              birthday: _birthday,
              notes: _notesCtrl.text.trim().isEmpty
                  ? null
                  : _notesCtrl.text.trim(),
            ),
          );
    }
    context.pop();
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text(
            'Remove ${_nameCtrl.text}? Their visit history will be lost.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              // Clear from checkout if attached
              final attached = ref.read(checkoutCustomerProvider);
              if (attached?.id == widget.customerId) {
                ref.read(checkoutCustomerProvider.notifier).state = null;
              }
              ref.read(customersProvider.notifier).delete(widget.customerId!);
              // Pop twice: form → detail → list
              context.pop();
              if (context.canPop()) context.pop();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.refund)),
          ),
        ],
      ),
    );
  }

  Future<void> _pickBirthday() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthday ?? DateTime(1995),
      firstDate: DateTime(1940),
      lastDate: DateTime.now(),
      helpText: 'Select birthday',
    );
    if (picked != null) setState(() => _birthday = picked);
  }

  String _formatDate(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}, ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Customer' : 'New Customer'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.refund),
              onPressed: _delete,
              tooltip: 'Delete',
            ),
          TextButton(
            onPressed: _save,
            child: const Text('Save',
                style: TextStyle(
                    fontWeight: FontWeight.w700, color: AppColors.accent)),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            // ── Avatar preview ─────────────────────────────────────────────
            const SizedBox(height: 24),
            Center(
              child: ValueListenableBuilder(
                valueListenable: _nameCtrl,
                builder: (context, value, child) => CustomerAvatar(
                  name: _nameCtrl.text.isEmpty ? '?' : _nameCtrl.text,
                  size: 64,
                ),
              ),
            ),
            const SizedBox(height: 4),

            // ── Required fields ───────────────────────────────────────────
            const _SectionHeader(label: 'Required'),
            _FormCard(children: [
              _Field(
                label: 'Full Name',
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration:
                      const InputDecoration(hintText: 'e.g. Priya Sharma'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                ),
              ),
              const Divider(height: 1),
              _Field(
                label: 'Phone Number',
                child: TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration:
                      const InputDecoration(hintText: 'e.g. 9841123456'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Phone is required';
                    }
                    if (v.trim().length < 7) {
                      return 'Enter a valid phone number';
                    }
                    return null;
                  },
                ),
              ),
            ]),

            // ── Optional fields ───────────────────────────────────────────
            const _SectionHeader(label: 'Optional'),
            _FormCard(children: [
              // Birthday picker
              InkWell(
                onTap: _pickBirthday,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  child: Row(
                    children: [
                      const Icon(Icons.cake_outlined,
                          size: 20, color: AppColors.textSecondary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _birthday != null
                              ? _formatDate(_birthday!)
                              : 'Birthday',
                          style: TextStyle(
                            fontSize: 15,
                            color: _birthday != null
                                ? AppColors.textPrimary
                                : AppColors.textTertiary,
                          ),
                        ),
                      ),
                      if (_birthday != null)
                        GestureDetector(
                          onTap: () => setState(() => _birthday = null),
                          child: const Icon(Icons.close,
                              size: 16,
                              color: AppColors.textTertiary),
                        )
                      else
                        const Icon(Icons.chevron_right,
                            size: 18, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const Divider(height: 1),
              // Notes
              _Field(
                label: 'Notes',
                child: TextFormField(
                  controller: _notesCtrl,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    hintText:
                        'Allergies, preferences, colour formulas…',
                  ),
                ),
              ),
            ]),

            // ── Delete ─────────────────────────────────────────────────────
            if (widget.isEditing) ...[
              const _SectionHeader(label: 'Danger Zone'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: OutlinedButton(
                  onPressed: _delete,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.refund,
                    side: const BorderSide(color: AppColors.refund),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.delete_outline, size: 18),
                      SizedBox(width: 6),
                      Text('Delete Customer',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Shared helpers ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(label.toUpperCase(),
          style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: AppColors.textSecondary)),
    );
  }
}

class _FormCard extends StatelessWidget {
  final List<Widget> children;
  const _FormCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(children: children),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
