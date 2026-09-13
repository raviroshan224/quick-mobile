import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../features/staff/data/staff_repository.dart';
import '../../../../features/staff/presentation/providers/staff_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/staff/domain/staff_models.dart';
import '../../../../core/network/api_client.dart';
import '../../../../shared/widgets/image_picker_sheet.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';
import '../../../../features/auth/data/auth_repository.dart';
import '../../../../core/storage/secure_storage_service.dart';
import '../../../../core/utils/pin_validator.dart';
import '../../../../core/utils/phone_validator.dart';
import 'settings_screen.dart' show salonSettingsProvider;

// ─── Avatar colors (must stay in sync with staff_screen.dart) ─────────────────

const _avatarColors = [
  Color(0xFF6B7A3D), // olive
  Color(0xFF4D5A2C), // dark olive
  Color(0xFF8A9950), // medium olive
  Color(0xFF111111), // black
  Color(0xFF3A3A3A), // dark grey
  Color(0xFF5A5A5A), // grey
  Color(0xFF9A9A9A), // light grey
  Color(0xFFB5C090), // pale olive
];

// ─── Staff list provider ──────────────────────────────────────────────────────

final _staffRepoProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.read(apiClientProvider)),
);

// ─── Predefined specialties ───────────────────────────────────────────────────

const _kSpecialties = [
  'Haircut',
  'Hair Color',
  'Blow Dry',
  'Facial',
  'Manicure',
  'Pedicure',
  'Nail Art',
  'Waxing',
  'Massage',
  'Threading',
  'Makeup',
  'Keratin',
];

// ─── Screen ───────────────────────────────────────────────────────────────────

class StaffFormScreen extends ConsumerStatefulWidget {
  /// null = new staff, non-null = editing existing
  final String? staffId;

  const StaffFormScreen({super.key, this.staffId});

  bool get isEditing => staffId != null;

  @override
  ConsumerState<StaffFormScreen> createState() => _StaffFormScreenState();
}

