import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/data/mock_auth_repository.dart';
import '../../../../features/auth/domain/user_model.dart';
import '../../../../features/staff/data/mock_staff_repository.dart';
import '../../../../features/staff/domain/staff_models.dart';
import '../../../../shared/widgets/image_picker_sheet.dart';

// ─── Avatar colors (must stay in sync with staff_screen.dart) ─────────────────

const _avatarColors = [
  Color(0xFF6366F1),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF14B8A6),
];

// ─── Staff list provider ──────────────────────────────────────────────────────

class _StaffListNotifier extends StateNotifier<List<StaffModel>> {
  _StaffListNotifier() : super([]);

  void add(StaffModel s) => state = [...state, s];

  void update(StaffModel updated) {
    state = [
      for (final s in state)
        if (s.id == updated.id) updated else s,
    ];
  }

  void delete(String id) => state = state.where((s) => s.id != id).toList();
}

final staffListProvider =
    StateNotifierProvider<_StaffListNotifier, List<StaffModel>>(
      (_) => _StaffListNotifier(),
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
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();

  PickedImage? _pickedImage;
  PickedImage? _govIdImage;
  String _govIdType = 'Citizenship';

  bool _isActive = true;
  bool _loading = true;
  bool _showPassword = false;
  bool _showConfirm = false;

  Set<String> _selectedSpecialties = {};
  final _commissionCtrl = TextEditingController();

  StaffModel? _original;

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
      final s = await MockStaffRepository().getById(widget.staffId!);
      if (!mounted) return;
      _original = s;
      _fullNameCtrl.text = '${s.firstName} ${s.lastName}';
      _mobileCtrl.text = s.phone ?? '';
      _commissionCtrl.text = s.commissionRate != null
          ? s.commissionRate!.toStringAsFixed(
              s.commissionRate! % 1 == 0 ? 0 : 1,
            )
          : '';
      final email = MockAuthRepository.getEmailByUserId(s.userId);
      if (email != null) _emailCtrl.text = email;
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
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
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

    final commission = double.tryParse(_commissionCtrl.text.trim());
    final phone = _mobileCtrl.text.trim().isEmpty
        ? null
        : _mobileCtrl.text.trim();
    final email = _emailCtrl.text.trim().toLowerCase();
    final password = _passwordCtrl.text;

    if (widget.isEditing && _original != null) {
      final updated = _original!.copyWith(
        firstName: _previewFirstName,
        lastName: _previewLastName,
        phone: phone,
        specialties: _selectedSpecialties.toList(),
        commissionRate: commission,
        isActive: _isActive,
      );
      ref.read(staffListProvider.notifier).update(updated);
      context.go('/more/staff/${widget.staffId}');
    } else {
      final userId =
          'u-${_previewFirstName.toLowerCase()}-${DateTime.now().millisecondsSinceEpoch}';
      final newStaff = StaffModel(
        id: 'st-${DateTime.now().millisecondsSinceEpoch}',
        userId: userId,
        firstName: _previewFirstName,
        lastName: _previewLastName,
        phone: phone,
        specialties: _selectedSpecialties.toList(),
        commissionRate: commission,
        isActive: _isActive,
      );
      ref.read(staffListProvider.notifier).add(newStaff);
      MockAuthRepository.registerStaff(
        email: email,
        password: password,
        user: UserModel(
          id: userId,
          email: email,
          firstName: _previewFirstName,
          lastName: _previewLastName,
          role: UserRole.staff,
        ),
      );
      _showCreatedDialog(email, password);
    }
  }

  void _showCreatedDialog(String email, String password) {
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
              'Share these login credentials with the staff member:',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CredRow(label: 'Email', value: email),
                  const SizedBox(height: 8),
                  _CredRow(label: 'Password', value: password),
                ],
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'The staff member can log in and change their password from Settings.',
              style: TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
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

  void _resetPassword() {
    final resetCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Reset Password', style: TextStyle(fontSize: 16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Set a new password for ${_previewFirstName}:',
              style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: resetCtrl,
              obscureText: true,
              autofocus: true,
              decoration: InputDecoration(
                hintText: 'New password (min 4 chars)',
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                border: OutlineInputBorder(
                  borderSide: BorderSide.none,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              final newPw = resetCtrl.text.trim();
              if (newPw.length < 4) return;
              final email = _emailCtrl.text.trim().toLowerCase();
              MockAuthRepository.resetPassword(
                email: email,
                newPassword: newPw,
              );
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Password reset successfully'),
                  backgroundColor: Colors.black,
                  behavior: SnackBarBehavior.floating,
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Reset',
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

  // ── Delete ─────────────────────────────────────────────────────────────────

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove Staff Member'),
        content: Text(
          'Remove ${_previewFullName}? '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(staffListProvider.notifier).delete(widget.staffId!);
              context.go('/more/staff');
            },
            child: const Text(
              'Remove',
              style: TextStyle(color: Color(0xFFEF4444)),
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
        backgroundColor: Color(0xFFF9FAFB),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            _FormHeader(
              isEditing: widget.isEditing,
              onBack: () => Navigator.canPop(context)
                  ? Navigator.pop(context)
                  : widget.isEditing
                  ? context.go('/more/staff/${widget.staffId}')
                  : context.go('/more/staff'),
              onDelete: widget.isEditing ? _delete : null,
            ),
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

                    // ── Basic Information ──────────────────────────────────
                    const _SectionHeader(label: 'Basic Information'),
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
                              LengthLimitingTextInputFormatter(15),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'e.g. 9841001001',
                            ),
                            validator: (v) => (v == null || v.trim().isEmpty)
                                ? 'Phone number is required'
                                : null,
                          ),
                        ),
                        const _FieldDivider(),
                        _Field(
                          label: 'Email',
                          child: TextFormField(
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            readOnly: widget.isEditing,
                            style: TextStyle(
                              color: widget.isEditing
                                  ? const Color(0xFF6B7280)
                                  : Colors.black,
                            ),
                            decoration: InputDecoration(
                              hintText: 'e.g. priya@salon.com',
                              suffixIcon: widget.isEditing
                                  ? const Icon(
                                      Icons.lock_outline,
                                      size: 16,
                                      color: Color(0xFF9CA3AF),
                                    )
                                  : null,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return widget.isEditing
                                    ? null
                                    : 'Email is required';
                              }
                              if (!v.contains('@'))
                                return 'Enter a valid email';
                              if (!widget.isEditing &&
                                  MockAuthRepository.emailExists(v.trim())) {
                                return 'This email is already registered';
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
                              LengthLimitingTextInputFormatter(15),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'e.g. 9801234567',
                            ),
                          ),
                        ),
                        const _FieldDivider(),
                        _Field(
                          label: 'Emergency Contact Name',
                          child: TextFormField(
                            controller: _emergencyNameCtrl,
                            textCapitalization: TextCapitalization.words,
                            decoration: const InputDecoration(
                              hintText: 'e.g. Ram Thapa',
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
                                  color: Color(0xFF6B7280),
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
                                                : const Color(0xFFF3F4F6),
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                            border: Border.all(
                                              color: selected
                                                  ? Colors.black
                                                  : const Color(0xFFE5E7EB),
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
                                                  : const Color(0xFF374151),
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
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await ImagePickerSheet.show(
                                    context,
                                    title: 'Upload ID Photo',
                                  );
                                  if (picked != null)
                                    setState(() => _govIdImage = picked);
                                },
                                child: Container(
                                  width: double.infinity,
                                  height: _govIdImage != null ? 100 : 80,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFF9FAFB),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: const Color(0xFFE5E7EB),
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
                                              color: Color(0xFF9CA3AF),
                                            ),
                                            SizedBox(height: 6),
                                            Text(
                                              'Tap to upload photo',
                                              style: TextStyle(
                                                fontSize: 13,
                                                color: Color(0xFF6B7280),
                                              ),
                                            ),
                                            Text(
                                              'Camera or Gallery',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Color(0xFF9CA3AF),
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
                              hintText: 'e.g. 15',
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

                    // ── Specialties ───────────────────────────────────────
                    const _SectionHeader(label: 'Specialties'),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                              color: Color(0xFF6B7280),
                            ),
                          ),
                          value: _isActive,
                          onChanged: (v) => setState(() => _isActive = v),
                          activeThumbColor: Colors.white,
                          activeTrackColor: Colors.black,
                        ),
                      ],
                    ),

                    // ── Login Credentials ─────────────────────────────────
                    if (!widget.isEditing) ...[
                      const _SectionHeader(label: 'Login Credentials'),
                      _FormCard(
                        children: [
                          _Field(
                            label: 'Password',
                            child: TextFormField(
                              controller: _passwordCtrl,
                              obscureText: !_showPassword,
                              decoration: InputDecoration(
                                hintText: 'Min 4 characters',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showPassword
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                  onPressed: () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty)
                                  return 'Password is required';
                                if (v.length < 4)
                                  return 'At least 4 characters';
                                return null;
                              },
                            ),
                          ),
                          const _FieldDivider(),
                          _Field(
                            label: 'Confirm Password',
                            child: TextFormField(
                              controller: _confirmCtrl,
                              obscureText: !_showConfirm,
                              decoration: InputDecoration(
                                hintText: 'Re-enter password',
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _showConfirm
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 18,
                                    color: const Color(0xFF9CA3AF),
                                  ),
                                  onPressed: () => setState(
                                    () => _showConfirm = !_showConfirm,
                                  ),
                                ),
                              ),
                              validator: (v) {
                                if (v != _passwordCtrl.text) {
                                  return 'Passwords do not match';
                                }
                                return null;
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (widget.isEditing) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
                        child: OutlinedButton.icon(
                          onPressed: _resetPassword,
                          icon: const Icon(Icons.lock_reset_outlined, size: 17),
                          label: const Text('Reset Password'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF374151),
                            side: const BorderSide(color: Color(0xFFD1D5DB)),
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
                      _ActivitySection(staffId: widget.staffId!),
                    ],

                    // ── Danger zone (edit only) ───────────────────────────
                    if (widget.isEditing) ...[
                      const _SectionHeader(label: 'Danger Zone'),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: OutlinedButton(
                          onPressed: _delete,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
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
        color: const Color(0xFFF9FAFB),
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.of(context).padding.bottom + 12,
        ),
        child: _BigBtn(
          label: widget.isEditing ? 'Save Changes' : 'Add Staff Member',
          onTap: _save,
        ),
      ),
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _FormHeader extends StatelessWidget {
  const _FormHeader({
    required this.isEditing,
    required this.onBack,
    this.onDelete,
  });
  final bool isEditing;
  final VoidCallback onBack;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: onBack,
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
              color: Colors.black,
            ),
          ),
          const Spacer(),
          Text(
            isEditing ? 'Edit Staff' : 'New Staff Member',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          if (onDelete != null)
            GestureDetector(
              onTap: onDelete,
              child: const Icon(
                Icons.delete_outline,
                size: 22,
                color: Color(0xFFEF4444),
              ),
            )
          else
            const SizedBox(width: 22),
        ],
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                          color: Color(0xFF111827),
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
                            : const Color(0xFFD1D5DB),
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
                      color: Color(0xFF6B7280),
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
                color: const Color(0xFFEEF2FF),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${commission!.toStringAsFixed(0)}%',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF6366F1),
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
          color: selected ? Colors.black : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? Colors.white : const Color(0xFF374151),
          ),
        ),
      ),
    );
  }
}

