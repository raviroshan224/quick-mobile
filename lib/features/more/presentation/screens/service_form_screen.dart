import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/services/data/services_repository.dart';
import '../../../../features/services/domain/service_models.dart';
import '../../../../features/services/presentation/providers/services_provider.dart';
import '../../../../shared/widgets/image_picker_sheet.dart';

final _servicesRepoProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(ref.read(apiClientProvider)),
);

// ─── Quick duration presets ───────────────────────────────────────────────────

const _kDurations = [10, 15, 20, 30, 45, 60, 90, 120, 180, 240];

String _durationLabel(int minutes) {
  if (minutes < 60) return '${minutes}m';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

// ─── Category colors ──────────────────────────────────────────────────────────

const _kCatColors = {
  'cat-1': Color(0xFFE8EDD6), // olive-50
  'cat-2': Color(0xFFEEEEEB), // warm grey
  'cat-3': Color(0xFFD1FAE5), // green (keep semantic)
  'cat-4': Color(0xFFDCE0C8), // deeper olive
  'cat-5': Color(0xFFFFEDD5), // orange (keep warm)
};
const _kCatIcons = {
  'cat-1': Icons.content_cut_rounded,
  'cat-2': Icons.back_hand_outlined,
  'cat-3': Icons.face_retouching_natural,
  'cat-4': Icons.auto_awesome,
  'cat-5': Icons.self_improvement,
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class ServiceFormScreen extends ConsumerStatefulWidget {
  const ServiceFormScreen({super.key, this.serviceId});
  final String? serviceId;

  bool get isEditing => serviceId != null;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  List<ServiceCategory> _categories = [];
  ServiceCategory? _selectedCategory;
  bool _isActive = true;
  bool _loading = true;
  ServiceModel? _original;
  PickedImage? _pickedImage;

  @override
  void initState() {
    super.initState();
    _nameCtrl.addListener(() => setState(() {}));
    _priceCtrl.addListener(() => setState(() {}));
    _loadData();
  }

  Future<void> _loadData() async {
    final repo = ref.read(_servicesRepoProvider);
    try {
      final cats = await repo.getCategories();
      if (!mounted) return;

      if (widget.isEditing) {
        final s = await repo.getById(widget.serviceId!);
        if (!mounted) return;
        _original = s;
        _nameCtrl.text = s.name;
        _priceCtrl.text = s.price.toStringAsFixed(0);
        _durationCtrl.text = s.duration.toString();
        _descCtrl.text = s.description ?? '';
        setState(() {
          _categories = cats;
          _selectedCategory = cats.where((c) => c.id == s.category?.id).firstOrNull
              ?? (cats.isNotEmpty ? cats.first : null);
          _isActive = s.isActive;
          _loading = false;
        });
      } else {
        setState(() {
          _categories = cats;
          _loading = false;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  // ── Create Category ────────────────────────────────────────────────────────

  Future<void> _createCategory(BuildContext context) async {
    final ctrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Category'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'e.g. Hair Care, Skin, Nails',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    final name = ctrl.text.trim();
    if (name.isEmpty) return;
    try {
      final repo = ref.read(_servicesRepoProvider);
      final cat = await repo.createCategory(name);
      if (!mounted) return;
      setState(() {
        if (!_categories.any((c) => c.id == cat.id)) {
          _categories = [..._categories, cat];
        }
        _selectedCategory = cat;
      });
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  // ── Pick Image ─────────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    final picked = await ImagePickerSheet.show(
      context,
      initialCategory: ImagePickerCategory.service,
      title: 'Pick Service Icon',
    );
    if (picked != null) setState(() => _pickedImage = picked);
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 0;
    final description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    final repo = ref.read(_servicesRepoProvider);

    try {
      if (widget.isEditing && _original != null) {
        await repo.update(
          _original!.id,
          name: _nameCtrl.text.trim(),
          price: price,
          duration: duration,
          description: description,
          categoryId: _selectedCategory?.id,
          isActive: _isActive,
        );
      } else {
        await repo.create(
          name: _nameCtrl.text.trim(),
          price: price,
          duration: duration,
          description: description,
          categoryId: _selectedCategory?.id,
          isActive: _isActive,
        );
      }
      ref.invalidate(servicesListProvider);
      ref.invalidate(serviceCategoriesListProvider);
      if (mounted) context.go(AppRoutes.moreServices);
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
  }

  // ── Delete ─────────────────────────────────────────────────────────────────

  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Service'),
        content: Text('Delete "${_nameCtrl.text.trim()}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(_servicesRepoProvider).delete(widget.serviceId!);
                ref.invalidate(servicesListProvider);
                if (mounted) context.go(AppRoutes.moreServices);
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
                style: TextStyle(color: AppColors.danger)),
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

    final previewName = _nameCtrl.text.trim().isEmpty ? 'Service Name' : _nameCtrl.text.trim();
    final previewPrice = double.tryParse(_priceCtrl.text.trim());
    final catId = _selectedCategory?.id ?? '';
    final catColor = _kCatColors[catId] ?? AppColors.surfaceVariant;
    final catIcon = _kCatIcons[catId] ?? Icons.spa_outlined;

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
              : context.go(AppRoutes.moreServices),
        ),
        title: Text(
          widget.isEditing ? 'Edit Service' : 'New Service',
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
            // ── Form ──────────────────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 120),
                  children: [
                    // ── Preview card ───────────────────────────────────────
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border:
                              Border.all(color: AppColors.divider),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(children: [
                          GestureDetector(
                            onTap: _pickImage,
                            child: Stack(
                              children: [
                                Container(
                                  width: 46,
                                  height: 46,
                                  decoration: BoxDecoration(
                                    color: _pickedImage != null
                                        ? _pickedImage!.color.withValues(alpha: 0.15)
                                        : catColor,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: _pickedImage != null
                                      ? Icon(_pickedImage!.iconData,
                                          size: 24, color: _pickedImage!.color)
                                      : Icon(catIcon,
                                          size: 22, color: Colors.black54),
                                ),
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: Container(
                                    width: 18,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: Colors.black,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                          color: Colors.white, width: 1.5),
                                    ),
                                    child: const Icon(
                                        Icons.photo_library_outlined,
                                        size: 9,
                                        color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  previewName,
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: _nameCtrl.text.trim().isEmpty
                                        ? AppColors.textTertiary
                                        : Colors.black,
                                  ),
                                ),
                                if (_selectedCategory != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedCategory!.name,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: AppColors.textSecondary),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              if (previewPrice != null)
                                Text(
                                  'NPR ${previewPrice.toStringAsFixed(0)}',
                                  style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                              Container(
                                margin: const EdgeInsets.only(top: 3),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: _isActive
                                      ? const Color(0xFFDCFCE7)
                                      : AppColors.surfaceVariant,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _isActive
                                        ? const Color(0xFF16A34A)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ]),
                      ),
                    ),

                    // ── Details ────────────────────────────────────────────
                    _SectionLabel(text: 'SERVICE DETAILS'),
                    _Card(children: [
                      _Field(
                        label: 'Service Name',
                        child: TextFormField(
                          controller: _nameCtrl,
                          textCapitalization: TextCapitalization.words,
                          decoration: const InputDecoration(
                              hintText: 'e.g. Haircut (Women)'),
                          validator: (v) =>
                              (v == null || v.trim().isEmpty)
                                  ? 'Name is required'
                                  : null,
                        ),
                      ),
                      _Divider(),
                      _Field(
                        label: 'Category',
                        child: _loading
                            ? const Text('Loading…',
                                style: TextStyle(color: AppColors.textTertiary))
                            : Row(
                                children: [
                                  Expanded(
                                    child: _categories.isEmpty
                                        ? GestureDetector(
                                            onTap: () => _createCategory(context),
                                            child: const Text(
                                              'Tap + to add a category',
                                              style: TextStyle(color: AppColors.textTertiary),
                                            ),
                                          )
                                        : DropdownButtonFormField<ServiceCategory>(
                                            initialValue: _selectedCategory,
                                            isExpanded: true,
                                            decoration: const InputDecoration(
                                                border: InputBorder.none,
                                                contentPadding: EdgeInsets.zero,
                                                isDense: true),
                                            hint: const Text('Select category'),
                                            items: _categories
                                                .map((c) => DropdownMenuItem(
                                                      value: c,
                                                      child: Text(c.name),
                                                    ))
                                                .toList(),
                                            onChanged: (v) =>
                                                setState(() => _selectedCategory = v),
                                          ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _createCategory(context),
                                    child: const Padding(
                                      padding: EdgeInsets.only(left: 8),
                                      child: Icon(Icons.add_circle_outline,
                                          size: 20, color: AppColors.textSecondary),
                                    ),
                                  ),
                                ],
                              ),
                      ),
                      _Divider(),
                      _Field(
                        label: 'Description (optional)',
                        child: TextFormField(
                          controller: _descCtrl,
                          maxLines: 2,
                          textCapitalization:
                              TextCapitalization.sentences,
                          decoration: const InputDecoration(
                              hintText: 'Short description of the service'),
                        ),
                      ),
                    ]),

                    // ── Pricing ────────────────────────────────────────────
                    _SectionLabel(text: 'PRICING & DURATION'),
                    _Card(children: [
                      _Field(
                        label: 'Price (NPR)',
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: 'e.g. 500',
                            prefixText: 'NPR ',
                          ),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) {
                              return 'Price is required';
                            }
                            if ((double.tryParse(v) ?? 0) <= 0) {
                              return 'Enter a valid price';
                            }
                            return null;
                          },
                        ),
                      ),
                      _Divider(),
                      _Field(
                        label: 'Duration',
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _kDurations.map((d) {
                                final selected =
                                    _durationCtrl.text == d.toString();
                                return GestureDetector(
                                  onTap: () => setState(
                                      () => _durationCtrl.text = d.toString()),
                                  child: AnimatedContainer(
                                    duration:
                                        const Duration(milliseconds: 150),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 12, vertical: 7),
                                    decoration: BoxDecoration(
                                      color: selected
                                          ? Colors.black
                                          : AppColors.surfaceVariant,
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      _durationLabel(d),
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
                            const SizedBox(height: 10),
                            TextFormField(
                              controller: _durationCtrl,
                              keyboardType: TextInputType.number,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(3),
                              ],
                              decoration: const InputDecoration(
                                hintText: 'Optional — e.g. 30',
                                suffixText: 'min',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return null;
                                }
                                if ((int.tryParse(v) ?? 0) <= 0) {
                                  return 'Enter a valid duration';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ]),

                    // ── Status ─────────────────────────────────────────────
                    _SectionLabel(text: 'STATUS'),
                    _Card(children: [
                      SwitchListTile.adaptive(
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 4),
                        title: const Text('Active',
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w400)),
                        subtitle: Text(
                          _isActive
                              ? 'Service appears in checkout'
                              : 'Hidden from checkout & billing',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.textSecondary),
                        ),
                        value: _isActive,
                        onChanged: (v) => setState(() => _isActive = v),
                        activeThumbColor: Colors.white,
                        activeTrackColor: Colors.black,
                      ),
                    ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        color: AppColors.background,
        padding: EdgeInsets.fromLTRB(
            16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
        child: SizedBox(
          height: 52,
          child: ElevatedButton(
            onPressed: _save,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26)),
            ),
            child: Text(
              widget.isEditing ? 'Save Changes' : 'Add Service',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.8)),
      );
}

class _Card extends StatelessWidget {
  const _Card({required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(children: children),
      );
}

class _Field extends StatelessWidget {
  const _Field({required this.label, required this.child});
  final String label;
  final Widget child;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 5),
            child,
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 16, endIndent: 16, color: AppColors.divider);
}