class _StaffFormScreenState extends ConsumerState<StaffFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _emergencyContactCtrl = TextEditingController();
  final _emergencyNameCtrl = TextEditingController();
  final _relationshipCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _pinCtrl = TextEditingController();
  final _confirmPinCtrl = TextEditingController();

  PickedImage? _pickedImage;
  PickedImage? _govIdImage;
  String _govIdType = 'Citizenship';

  bool _isActive = true;
  bool _loading = true;
  // Collapsed by default when creating (keeps the common case — name,
  // phone, PIN — short); expanded by default when editing, since an owner
  // opening an existing staff member's profile likely wants to see what's
  // already filled in, not have it hidden behind a tap.
  late bool _showAdditional = widget.isEditing;

  Set<String> _selectedSpecialties = {};
  final _commissionCtrl = TextEditingController();

  StaffModel? _original;

  // Retry-safety for _saveNew(): the account-creation step (POST
  // /auth/register) is idempotent server-side, keyed off these two values
  // staying byte-identical across a retry — see
  // StaffRepository.createWithAccount(). Minted lazily on the first save
  // attempt and reused as long as the identifying fields haven't changed
  // since; regenerated if they have, since that's a genuinely different
  // signup, not a retry of the same one. Without this, a client-side
  // timeout on a request that actually succeeded server-side left the form
  // permanently stuck: every retry recomputed the same synthesized email
  // and got "Email already in use" from the account the first attempt had
  // already created.
  String? _pendingPassword;
  String? _pendingIdempotencyKey;
  String? _pendingRequestSignature;

  String _requestSignature() => [
        _previewFirstName,
        _previewLastName,
        _mobileCtrl.text.trim(),
        _emailCtrl.text.trim().toLowerCase(),
      ].join('|');

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExisting();
    } else {
      setState(() => _loading = false);
    }
    _fullNameCtrl.addListener(() => setState(() {}));
    _commissionCtrl.addListener(() => setState(() {}));
  }

  Future<void> _loadExisting() async {
    try {
      final repo = ref.read(_staffRepoProvider);
      final s = await repo.getById(widget.staffId!);
      if (!mounted) return;
      _original = s;
      _fullNameCtrl.text = '${s.firstName} ${s.lastName}';
      _mobileCtrl.text = s.phone ?? '';
      _commissionCtrl.text = s.commissionRate != null
          ? s.commissionRate!.toStringAsFixed(
              s.commissionRate! % 1 == 0 ? 0 : 1,
            )
          : '';
      setState(() {
        _selectedSpecialties = Set<String>.from(s.specialties);
        _isActive = s.isActive;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _fullNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _emergencyContactCtrl.dispose();
    _emergencyNameCtrl.dispose();
    _relationshipCtrl.dispose();
    _addressCtrl.dispose();
    _commissionCtrl.dispose();
    _pinCtrl.dispose();
    _confirmPinCtrl.dispose();
    super.dispose();
  }

  // ── Derived display values ─────────────────────────────────────────────────

  String get _previewFullName {
    final t = _fullNameCtrl.text.trim();
    return t.isEmpty ? 'Full Name' : t;
  }

  String get _previewInitials {
    final parts = _previewFullName.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return _previewFullName.isNotEmpty
        ? _previewFullName[0].toUpperCase()
        : '?';
  }

  String get _previewFirstName {
    final parts = _fullNameCtrl.text.trim().split(' ');
    return parts.isNotEmpty ? parts[0] : '';
  }

  String get _previewLastName {
    final parts = _fullNameCtrl.text.trim().split(' ');
    return parts.length > 1 ? parts.sublist(1).join(' ') : '';
  }

  double? get _previewCommission =>
      double.tryParse(_commissionCtrl.text.trim());

  Color get _previewAvatarColor {
    if (widget.isEditing && _original != null) {
      // Use a stable color derived from the existing staff's position — just
      // use a fixed color seeded from the id characters.
      final seed = widget.staffId!.codeUnits.fold(0, (sum, c) => sum + c);
      return _avatarColors[seed % _avatarColors.length];
    }
    return _avatarColors[0];
  }

  Future<void> _pickImage() async {
    final picked = await ImagePickerSheet.show(
      context,
      initialCategory: ImagePickerCategory.staff,
      title: 'Pick Staff Photo',
    );
    if (picked != null) setState(() => _pickedImage = picked);
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (widget.isEditing) {
      _saveEdit();
    } else {
      _saveNew();
    }
  }

  Future<void> _saveEdit() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(_staffRepoProvider);
      await repo.update(
        widget.staffId!,
        phone: _mobileCtrl.text.trim().isEmpty ? null : _mobileCtrl.text.trim(),
        specialties: _selectedSpecialties.toList(),
        commissionRate: double.tryParse(_commissionCtrl.text.trim()),
        isActive: _isActive,
        emergencyContact: _emergencyContactCtrl.text.trim().isEmpty
            ? null
            : _emergencyContactCtrl.text.trim(),
        emergencyContactName: _emergencyNameCtrl.text.trim().isEmpty
            ? null
            : _emergencyNameCtrl.text.trim(),
        emergencyRelationship: _relationshipCtrl.text.trim().isEmpty
            ? null
            : _relationshipCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
      );
      ref.invalidate(staffListProvider);
      ref.invalidate(activeStaffListProvider);
      ref.invalidate(staffDetailProvider(widget.staffId!));
      if (mounted) context.go('/more/staff/${widget.staffId}');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveNew() async {
    setState(() => _loading = true);
    try {
      final repo = ref.read(_staffRepoProvider);
      final rawEmail = _emailCtrl.text.trim().toLowerCase();
      final phone = _mobileCtrl.text.trim();

      // Reuse the same password/idempotency-key as last time only if
      // nothing identifying has changed since — otherwise this is a
      // genuinely new signup, not a retry, and reusing stale tokens would
      // make the idempotency check reject it as "same key, different
      // payload" instead of letting it through.
      final signature = _requestSignature();
      if (_pendingRequestSignature != signature) {
        _pendingRequestSignature = signature;
        _pendingPassword = repo.generatePassword();
        _pendingIdempotencyKey = const Uuid().v4();
      }

      final result = await repo.createWithAccount(
        firstName: _previewFirstName,
        lastName: _previewLastName,
        email: rawEmail.isEmpty ? null : rawEmail,
        pin: _pinCtrl.text,
        phone: phone.isEmpty ? null : phone,
        specialties: _selectedSpecialties.toList(),
        commissionRate: double.tryParse(_commissionCtrl.text.trim()),
        isActive: _isActive,
        emergencyContact: _emergencyContactCtrl.text.trim().isEmpty
            ? null
            : _emergencyContactCtrl.text.trim(),
        emergencyContactName: _emergencyNameCtrl.text.trim().isEmpty
            ? null
            : _emergencyNameCtrl.text.trim(),
        emergencyRelationship: _relationshipCtrl.text.trim().isEmpty
            ? null
            : _relationshipCtrl.text.trim(),
        address: _addressCtrl.text.trim().isEmpty
            ? null
            : _addressCtrl.text.trim(),
        govIdType: _govIdType,
        password: _pendingPassword,
        idempotencyKey: _pendingIdempotencyKey,
      );
      // Done — nothing left to retry, so these must not be reused if the
      // owner comes back to this screen later to add someone else.
      _pendingPassword = null;
      _pendingIdempotencyKey = null;
      _pendingRequestSignature = null;
      ref.invalidate(staffListProvider);
      ref.invalidate(activeStaffListProvider);
      if (mounted) _showCreatedDialog(result.email);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showCreatedDialog(String email) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: const BoxDecoration(
                color: Color(0xFFDCFCE7),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: Color(0xFF16A34A),
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text('Staff Account Created', style: TextStyle(fontSize: 16)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'The staff member can now sign in from the profile picker using the PIN you just set.',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.divider),
              ),
              child: _CredRow(label: 'Email', value: email),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.go('/more/staff');
            },
            child: const Text(
              'Done',
              style: TextStyle(
                color: Colors.black,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _setPin() {
    final pinCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Set Staff PIN'),
            content: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Enter a 4-digit PIN for this staff member to use at the profile picker.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: pinCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'PIN',
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v == null || v.length != 4) return 'PIN must be 4 digits';
                      if (!RegExp(r'^\d{4}$').hasMatch(v)) return 'Digits only';
                      return weakPinError(v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: confirmCtrl,
                    keyboardType: TextInputType.number,
                    maxLength: 4,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirm PIN',
                      counterText: '',
                    ),
                    validator: (v) {
                      if (v != pinCtrl.text) return 'PINs do not match';
                      return null;
                    },
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: saving ? null : () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: saving
                    ? null
                    : () async {
                        if (!formKey.currentState!.validate()) return;
                        setDialogState(() => saving = true);
                        try {
                          final repo = AuthRepository(
                            ref.read(apiClientProvider),
                            ref.read(secureStorageProvider),
                          );
                          await repo.setStaffPin(widget.staffId!, pinCtrl.text);
                          if (ctx.mounted) Navigator.pop(ctx);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('PIN set successfully.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        } catch (e) {
                          setDialogState(() => saving = false);
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(ctx).showSnackBar(
                              SnackBar(
                                content: Text(e.toString()),
                                backgroundColor: AppColors.danger,
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                child: saving
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: Text('Remove $_previewFullName? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(_staffRepoProvider).delete(widget.staffId!);
                // The list/detail screens read from cached FutureProviders
                // that never refetch on their own — without this, the
                // removed staff member keeps showing until the app is
                // fully restarted, making the removal look like it failed.
                ref.invalidate(staffListProvider);
                ref.invalidate(activeStaffListProvider);
                if (mounted) context.go('/more/staff');
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(e.toString()), backgroundColor: Colors.red),
                  );
                }
              }
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: AppColors.danger),
            ),
          ),
        ],
      ),
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final commissionTrackingEnabled =
        ref.watch(salonSettingsProvider).commissionEnabled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : widget.isEditing
              ? context.go('/more/staff/${widget.staffId}')
              : context.go('/more/staff'),
        ),
        title: Text(
          widget.isEditing ? 'Edit Staff' : 'New Staff Member',
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.danger),
              onPressed: _delete,
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Scrollable form body ───────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    // ── Live preview card ──────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                      child: _PreviewCard(
                        initials: _previewInitials,
                        fullName: _previewFullName,
                        avatarColor: _previewAvatarColor,
                        commission: _previewCommission,
                        isActive: _isActive,
                        specialties: _selectedSpecialties.take(3).toList(),
                        pickedImage: _pickedImage,
                        onPickImage: _pickImage,
                      ),
                    ),

                    // ── Required Information ───────────────────────────────
                    _SectionHeader(
                        label: widget.isEditing
                            ? 'Basic Information'
                            : 'Required Information'),
                    _FormCard(
                      children: [
                        _Field(
                          label: 'Full Name *',
                          child: TextFormField(
                            controller: _fullNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Priya Thapa',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Full name is required'
                                : null,
                          ),
                        ),
                        const _FieldDivider(),
                        _Field(
                          label: 'Mobile Number *',
                          child: TextFormField(
                            controller: _mobileCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'e.g. 9800000000',
                            ),
                            validator: (v) =>
                                phoneNumberError(v, required: true),
                          ),
                        ),
                        if (!widget.isEditing) ...[
                          const _FieldDivider(),
                          _Field(
                            label: 'PIN *',
                            child: TextFormField(
                              controller: _pinCtrl,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                hintText: '4-digit sign-in PIN',
                                counterText: '',
                              ),
                              validator: (v) {
                                if (v == null || v.length != 4) {
                                  return 'PIN must be 4 digits';
                                }
                                return weakPinError(v);
                              },
                            ),
                          ),
                          const _FieldDivider(),
                          _Field(
                            label: 'Confirm PIN *',
                            child: TextFormField(
                              controller: _confirmPinCtrl,
                              keyboardType: TextInputType.number,
                              obscureText: true,
                              maxLength: 4,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              decoration: const InputDecoration(
                                hintText: 'Re-enter PIN',
                                counterText: '',
                              ),
                              validator: (v) {
                                if (v != _pinCtrl.text) {
                                  return 'PINs do not match';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ],
                    ),

                    // ── Additional Information (collapsible) ───────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _showAdditional = !_showAdditional),
                        child: Row(
                          children: [
                            const Text(
                              'ADDITIONAL INFORMATION',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _showAdditional
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const Spacer(),
                            if (!_showAdditional)
                              const Text(
                                'Optional',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textTertiary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    if (!_showAdditional) const SizedBox(height: 4),

                    if (_showAdditional) ...[
                    // ── Contact ─────────────────────────────────────────────
                    const _SectionHeader(label: 'Contact'),
                    _FormCard(
                      children: [
                        _Field(
                          label: 'Email',
                          child: TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: widget.isEditing,
                            style: TextStyle(
                              color: widget.isEditing
                                  ? AppColors.textSecondary
                                  : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. priya@salon.com (optional)',
                              suffixIcon: widget.isEditing
                                  ? const Icon(
                                      Icons.lock_outline,
                                      size: 16,
                                      color: AppColors.textTertiary,
                                    )
                                  : null,
                            ),
                            validator: (v) {
                              if (v != null && v.trim().isNotEmpty && !v.contains('@')) {
                                return 'Enter a valid email';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    // ── Emergency Contact ─────────────────────────────────
                    const _SectionHeader(label: 'Emergency Contact'),
                    _FormCard(
                      children: [
                        _Field(
                          label: 'Emergency Contact Number',
                          child: TextFormField(
                            controller: _emergencyContactCtrl,
                            keyboardType: TextInputType.phone,
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(10),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'e.g. 9800000000 (optional)',
                            ),
                            validator: (v) => phoneNumberError(v),
                          ),
                        ),
                        const _FieldDivider(),
                        _Field(
                          label: 'Emergency Contact Name',
                          child: TextFormField(
                            controller: _emergencyNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Ram Thapa (optional)',
                            ),
                          ),
                        ),
                        const _FieldDivider(),
                        _Field(
                          label: 'Relationship',
                          child: TextFormField(
                            controller: _relationshipCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Father, Mother, Spouse',
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Address ────────────────────────────────────────────
                    const _SectionHeader(label: 'Address'),
                    _FormCard(
                      children: [
                        _Field(
                          label: 'Address',
                          child: TextFormField(
                            controller: _addressCtrl,
                            textCapitalization: TextCapitalization.words,
                            maxLines: 2,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Kathmandu, Nepal',
                            ),
                          ),
                        ),
                      ],
                    ),

                    // ── Government Identification ─────────────────────────
                    const _SectionHeader(label: 'Government Identification'),
                    _FormCard(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'ID Type',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                children:
                                    [
                                      'Citizenship',
                                      'Passport',
                                      'Driving License',
                                    ].map((type) {
                                      final selected = _govIdType == type;
                                      return GestureDetector(
                                        onTap: () =>
                                            setState(() => _govIdType = type),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 7,
                                          ),
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? Colors.black
                                                : AppColors.surfaceVariant,
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? Colors.black
                                                  : AppColors.divider,
                                            ),
                                          ),
                                          child: Text(
                                            type,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: selected
                                                  ? FontWeight.w600
                                                  : FontWeight.w400,
                                              color: selected
                                                  ? Colors.white
                                                  : AppColors.textSecondary,
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                        const _FieldDivider(),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Government Photo',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await ImagePickerSheet.show(
                                    context,
                                    title: 'Upload ID Photo',
                                  );
                                  if (picked != null) {
                                    setState(() => _govIdImage = picked);
                                  }
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: _govIdImage != null ? 100 : 80,
                                  decoration: BoxDecoration(
                                    color: AppColors.background,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: AppColors.divider,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: _govIdImage != null
                                      ? Stack(
                                          children: [
                                            Center(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    _govIdImage!.iconData,
                                                    size: 32,
                                                    color: _govIdImage!.color,
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    _govIdImage!.name,
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Positioned(
                                              top: 6,
                                              right: 6,
                                              child: GestureDetector(
                                                onTap: () => setState(
                                                  () => _govIdImage = null,
                                                ),
                                                child: Container(
                                                  padding: const EdgeInsets.all(
                                                    4,
                                                  ),
                                                  decoration:
                                                      const BoxDecoration(
                                                        color: Color(
                                                          0xFFF3F4F6,
                                                        ),
                                                        shape: BoxShape.circle,
                                                      ),
                                                  child: const Icon(
                                                    Icons.close,
                                                    size: 14,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Column(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(
                                              Icons.cloud_upload_outlined,
                                              size: 24,
                                              color: AppColors.textTertiary,
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              'Tap to upload photo',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: AppColors.textSecondary,
                                              ),
                                            ),
                                            Text(
                                              'Camera or Gallery',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textTertiary,
                                              ),
                                            ),
                                          ],
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    // ── Commission ────────────────────────────────────────
                    if (commissionTrackingEnabled) ...[
                      const _SectionHeader(label: 'Commission'),
                      _FormCard(
                        children: [
                          _Field(
                            label: 'Commission Rate (%)',
                            child: TextFormField(
                              controller: _commissionCtrl,
                              keyboardType: const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              inputFormatters: [
                                FilteringTextInputFormatter.allow(
                                  RegExp(r'^\d*\.?\d{0,2}'),
                                ),
                              ],
                              decoration: const InputDecoration(
                                hintText: 'Leave blank for no commission',
                                suffixText: '%',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return null; // optional
                                }
                                final n = double.tryParse(v);
                                if (n == null || n < 0 || n > 100) {
                                  return 'Enter a value between 0 and 100';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],

                    // ── Specialties ───────────────────────────────────────
                    const _SectionHeader(label: 'Specialties'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: _kSpecialties.map((sp) {
                            final selected = _selectedSpecialties.contains(sp);
                            return _SpecialtyToggleChip(
                              label: sp,
                              selected: selected,
                              onTap: () => setState(() {
                                if (selected) {
                                  _selectedSpecialties.remove(sp);
                                } else {
                                  _selectedSpecialties.add(sp);
                                }
                              }),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // ── Status ────────────────────────────────────────────
                    const _SectionHeader(label: 'Status'),
                    _FormCard(
                      children: [
                        SwitchListTile.adaptive(
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          title: const Text(
                            'Active',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          subtitle: Text(
                            _isActive
                                ? 'Staff member appears in checkout & scheduling'
                                : 'Staff member is hidden from active lists',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: Colors.black,
                        ),
                      ],
                    ),

                    ], // end of _showAdditional block

                    if (widget.isEditing) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: OutlinedButton.icon(
                          onPressed: _setPin,
                          icon: const Icon(Icons.pin_outlined, size: 17),
                          label: const Text('Set PIN'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textSecondary,
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            minimumSize: const Size(double.infinity, 0),
                          ),
                        ),
                      ),
                    ],

                    // ── Activity (edit only) ──────────────────────────────
                    if (widget.isEditing) ...[
                      const _SectionHeader(label: 'Activity'),
                      _ActivitySection(
                        staffId: widget.staffId!,
                        commissionRate:
                            double.tryParse(_commissionCtrl.text) ?? 0,
                        showCommission: commissionTrackingEnabled,
                      ),
                    ],

                    // ── Danger zone (edit only) ───────────────────────────
                    if (widget.isEditing) ...[
                      const _SectionHeader(label: 'Danger Zone'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton(
                          onPressed: _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger,
                            side: const BorderSide(color: AppColors.danger),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.person_remove_outlined, size: 18),
                              SizedBox(width: 6),
                              Text(
                                'Remove Staff Member',
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
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
      // ── Save button ───────────────────────────────────────────────────────
      bottomNavigationBar: Container(
        color: AppColors.background,
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: _BigBtn(
          label: widget.isEditing ? 'Save Changes' : 'Add Staff Member',
          onTap: _save,
          isLoading: _loading,
        ),
      ),
    );
  }
}

// ─── Live preview card ────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.initials,
    required this.fullName,
    required this.avatarColor,
    required this.commission,
    required this.isActive,
    required this.specialties,
    this.pickedImage,
    this.onPickImage,
  });
  final String initials;
  final String fullName;
  final Color avatarColor;
  final double? commission;
  final bool isActive;
  final List<String> specialties;
  final PickedImage? pickedImage;
  final VoidCallback? onPickImage;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          // Avatar
          PickableAvatar(
            radius: 26,
            fallbackInitials: initials,
            fallbackColor: avatarColor,
            picked: pickedImage,
            onTap: onPickImage ?? () {},
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Active dot
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: isActive
                            ? const Color(0xFF10B981)
                            : AppColors.border,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
                if (specialties.isNotEmpty) ...[
                  const SizedBox(height: 5),
                  Text(
                    specialties.join(' · '),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (commission != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                color: AppColors.primaryLight,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${commission!.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Specialty toggle chip ────────────────────────────────────────────────────

class _SpecialtyToggleChip extends StatelessWidget {
  const _SpecialtyToggleChip({
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.black : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : AppColors.divider,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── Big black save button ────────────────────────────────────────────────────

class _BigBtn extends StatelessWidget {
  const _BigBtn({required this.label, required this.onTap, this.isLoading = false});
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: isLoading ? null : onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.textSecondary,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.1,
                ),
              ),
      ),
    );
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.8,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Form card ────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(children: children),
    );
  }
}

// ─── Field ────────────────────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 5),
          child,
        ],
      ),
    );
  }
}

// ─── Field divider ────────────────────────────────────────────────────────────

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(
      height: 1,
      indent: 16,
      endIndent: 16,
      color: AppColors.divider,
    );
  }
}

// ─── Activity section (edit mode) ────────────────────────────────────────────

class _ActivitySection extends ConsumerWidget {
  const _ActivitySection({
    required this.staffId,
    required this.commissionRate,
    this.showCommission = true,
  });
  final String staffId;
  final double commissionRate;
  final bool showCommission;

  String _dateLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(d).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(staffTransactionsProvider(staffId));

    return txAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => const SizedBox.shrink(),
      data: (transactions) {
        final totalSales =
            transactions.fold(0.0, (s, t) => s + t.total);
        final totalComm = totalSales * commissionRate / 100;

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _StatBox(
                      label: 'Revenue',
                      value: 'Rs ${totalSales.toStringAsFixed(0)}',
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF10B981),
                    ),
                  ),
                  if (showCommission) ...[
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatBox(
                        label: 'Commission',
                        value: 'Rs ${totalComm.toStringAsFixed(0)}',
                        icon: Icons.payments_outlined,
                        iconColor: AppColors.primary,
                      ),
                    ),
                  ],
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatBox(
                      label: 'Services',
                      value: '${transactions.length}',
                      icon: Icons.spa_outlined,
                      iconColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                      child: Text(
                        'Recent Services',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    const Divider(height: 1, color: AppColors.surfaceVariant),
                    if (transactions.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(16),
                        child: Text('No activity yet.',
                            style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                      )
                    else
                      ...transactions.take(5).map((tx) {
                        final service = tx.items?.firstOrNull?.displayName ?? 'Service';
                        final comm =
                            showCommission ? tx.total * commissionRate / 100 : 0.0;
                        return _ActivityTile(
                          entry: _ActivityEntry(
                            date: _dateLabel(tx.createdAt),
                            service: service,
                            customer: tx.displayName,
                            amount: tx.total,
                            commission: comm,
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ActivityEntry {
  const _ActivityEntry({
    required this.date,
    required this.service,
    required this.amount,
    required this.commission,
    required this.customer,
  });
  final String date;
  final String service;
  final double amount;
  final double commission;
  final String customer;
}

class _StatBox extends StatelessWidget {
  const _StatBox({
    required this.label,
    required this.value,
    required this.icon,
    required this.iconColor,
  });
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});
  final _ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.spa_outlined,
              size: 18,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.service,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  entry.customer,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Rs ${entry.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (entry.commission > 0)
                Text(
                  '+Rs ${entry.commission.toStringAsFixed(0)} comm.',
                  style: const TextStyle(fontSize: 11, color: Color(0xFF10B981)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Credential row (used in the "account created" dialog) ───────────────────

class _CredRow extends StatelessWidget {
  const _CredRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 68,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