// ─── Big black save button ────────────────────────────────────────────────────

class _BigBtn extends StatelessWidget {
  const _BigBtn({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onTap,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.black,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
        child: Text(
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
          color: Color(0xFF6B7280),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              color: Color(0xFF6B7280),
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
      color: Color(0xFFE5E7EB),
    );
  }
}

// ─── Activity section (edit mode) ────────────────────────────────────────────

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

// Stable mock data keyed by a hash of the staffId so each staff shows
// different numbers without needing a real backend.
List<_ActivityEntry> _mockActivity(String staffId) {
  final seed = staffId.codeUnits.fold(0, (s, c) => s + c);
  final services = [
    'Haircut',
    'Hair Color',
    'Facial',
    'Manicure',
    'Blow Dry',
    'Waxing',
    'Massage',
  ];
  final customers = [
    'Sita Rai',
    'Anita Gurung',
    'Bipana Thapa',
    'Nirmala KC',
    'Sabita Shrestha',
  ];
  final base = 800 + (seed % 600);
  return List.generate(5, (i) {
    final svc = services[(seed + i * 3) % services.length];
    final amt = (base + i * 150).toDouble();
    final rate = 10.0 + (seed % 3) * 5;
    return _ActivityEntry(
      date: i == 0
          ? 'Today'
          : i == 1
          ? 'Yesterday'
          : '${i + 1} days ago',
      service: svc,
      amount: amt,
      commission: amt * rate / 100,
      customer: customers[(seed + i) % customers.length],
    );
  });
}

class _ActivitySection extends StatelessWidget {
  const _ActivitySection({required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context) {
    final entries = _mockActivity(staffId);
    final totalSales = entries.fold(0.0, (s, e) => s + e.amount);
    final totalComm = entries.fold(0.0, (s, e) => s + e.commission);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          // Stats row
          Row(
            children: [
              Expanded(
                child: _StatBox(
                  label: 'This Week',
                  value: 'NPR ${totalSales.toStringAsFixed(0)}',
                  icon: Icons.trending_up_rounded,
                  iconColor: const Color(0xFF10B981),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  label: 'Commission',
                  value: 'NPR ${totalComm.toStringAsFixed(0)}',
                  icon: Icons.payments_outlined,
                  iconColor: const Color(0xFF6366F1),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StatBox(
                  label: 'Services',
                  value: '${entries.length}',
                  icon: Icons.spa_outlined,
                  iconColor: const Color(0xFFF59E0B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Recent transactions
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: const Color(0xFFE5E7EB)),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(16, 14, 16, 8),
                  child: Text(
                    'Recent Services',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFF3F4F6)),
                ...entries.map((e) => _ActivityTile(entry: e)),
              ],
            ),
          ),
        ],
      ),
    );
  }
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
            style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
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
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.spa_outlined,
              size: 18,
              color: Color(0xFF6B7280),
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
                    color: Color(0xFF9CA3AF),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'NPR ${entry.amount.toStringAsFixed(0)}',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '+NPR ${entry.commission.toStringAsFixed(0)} comm.',
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
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
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
