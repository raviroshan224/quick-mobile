import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/customers/data/mock_customers_repository.dart';
import '../../../../features/customers/domain/customer_models.dart';
import '../../../../shared/widgets/image_picker_sheet.dart';

// ── In-memory customer list provider ─────────────────────────────────────────

class _CustomerListNotifier
    extends StateNotifier<List<CustomerModel>> {
  _CustomerListNotifier() : super([]);

  /// Seeded lazily from the mock repo the first time we need data.
  bool _seeded = false;

  Future<void> ensureSeeded() async {
    if (_seeded) return;
    _seeded = true;
    final all = await MockCustomersRepository().getAll();
    state = all;
  }

  void add(CustomerModel c) => state = [...state, c];

  void update(CustomerModel c) {
    state = [for (final s in state) if (s.id == c.id) c else s];
  }

  void delete(String id) =>
      state = state.where((c) => c.id != id).toList();
}

final customerListProvider = StateNotifierProvider<
    _CustomerListNotifier, List<CustomerModel>>(
  (_) => _CustomerListNotifier(),
);

/// FutureProvider used by the form to load a single customer for editing.
final _editCustomerProvider =
    FutureProvider.family<CustomerModel?, String>((ref, id) {
  return MockCustomersRepository().getById(id);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CustomerFormScreen extends ConsumerStatefulWidget {
  const CustomerFormScreen({super.key, this.customerId});

  /// null = new customer; non-null = editing.
  final String? customerId;

  bool get isEditing => customerId != null;

  @override
  ConsumerState<CustomerFormScreen> createState() =>
      _CustomerFormScreenState();
}

class _CustomerFormScreenState
    extends ConsumerState<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameCtrl = TextEditingController();
  final _lastNameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  PickedImage? _pickedImage;

  bool _prefilled = false;
  bool _saving = false;

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // Pre-fill form fields from a loaded customer (edit mode).
  void _prefill(CustomerModel c) {
    if (_prefilled) return;
    _prefilled = true;
    _firstNameCtrl.text = c.firstName;
    _lastNameCtrl.text = c.lastName;
    _phoneCtrl.text = c.phone ?? '';
    _emailCtrl.text = c.email ?? '';
    _notesCtrl.text = c.notes ?? '';
  }

  String get _previewName {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    if (first.isEmpty && last.isEmpty) return 'New Customer';
    return '$first $last'.trim();
  }

  String get _previewInitials {
    final first = _firstNameCtrl.text.trim();
    final last = _lastNameCtrl.text.trim();
    final f = first.isNotEmpty ? first[0].toUpperCase() : '';
    final l = last.isNotEmpty ? last[0].toUpperCase() : '';
    final initials = '$f$l';
    return initials.isNotEmpty ? initials : '?';
  }

  Future<void> _pickImage() async {
    final picked = await ImagePickerSheet.show(
      context,
      initialCategory: ImagePickerCategory.all,
      title: 'Pick Customer Photo',
    );
    if (picked != null) setState(() => _pickedImage = picked);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone =
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
    final email =
        _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    if (widget.isEditing) {
      // We need the original to preserve visit stats.
      // Pull it from the mock repo via the already-loaded async value.
      final existing = ref
          .read(_editCustomerProvider(widget.customerId!))
          .valueOrNull;
      if (existing != null) {
        final updated = existing.copyWith(
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          email: email,
          notes: notes,
        );
        ref.read(customerListProvider.notifier).update(updated);
      }
    } else {
      final newCustomer = CustomerModel(
        id: 'c-${DateTime.now().millisecondsSinceEpoch}',
        firstName: firstName,
        lastName: lastName,
        phone: phone,
        email: email,
        notes: notes,
      );
      ref.read(customerListProvider.notifier).add(newCustomer);
    }

    setState(() => _saving = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(widget.isEditing
            ? 'Customer updated'
            : '$firstName $lastName added'),
        backgroundColor: Colors.black,
        duration: const Duration(seconds: 2),
      ),
    );

    context.go(AppRoutes.moreCustomers);
  }

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Customer',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600)),
        content: Text(
          'Remove $_previewName? This cannot be undone.',
          style: const TextStyle(
              fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(customerListProvider.notifier)
                  .delete(widget.customerId!);
              context.go(AppRoutes.moreCustomers);
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: Color(0xFFEF4444),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // In edit mode, load and prefill from the repo.
    if (widget.isEditing) {
      final customerAsync =
          ref.watch(_editCustomerProvider(widget.customerId!));
      customerAsync.whenData((c) {
        if (c != null) _prefill(c);
      });
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.black),
                    onPressed: () {
                      if (widget.isEditing) {
                        context.go(AppRoutes.customerDetail(
                            widget.customerId!));
                      } else {
                        context.go(AppRoutes.moreCustomers);
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      widget.isEditing
                          ? 'Edit Customer'
                          : 'New Customer',
                      style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                    ),
                  ),
                  // Save text button
                  TextButton(
                    onPressed: _saving ? null : _save,
                    child: Text(
                      _saving ? 'Saving…' : 'Save',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: _saving
                            ? const Color(0xFF9CA3AF)
                            : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Form body ─────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 40),
                  children: [
                    const SizedBox(height: 16),

                    // ── Live preview card ─────────────────────────
                    Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16),
                      child: _PreviewCard(
                        initials: _previewInitials,
                        name: _previewName,
                        phone: _phoneCtrl.text.trim(),
                        email: _emailCtrl.text.trim(),
                        picked: _pickedImage,
                        onPickTap: _pickImage,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Name fields ───────────────────────────────
                    const _SectionLabel(text: 'NAME'),
                    _FormCard(
                      children: [
                        _FormField(
                          label: 'First Name',
                          required: true,
                          child: TextFormField(
                            controller: _firstNameCtrl,
                            textCapitalization:
                                TextCapitalization.words,
                            decoration: const InputDecoration(
                                hintText: 'e.g. Anita'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'First name is required'
                                    : null,
                          ),
                        ),
                        const _FieldDivider(),
                        _FormField(
                          label: 'Last Name',
                          required: true,
                          child: TextFormField(
                            controller: _lastNameCtrl,
                            textCapitalization:
                                TextCapitalization.words,
                            decoration: const InputDecoration(
                                hintText: 'e.g. Shrestha'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) =>
                                (v == null || v.trim().isEmpty)
                                    ? 'Last name is required'
                                    : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Contact fields ────────────────────────────
                    const _SectionLabel(text: 'CONTACT'),
                    _FormCard(
                      children: [
                        _FormField(
                          label: 'Phone',
                          child: TextFormField(
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                            ],
                            decoration: const InputDecoration(
                                hintText: 'e.g. 9801234567'),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                        const _FieldDivider(),
                        _FormField(
                          label: 'Email',
                          child: TextFormField(
                            controller: _emailCtrl,
                            keyboardType:
                                TextInputType.emailAddress,
                            decoration: const InputDecoration(
                                hintText:
                                    'e.g. anita@email.com'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return null; // optional
                              }
                              final emailRe = RegExp(
                                  r'^[^@]+@[^@]+\.[^@]+$');
                              if (!emailRe
                                  .hasMatch(v.trim())) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),

                    // ── Notes field ───────────────────────────────
                    const _SectionLabel(text: 'NOTES'),
                    _FormCard(
                      children: [
                        _FormField(
                          label: 'Notes',
                          child: TextFormField(
                            controller: _notesCtrl,
                            maxLines: 4,
                            minLines: 3,
                            textCapitalization:
                                TextCapitalization.sentences,
                            decoration: const InputDecoration(
                              hintText:
                                  'Preferences, allergies, special requests…',
                              alignLabelWithHint: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),

                    // ── Delete (edit mode only) ───────────────────
                    if (widget.isEditing) ...[
                      const SizedBox(height: 28),
                      const _SectionLabel(text: 'DANGER ZONE'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16),
                        child: OutlinedButton(
                          onPressed: _confirmDelete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor:
                                const Color(0xFFEF4444),
                            side: const BorderSide(
                                color: Color(0xFFEF4444)),
                            shape: RoundedRectangleBorder(
                                borderRadius:
                                    BorderRadius.circular(12)),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                          child: const Row(
                            mainAxisAlignment:
                                MainAxisAlignment.center,
                            children: [
                              Icon(Icons.delete_outline,
                                  size: 17),
                              SizedBox(width: 8),
                              Text('Delete Customer',
                                  style: TextStyle(
                                      fontWeight:
                                          FontWeight.w600,
                                      fontSize: 14)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Live preview card ─────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.initials,
    required this.name,
    required this.phone,
    required this.email,
    required this.picked,
    required this.onPickTap,
  });
  final String initials;
  final String name;
  final String phone;
  final String email;
  final PickedImage? picked;
  final VoidCallback onPickTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          PickableAvatar(
            radius: 26,
            fallbackInitials: initials,
            fallbackColor: Colors.black,
            picked: picked,
            onTap: onPickTap,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w600),
                ),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(phone,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280))),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF6B7280))),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section label ─────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Form card ─────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(children: children),
    );
  }
}

// ── Field divider ─────────────────────────────────────────────────────────────

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
        height: 1, indent: 16, endIndent: 0,
        color: Color(0xFFF3F4F6));
  }
}

// ── Form field row ────────────────────────────────────────────────────────────

class _FormField extends StatelessWidget {
  const _FormField({
    required this.label,
    required this.child,
    this.required = false,
  });
  final String label;
  final Widget child;
  final bool required;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF6B7280),
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFEF4444)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
