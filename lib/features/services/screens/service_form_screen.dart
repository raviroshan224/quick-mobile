import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/service_model.dart';
import '../providers/services_provider.dart';

class ServiceFormScreen extends ConsumerStatefulWidget {
  final String? serviceId;

  const ServiceFormScreen({super.key, this.serviceId});

  bool get isEditing => serviceId != null;

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '30');
  final _descCtrl = TextEditingController();

  String _category = 'Hair';
  bool _isActive = true;
  bool _isTopService = false;

  Service? _original;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadService());
    }
  }

  void _loadService() {
    final services = ref.read(servicesProvider);
    final service =
        services.where((s) => s.id == widget.serviceId).firstOrNull;
    if (service == null) return;
    _original = service;
    _nameCtrl.text = service.name;
    _priceCtrl.text = service.price.toStringAsFixed(0);
    _durationCtrl.text = service.durationMinutes.toString();
    _descCtrl.text = service.description ?? '';
    setState(() {
      _category = service.category;
      _isActive = service.isActive;
      _isTopService = service.isTopService;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final duration = int.tryParse(_durationCtrl.text.trim()) ?? 30;

    if (widget.isEditing && _original != null) {
      ref.read(servicesProvider.notifier).update(
            _original!.copyWith(
              name: _nameCtrl.text.trim(),
              price: price,
              durationMinutes: duration,
              category: _category,
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              isActive: _isActive,
              isTopService: _isTopService,
            ),
          );
    } else {
      ref.read(servicesProvider.notifier).add(
            Service.create(
              name: _nameCtrl.text.trim(),
              price: price,
              durationMinutes: duration,
              category: _category,
              description: _descCtrl.text.trim().isEmpty
                  ? null
                  : _descCtrl.text.trim(),
              isActive: _isActive,
              isTopService: _isTopService,
            ),
          );
    }
    context.pop();
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Service'),
        content:
            Text('Remove "${_nameCtrl.text}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref
                  .read(servicesProvider.notifier)
                  .delete(widget.serviceId!);
              context.pop();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.refund)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Service' : 'New Service'),
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
            const _SectionHeader(label: 'Service Details'),
            _FormCard(children: [
              _Field(
                label: 'Service Name',
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Haircut & Blow Dry'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                ),
              ),
              const Divider(height: 1),
              _Field(
                label: 'Category',
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(),
                  items: serviceCategories
                      .where((c) => c != 'All')
                      .map((c) =>
                          DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                  },
                ),
              ),
              const Divider(height: 1),
              _Field(
                label: 'Description',
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                      hintText: 'Optional description for staff or receipts'),
                ),
              ),
            ]),
            const _SectionHeader(label: 'Pricing & Duration'),
            _FormCard(children: [
              _Field(
                label: 'Price (Rs)',
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                      decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(hintText: '0'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Price is required';
                    }
                    if ((double.tryParse(v) ?? -1) < 0) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                ),
              ),
              const Divider(height: 1),
              _Field(
                label: 'Duration (minutes)',
                child: TextFormField(
                  controller: _durationCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '30'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Required';
                    final n = int.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a valid duration';
                    return null;
                  },
                ),
              ),
            ]),
            const _SectionHeader(label: 'Visibility'),
            _FormCard(children: [
              SwitchListTile.adaptive(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Active',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w400)),
                subtitle: const Text(
                  'Active services appear in All Services tab during checkout',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
              const Divider(height: 1, indent: 16),
              SwitchListTile.adaptive(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Quick Access',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w400)),
                subtitle: const Text(
                  'Pinned to the top strip in the checkout Library tab',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _isTopService,
                onChanged: (v) => setState(() => _isTopService = v),
              ),
            ]),
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
                      Text('Delete Service',
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

// ── Shared form helpers (mirrors item_form_screen.dart) ───────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

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
            color: AppColors.textSecondary),
      ),
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
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary),
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
