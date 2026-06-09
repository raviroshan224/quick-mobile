import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/services/data/mock_services_repository.dart';
import '../../../../features/services/domain/service_models.dart';
import '../../../../shared/widgets/image_picker_sheet.dart';

// ─── Runtime service list provider ───────────────────────────────────────────

class _ServiceListNotifier extends StateNotifier<List<ServiceModel>> {
  _ServiceListNotifier() : super([]);

  void add(ServiceModel s) => state = [...state, s];

  void update(ServiceModel updated) {
    state = [for (final s in state) if (s.id == updated.id) updated else s];
  }

  void toggleActive(String id) {
    state = [
      for (final s in state)
        if (s.id == id) s.copyWith(isActive: !s.isActive) else s,
    ];
  }
}

final serviceListProvider =
    StateNotifierProvider<_ServiceListNotifier, List<ServiceModel>>(
  (_) => _ServiceListNotifier(),
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
  'cat-1': Color(0xFFDBEAFE),
  'cat-2': Color(0xFFFCE7F3),
  'cat-3': Color(0xFFD1FAE5),
  'cat-4': Color(0xFFEDE9FE),
  'cat-5': Color(0xFFFFEDD5),
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
    final repo = MockServicesRepository();
    final cats = await repo.getCategories();
    if (!mounted) return;

    if (widget.isEditing) {
      try {
        // Check runtime list first, then fall back to mock repo
        final runtime = ref.read(serviceListProvider);
        ServiceModel? s = runtime.where((x) => x.id == widget.serviceId).firstOrNull;
        s ??= await repo.getService(widget.serviceId!);
        if (!mounted) return;
        _original = s;
        _nameCtrl.text = s!.name;
        _priceCtrl.text = s.price.toStringAsFixed(0);
        _durationCtrl.text = s.duration.toString();
        _descCtrl.text = s.description ?? '';
        setState(() {
          _categories = cats;
          _selectedCategory = cats.firstWhere(
            (c) => c.id == s!.category?.id,
            orElse: () => cats.first,
          );
          _isActive = s!.isActive;
          _loading = false;
        });
      } catch (_) {
        setState(() {
          _categories = cats;
          _loading = false;
        });
      }
    } else {
      setState(() {
        _categories = cats;
        _loading = false;
      });
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

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 30;

    if (widget.isEditing && _original != null) {
      final updated = _original!.copyWith(
        name: _nameCtrl.text.trim(),
        price: price,
        duration: duration,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _selectedCategory,
        isActive: _isActive,
      );
      ref.read(serviceListProvider.notifier).update(updated);
      context.go(AppRoutes.moreServices);
    } else {
      final newService = ServiceModel(
        id: 'svc-${DateTime.now().millisecondsSinceEpoch}',
        name: _nameCtrl.text.trim(),
        price: price,
        duration: duration,
        description: _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim(),
        category: _selectedCategory,
        isActive: _isActive,
      );
      ref.read(serviceListProvider.notifier).add(newService);
      context.go(AppRoutes.moreServices);
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
            onPressed: () {
              Navigator.pop(ctx);
              context.go(AppRoutes.moreServices);
            },
            child: const Text('Delete',
                style: TextStyle(color: Color(0xFFEF4444))),
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

    final previewName = _nameCtrl.text.trim().isEmpty ? 'Service Name' : _nameCtrl.text.trim();
    final previewPrice = double.tryParse(_priceCtrl.text.trim());
    final catId = _selectedCategory?.id ?? '';
    final catColor = _kCatColors[catId] ?? const Color(0xFFF3F4F6);
    final catIcon = _kCatIcons[catId] ?? Icons.spa_outlined;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.canPop(context)
                      ? Navigator.pop(context)
                      : context.go(AppRoutes.moreServices),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.black),
                ),
                const Spacer(),
                Text(
                  widget.isEditing ? 'Edit Service' : 'New Service',
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.isEditing)
                  GestureDetector(
                    onTap: _confirmDelete,
                    child: const Icon(Icons.delete_outline,
                        size: 22, color: Color(0xFFEF4444)),
                  )
                else
                  const SizedBox(width: 22),
              ]),
            ),

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
                              Border.all(color: const Color(0xFFE5E7EB)),
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
                                        ? const Color(0xFF9CA3AF)
                                        : Colors.black,
                                  ),
                                ),
                                if (_selectedCategory != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _selectedCategory!.name,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        color: Color(0xFF6B7280)),
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
                                      : const Color(0xFFF3F4F6),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  _isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: _isActive
                                        ? const Color(0xFF16A34A)
                                        : const Color(0xFF6B7280),
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
                        child: _categories.isEmpty
                            ? const Text('Loading…',
                                style: TextStyle(color: Color(0xFF9CA3AF)))
                            : DropdownButtonFormField<ServiceCategory>(
                                initialValue: _selectedCategory,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                    border: InputBorder.none,
                                    contentPadding: EdgeInsets.zero),
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
                                          : const Color(0xFFF3F4F6),
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
                                            : const Color(0xFF374151),
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
                                hintText: 'Or type custom minutes',
                                suffixText: 'min',
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) {
                                  return 'Duration is required';
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
                              fontSize: 12, color: Color(0xFF6B7280)),
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
        color: const Color(0xFFF9FAFB),
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
                color: Color(0xFF6B7280),
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
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                    color: Color(0xFF6B7280))),
            const SizedBox(height: 5),
            child,
          ],
        ),
      );
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 16, endIndent: 16, color: Color(0xFFE5E7EB));
}
