import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../image_library/presentation/providers/image_library_provider.dart';
import '../models/payment_mode_model.dart';
import '../providers/payment_modes_provider.dart';

class PaymentModeFormScreen extends ConsumerStatefulWidget {
  final String? paymentModeId;
  const PaymentModeFormScreen({super.key, this.paymentModeId});

  bool get isEditing => paymentModeId != null;

  @override
  ConsumerState<PaymentModeFormScreen> createState() => _PaymentModeFormScreenState();
}

class _PaymentModeFormScreenState extends ConsumerState<PaymentModeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();

  String? _qrImageUrl;
  bool _isActive = true;
  bool _uploading = false;
  bool _saving = false;
  bool _loadedExisting = false;
  PaymentMode? _original;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _loadExistingIfNeeded(List<PaymentMode> all) {
    if (_loadedExisting || !widget.isEditing) return;
    final m = all.where((m) => m.id == widget.paymentModeId).firstOrNull;
    if (m == null) return;
    _original = m;
    _nameCtrl.text = m.name;
    _qrImageUrl = m.qrImageUrl;
    _isActive = m.isActive;
    _loadedExisting = true;
  }

  Future<void> _pickAndUploadQr(ImageSource source) async {
    final picked = await ImagePicker().pickImage(source: source, imageQuality: 90);
    if (picked == null || !mounted) return;

    // QR codes are square and only the code itself matters — cropping
    // before upload (rather than uploading the raw photo, background and
    // all) is what makes the saved image actually look like a QR code
    // instead of a snapshot with a QR code somewhere in it.
    final cropped = await ImageCropper().cropImage(
      sourcePath: picked.path,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
      compressQuality: 90,
      uiSettings: [
        AndroidUiSettings(
          toolbarTitle: 'Crop QR Code',
          toolbarColor: Colors.black,
          toolbarWidgetColor: Colors.white,
          statusBarLight: true,
          activeControlsWidgetColor: AppColors.primary,
          initAspectRatio: CropAspectRatioPreset.square,
          lockAspectRatio: true,
        ),
        IOSUiSettings(
          title: 'Crop QR Code',
          aspectRatioLockEnabled: true,
          resetAspectRatioEnabled: false,
          aspectRatioPickerButtonHidden: true,
        ),
      ],
    );
    if (cropped == null || !mounted) return;

    setState(() => _uploading = true);
    try {
      final asset = await ref.read(imageLibraryRepoProvider).upload(
            file: XFile(cropped.path),
            type: 'PAYMENT_QR',
            name: _nameCtrl.text.trim().isEmpty ? 'Payment QR' : _nameCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _qrImageUrl = asset.url);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Upload failed: $e'),
        backgroundColor: AppColors.danger,
        behavior: SnackBarBehavior.floating,
      ));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadQr(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('Take a photo'),
              onTap: () {
                Navigator.pop(ctx);
                _pickAndUploadQr(ImageSource.camera);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_qrImageUrl == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Upload a QR code image'),
          backgroundColor: AppColors.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final name = _nameCtrl.text.trim();
      if (widget.isEditing && _original != null) {
        await ref.read(paymentModesProvider.notifier).updateMode(
              _original!.id,
              name: name,
              qrImageUrl: _qrImageUrl,
              isActive: _isActive,
            );
      } else {
        await ref.read(paymentModesProvider.notifier).createMode(
              name: name,
              qrImageUrl: _qrImageUrl!,
            );
      }
      if (mounted) context.pop();
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

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Payment Mode'),
        content: Text('Remove "${_nameCtrl.text}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(paymentModesProvider.notifier).deleteMode(widget.paymentModeId!);
                if (mounted) context.pop();
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
            child: const Text('Delete', style: TextStyle(color: AppColors.refund)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditing) {
      ref.watch(allPaymentModesProvider).whenData(_loadExistingIfNeeded);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black),
          onPressed: () => Navigator.canPop(context)
              ? Navigator.pop(context)
              : context.go(AppRoutes.morePaymentModes),
        ),
        title: Text(
          widget.isEditing ? 'Edit Payment Mode' : 'New Payment Mode',
          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
        actions: [
          if (widget.isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: AppColors.refund),
              onPressed: _delete,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 120),
          children: [
            const _SectionHeader(label: 'Details'),
            _FormCard(children: [
              _Field(
                label: 'Name',
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. eSewa, Fonepay'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
              ),
            ]),
            const _SectionHeader(label: 'QR Code'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: GestureDetector(
                onTap: _uploading ? null : _showImageSourcePicker,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: _uploading
                            ? const Center(child: CircularProgressIndicator())
                            : _qrImageUrl != null
                                ? ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: Image.network(
                                      _qrImageUrl!,
                                      fit: BoxFit.contain,
                                      errorBuilder: (_, _, _) => const Icon(
                                          Icons.broken_image_outlined,
                                          size: 40,
                                          color: AppColors.danger),
                                    ),
                                  )
                                : const Icon(Icons.qr_code_2_rounded,
                                    size: 56, color: AppColors.textTertiary),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _qrImageUrl != null ? 'Tap to change QR code' : 'Tap to upload QR code',
                        style: const TextStyle(fontSize: 13, color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.isEditing) ...[
              const _SectionHeader(label: 'Visibility'),
              _FormCard(children: [
                SwitchListTile.adaptive(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  title: const Text('Active',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w400)),
                  subtitle: const Text(
                    'Active payment modes appear at checkout',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ]),
            ],
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GestureDetector(
            onTap: _saving ? null : _save,
            child: Container(
              height: 52,
              decoration: BoxDecoration(
                color: _saving ? AppColors.border : Colors.black,
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : Text(
                      widget.isEditing ? 'Save Changes' : 'Add Payment Mode',
                      style: const TextStyle(
                          color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

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
        borderRadius: BorderRadius.circular(14),
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
                  fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
