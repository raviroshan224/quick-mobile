import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/services/data/services_repository.dart';
import '../../../../features/services/domain/service_colors.dart';
import '../../../../features/services/domain/service_models.dart';
import '../../../../features/services/presentation/providers/services_provider.dart';
import '../../../../shared/widgets/image_picker_sheet.dart';

final _servicesRepoProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(ref.read(apiClientProvider)),
);

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
  final _descCtrl = TextEditingController();

  List<ServiceCategory> _categories = [];
  ServiceCategory? _selectedCategory;
  bool _isActive = true;
  bool _loading = true;
  ServiceModel? _original;
  PickedImage? _pickedImage;
  // Null means "auto" — checkout falls back to its deterministic per-
  // category color (see resolveServiceColor in service_colors.dart).
  String? _selectedColorKey;

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
        _descCtrl.text = s.description ?? '';
        setState(() {
          _categories = cats;
          _selectedCategory = cats.where((c) => c.id == s.category?.id).firstOrNull
              ?? (cats.isNotEmpty ? cats.first : null);
          _isActive = s.isActive;
          _selectedColorKey = s.color;
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
    final description = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
    final repo = ref.read(_servicesRepoProvider);

    try {
      if (widget.isEditing && _original != null) {
        await repo.update(
          _original!.id,
          name: _nameCtrl.text.trim(),
          price: price,
          description: description,
          categoryId: _selectedCategory?.id,
          color: _selectedColorKey,
          clearColor: _selectedColorKey == null,
          isActive: _isActive,
        );
      } else {
        await repo.create(
          name: _nameCtrl.text.trim(),
          price: price,
          duration: 0,
          description: description,
          categoryId: _selectedCategory?.id,
          color: _selectedColorKey,
          isActive: _isActive,
        );
      }
      ref.invalidate(servicesListProvider);
      ref.invalidate(serviceCategoriesListProvider);
      // The management list above and Checkout's Services tab read from two
      // separate providers (servicesListProvider fetches all services;
      // activeServicesProvider fetches only active ones) — without this, a
      // newly created/edited service shows up here immediately but stays
      // missing from checkout until something else happens to refetch it.
      ref.invalidate(activeServicesProvider);
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
                ref.invalidate(activeServicesProvider);
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
                                  'Rs ${previewPrice.toStringAsFixed(0)}',
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
                    _SectionLabel(text: 'PRICING'),
                    _Card(children: [
                      _Field(
                        label: 'Price (Rs) — optional',
                        child: TextFormField(
                          controller: _priceCtrl,
                          keyboardType: TextInputType.number,
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                          ],
                          decoration: const InputDecoration(
                            hintText: '0',
                            prefixText: 'Rs ',
                          ),
                          // Only the service name is required to create a
                          // service — an unset or blank price is saved as 0
                          // (ServicesService.create() on the backend applies
                          // the same default if this is ever omitted).
                        ),
                      ),
                    ]),

                    // ── Card Color ───────────────────────────────────────────
                    _SectionLabel(text: 'CARD COLOR'),
                    _Card(children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Shown on the Checkout services grid',
                              style: TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 12,
                              runSpacing: 12,
                              children: [
                                _ColorSwatchOption(
                                  selected: _selectedColorKey == null,
                                  onTap: () =>
                                      setState(() => _selectedColorKey = null),
                                  tooltip: 'Auto',
                                  child: const Icon(Icons.auto_awesome,
                                      size: 16, color: AppColors.textSecondary),
                                ),
                                ...kServiceColorPalette.map(
                                  (swatch) => _ColorSwatchOption(
                                    selected: _selectedColorKey == swatch.key,
                                    onTap: () => setState(
                                        () => _selectedColorKey = swatch.key),
                                    color: swatch.accent,
                                    tooltip: swatch.label,
                                  ),
                                ),
                              ],
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

// A single tappable swatch in the Card Color picker — either a solid color
// circle (one of kServiceColorPalette) or, for the "Auto" option, a plain
// circle holding [child] instead.
class _ColorSwatchOption extends StatelessWidget {
  const _ColorSwatchOption({
    required this.selected,
    required this.onTap,
    required this.tooltip,
    this.color,
    this.child,
  });
  final bool selected;
  final VoidCallback onTap;
  final String tooltip;
  final Color? color;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Tooltip(
        message: tooltip,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color ?? AppColors.surfaceVariant,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.black : AppColors.divider,
                width: selected ? 2 : 1,
              ),
            ),
            child: Center(
              child: child ??
                  (selected
                      ? const Icon(Icons.check, size: 16, color: Colors.white)
                      : null),
            ),
          ),
        ),
      );
}
