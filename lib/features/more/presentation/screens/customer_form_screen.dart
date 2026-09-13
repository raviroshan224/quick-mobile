import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/phone_validator.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/customers/domain/customer_models.dart';
import '../../../../features/customers/presentation/providers/customers_provider.dart';
import '../../../../shared/widgets/image_picker_sheet.dart';
import 'settings_screen.dart' show salonSettingsProvider;

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
  final _addressCtrl = TextEditingController();
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
    _addressCtrl.dispose();
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
    _addressCtrl.text = c.address ?? '';
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final firstName = _firstNameCtrl.text.trim();
    final lastName = _lastNameCtrl.text.trim();
    final phone =
        _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim();
    final email =
        _emailCtrl.text.trim().isEmpty ? null : _emailCtrl.text.trim();
    final address =
        _addressCtrl.text.trim().isEmpty ? null : _addressCtrl.text.trim();
    final notes =
        _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim();

    try {
      final repo = ref.read(customersRepoProvider);
      if (widget.isEditing) {
        await repo.update(
          widget.customerId!,
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          email: email,
          address: address,
          notes: notes,
        );
      } else {
        await repo.create(
          firstName: firstName,
          lastName: lastName,
          phone: phone,
          email: email,
          address: address,
          notes: notes,
        );
      }
      ref.invalidate(customersProvider);
      if (widget.isEditing) {
        // Otherwise the detail screen keeps showing the pre-edit customer
        // (name/phone/email/etc.) if it's cached — customerDetailProvider
        // isn't autoDispose, so it won't naturally pick up this change.
        ref.invalidate(customerDetailProvider(widget.customerId!));
      }
      if (mounted) {
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
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
              fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(customersRepoProvider).delete(widget.customerId!);
                ref.invalidate(customersProvider);
                if (mounted) context.go(AppRoutes.moreCustomers);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.toString()),
                      backgroundColor: Colors.red,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
            child: const Text('Delete',
                style: TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // In edit mode, load and prefill from the API.
    if (widget.isEditing) {
      ref.watch(customerDetailProvider(widget.customerId!)).whenData(_prefill);
    }
    // The API already blanks these fields in the response for a restricted
    // staff viewer — disable them here too so it reads as "hidden" rather
    // than "empty", and so nobody tries to type a replacement value that
    // the backend will silently discard anyway.
    final contactFieldsHidden = widget.isEditing &&
        !ref.watch(isOwnerProvider) &&
        !ref.watch(salonSettingsProvider).staffCanViewCustomerDetails;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () {
            if (widget.isEditing) {
              context.go(AppRoutes.customerDetail(widget.customerId!));
            } else {
              context.go(AppRoutes.moreCustomers);
            }
          },
        ),
        title: Text(
          widget.isEditing ? 'Edit Customer' : 'New Customer',
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.danger),
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
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
                            enabled: !contactFieldsHidden,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: InputDecoration(
                                hintText: contactFieldsHidden
                                    ? 'Hidden — ask the owner'
                                    : 'e.g. 9800000000'),
                            onChanged: (_) => setState(() {}),
                            validator: (v) =>
                                contactFieldsHidden ? null : phoneNumberError(v),
                          ),
                        ),
                        const _FieldDivider(),
                        _FormField(
                          label: 'Email',
                          child: TextFormField(
                            controller: _emailCtrl,
                            enabled: !contactFieldsHidden,
                            keyboardType:
                                TextInputType.emailAddress,
                            decoration: InputDecoration(
                                hintText: contactFieldsHidden
                                    ? 'Hidden — ask the owner'
                                    : 'e.g. anita@email.com'),
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

                    // ── Location field ────────────────────────────
                    const _SectionLabel(text: 'LOCATION'),
                    _FormCard(
                      children: [
                        _FormField(
                          label: 'Address',
                          child: TextFormField(
                            controller: _addressCtrl,
                            enabled: !contactFieldsHidden,
                            maxLines: 3,
                            minLines: 2,
                            textCapitalization:
                                TextCapitalization.words,
                            decoration: InputDecoration(
                              hintText: contactFieldsHidden
                                  ? 'Hidden — ask the owner'
                                  : 'e.g. Baluwatar, Kathmandu',
                              alignLabelWithHint: true,
                            ),
                            onChanged: (_) => setState(() {}),
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
                            enabled: !contactFieldsHidden,
                            maxLines: 4,
                            minLines: 3,
                            textCapitalization:
                                TextCapitalization.sentences,
                            decoration: InputDecoration(
                              hintText: contactFieldsHidden
                                  ? 'Hidden — ask the owner'
                                  : 'Preferences, allergies, special requests…',
                              alignLabelWithHint: true,
                            ),
                            onChanged: (_) => setState(() {}),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GestureDetector(
            onTap: _saving ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                color: _saving ? Colors.black54 : Colors.black,
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      widget.isEditing ? 'Save Changes' : 'Add Customer',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
            ),
          ),
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
        border: Border.all(color: AppColors.divider),
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
                          color: AppColors.textSecondary)),
                ],
                if (email.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(email,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
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
          color: AppColors.textSecondary,
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
        border: Border.all(color: AppColors.divider),
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
        color: AppColors.surfaceVariant);
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
                  color: AppColors.textSecondary,
                ),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.danger),
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
