import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../services/models/service_model.dart';
import '../../services/providers/services_provider.dart';
import '../models/discount_model.dart';
import '../providers/discounts_provider.dart';

class DiscountFormScreen extends ConsumerStatefulWidget {
  final String? discountId;
  const DiscountFormScreen({super.key, this.discountId});

  bool get isEditing => discountId != null;

  @override
  ConsumerState<DiscountFormScreen> createState() =>
      _DiscountFormScreenState();
}

class _DiscountFormScreenState extends ConsumerState<DiscountFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _valueCtrl = TextEditingController();

  DiscountType _type = DiscountType.percentage;
  bool _isActive = true;
  DiscountScope _scope = DiscountScope.all;
  String? _selectedCategory;
  String? _selectedServiceId;
  String? _selectedServiceName;

  Discount? _original;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    }
  }

  void _load() {
    final d = ref
        .read(discountsProvider)
        .where((d) => d.id == widget.discountId)
        .firstOrNull;
    if (d == null) return;
    _original = d;
    _nameCtrl.text = d.name;
    _valueCtrl.text =
        d.value.toStringAsFixed(d.value % 1 == 0 ? 0 : 2);
    setState(() {
      _type = d.type;
      _isActive = d.isActive;
      _scope = d.scope;
      _selectedCategory = d.categoryName;
      _selectedServiceId = d.serviceId;
      _selectedServiceName = d.serviceName;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  bool _scopeIsValid() {
    if (_scope == DiscountScope.category && _selectedCategory == null) {
      return false;
    }
    if (_scope == DiscountScope.service && _selectedServiceId == null) {
      return false;
    }
    return true;
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    if (!_scopeIsValid()) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_scope == DiscountScope.category
              ? 'Please select a service category'
              : 'Please select a service'),
          backgroundColor: AppColors.refund,
        ),
      );
      return;
    }
    final value = double.tryParse(_valueCtrl.text.trim()) ?? 0;

    if (widget.isEditing && _original != null) {
      ref.read(discountsProvider.notifier).update(
            _original!.copyWith(
              name: _nameCtrl.text.trim(),
              type: _type,
              value: value,
              isActive: _isActive,
              scope: _scope,
              categoryName: _selectedCategory,
              serviceId: _selectedServiceId,
              serviceName: _selectedServiceName,
            ),
          );
    } else {
      ref.read(discountsProvider.notifier).add(
            Discount.create(
              name: _nameCtrl.text.trim(),
              type: _type,
              value: value,
              isActive: _isActive,
              scope: _scope,
              categoryName: _selectedCategory,
              serviceId: _selectedServiceId,
              serviceName: _selectedServiceName,
            ),
          );
    }
    context.pop();
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Discount'),
        content:
            Text('Remove "${_nameCtrl.text}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              final applied = ref.read(checkoutDiscountProvider);
              if (applied?.id == widget.discountId) {
                ref.read(checkoutDiscountProvider.notifier).state = null;
              }
              ref
                  .read(discountsProvider.notifier)
                  .delete(widget.discountId!);
              context.pop();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.refund)),
          ),
        ],
      ),
    );
  }

  void _pickService(BuildContext context) {
    final services = ref
        .read(servicesProvider)
        .where((s) => s.isActive)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ServicePickerSheet(
        services: services,
        selectedId: _selectedServiceId,
        onSelected: (s) {
          setState(() {
            _selectedServiceId = s.id;
            _selectedServiceName = s.name;
          });
        },
      ),
    );
  }

  String get _valueSuffix =>
      _type == DiscountType.percentage ? '%' : 'Rs';
  String get _valueHint =>
      _type == DiscountType.percentage ? 'e.g. 10' : 'e.g. 100';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Discount' : 'New Discount'),
        actions: [
          if (widget.isEditing)
            IconButton(
              icon:
                  const Icon(Icons.delete_outline, color: AppColors.refund),
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
            // ── Live preview ──────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
              child: _PreviewCard(
                name: _nameCtrl.text.isEmpty
                    ? 'Discount Name'
                    : _nameCtrl.text,
                type: _type,
                value: double.tryParse(_valueCtrl.text) ?? 0,
                isActive: _isActive,
                scopeLabel: _currentScopeLabel(),
              ),
            ),

            // ── Name ──────────────────────────────────────────────────────
            const _SectionHeader(label: 'Details'),
            _FormCard(children: [
              _Field(
                label: 'Discount Name',
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Hair 10% Off, Facial Special'),
                  onChanged: (_) => setState(() {}),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Name is required'
                      : null,
                ),
              ),
            ]),

            // ── Type toggle ───────────────────────────────────────────────
            const _SectionHeader(label: 'Discount Type'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _TypeToggle(
                selected: _type,
                onChanged: (t) => setState(() => _type = t),
              ),
            ),

            // ── Value ─────────────────────────────────────────────────────
            const _SectionHeader(label: 'Value'),
            _FormCard(children: [
              _Field(
                label: _type == DiscountType.percentage
                    ? 'Percentage (%)'
                    : 'Fixed Amount (Rs)',
                child: TextFormField(
                  controller: _valueCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                        RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: InputDecoration(
                    hintText: _valueHint,
                    suffixText: _valueSuffix,
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Value is required';
                    }
                    final n = double.tryParse(v);
                    if (n == null || n <= 0) return 'Enter a valid value';
                    if (_type == DiscountType.percentage && n > 100) {
                      return 'Percentage cannot exceed 100';
                    }
                    return null;
                  },
                ),
              ),
            ]),

            // ── Applies To ────────────────────────────────────────────────
            const _SectionHeader(label: 'Applies To'),
            _FormCard(children: [
              _ScopeTile(
                title: 'All services & items',
                subtitle: 'Applied to the full cart subtotal',
                icon: Icons.all_inclusive,
                isSelected: _scope == DiscountScope.all,
                onTap: () => setState(() {
                  _scope = DiscountScope.all;
                  _selectedCategory = null;
                  _selectedServiceId = null;
                  _selectedServiceName = null;
                }),
              ),
              const Divider(height: 1, indent: 56),
              _ScopeTile(
                title: 'Service category',
                subtitle: 'Applies only to services in a category',
                icon: Icons.category_outlined,
                isSelected: _scope == DiscountScope.category,
                onTap: () => setState(() {
                  _scope = DiscountScope.category;
                  _selectedServiceId = null;
                  _selectedServiceName = null;
                }),
              ),
              // Category dropdown — shown when category scope is selected
              if (_scope == DiscountScope.category)
                _CategoryDropdown(
                  selected: _selectedCategory,
                  onChanged: (v) =>
                      setState(() => _selectedCategory = v),
                ),
              const Divider(height: 1, indent: 56),
              _ScopeTile(
                title: 'Specific service',
                subtitle: 'Applies to one service only',
                icon: Icons.design_services_outlined,
                isSelected: _scope == DiscountScope.service,
                onTap: () => setState(() {
                  _scope = DiscountScope.service;
                  _selectedCategory = null;
                }),
              ),
              // Service picker — shown when service scope is selected
              if (_scope == DiscountScope.service)
                _ServicePickerTile(
                  serviceName: _selectedServiceName,
                  onTap: () => _pickService(context),
                ),
            ]),

            // ── Visibility ────────────────────────────────────────────────
            const _SectionHeader(label: 'Visibility'),
            _FormCard(children: [
              SwitchListTile.adaptive(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Active',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w400)),
                subtitle: const Text(
                  'Active discounts appear in the checkout Library tab',
                  style: TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _isActive,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ]),

            // ── Delete ────────────────────────────────────────────────────
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
                      Text('Delete Discount',
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

  String _currentScopeLabel() {
    switch (_scope) {
      case DiscountScope.all:
        return 'All services & items';
      case DiscountScope.category:
        return _selectedCategory != null
            ? '$_selectedCategory category'
            : 'Select category…';
      case DiscountScope.service:
        return _selectedServiceName ?? 'Select service…';
    }
  }
}

// ── Scope tile ────────────────────────────────────────────────────────────────

class _ScopeTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _ScopeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon,
                size: 22,
                color: isSelected
                    ? AppColors.accent
                    : AppColors.textSecondary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: isSelected
                              ? AppColors.textPrimary
                              : AppColors.textPrimary)),
                  Text(subtitle,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary)),
                ],
              ),
            ),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                    color: isSelected
                        ? AppColors.accent
                        : AppColors.textTertiary,
                    width: 2),
                color:
                    isSelected ? AppColors.accent : Colors.transparent,
              ),
              child: isSelected
                  ? const Icon(Icons.check,
                      size: 12, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Category dropdown (shown under category scope tile) ───────────────────────

class _CategoryDropdown extends StatelessWidget {
  final String? selected;
  final ValueChanged<String?> onChanged;

  const _CategoryDropdown(
      {required this.selected, required this.onChanged});

  static const _categories = [
    'Hair',
    'Color',
    'Facial',
    'Spa',
    'Nails',
    'Massage',
    'Wax',
    'Other',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(52, 0, 16, 12),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: selected,
          isExpanded: true,
          hint: const Text('Select category',
              style: TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
          items: _categories
              .map((c) => DropdownMenuItem(
                    value: c,
                    child: Text(c,
                        style: const TextStyle(fontSize: 14)),
                  ))
              .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
}

// ── Service picker tile (shown under service scope tile) ──────────────────────

class _ServicePickerTile extends StatelessWidget {
  final String? serviceName;
  final VoidCallback onTap;

  const _ServicePickerTile(
      {required this.serviceName, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.fromLTRB(52, 0, 16, 12),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                serviceName ?? 'Select service…',
                style: TextStyle(
                  fontSize: 14,
                  color: serviceName != null
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Service picker bottom sheet ───────────────────────────────────────────────

class _ServicePickerSheet extends StatefulWidget {
  final List<Service> services;
  final String? selectedId;
  final ValueChanged<Service> onSelected;

  const _ServicePickerSheet({
    required this.services,
    required this.selectedId,
    required this.onSelected,
  });

  @override
  State<_ServicePickerSheet> createState() => _ServicePickerSheetState();
}

class _ServicePickerSheetState extends State<_ServicePickerSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = widget.services
        .where((s) =>
            _query.isEmpty ||
            s.name.toLowerCase().contains(_query) ||
            s.category.toLowerCase().contains(_query))
        .toList();

    return Padding(
      padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          const SizedBox(height: 8),
          Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: AppColors.divider,
                  borderRadius: BorderRadius.circular(2))),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
            child: Row(
              children: [
                const Expanded(
                  child: Text('Select Service',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: TextField(
              controller: _searchCtrl,
              autofocus: true,
              onChanged: (v) => setState(() => _query = v.toLowerCase()),
              decoration: const InputDecoration(
                hintText: 'Search services…',
                prefixIcon: Icon(Icons.search,
                    size: 18, color: AppColors.textTertiary),
              ),
            ),
          ),
          const Divider(height: 1),
          // List
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.45,
            ),
            child: filtered.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(
                      child: Text('No services found',
                          style: TextStyle(color: AppColors.textSecondary)),
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: filtered.length,
                    separatorBuilder: (context, i) =>
                        const Divider(height: 1, indent: 16),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      final isSelected = s.id == widget.selectedId;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(s.name,
                            style: const TextStyle(fontSize: 15)),
                        subtitle: Text(
                            '${s.category} · ${s.durationLabel} · Rs ${s.price.toStringAsFixed(0)}',
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle,
                                color: AppColors.accent)
                            : null,
                        onTap: () {
                          widget.onSelected(s);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

// ── Live preview card ─────────────────────────────────────────────────────────

class _PreviewCard extends StatelessWidget {
  final String name;
  final DiscountType type;
  final double value;
  final bool isActive;
  final String scopeLabel;

  const _PreviewCard({
    required this.name,
    required this.type,
    required this.value,
    required this.isActive,
    required this.scopeLabel,
  });

  @override
  Widget build(BuildContext context) {
    final color = isActive ? AppColors.success : AppColors.textTertiary;
    final valueLabel = type == DiscountType.percentage
        ? '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}%'
        : 'Rs ${value.toStringAsFixed(0)}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        border: Border.all(color: color.withValues(alpha: 0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Center(
              child: Icon(
                type == DiscountType.percentage
                    ? Icons.percent
                    : Icons.currency_rupee,
                size: 22,
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  scopeLabel,
                  style: TextStyle(fontSize: 12, color: color),
                ),
              ],
            ),
          ),
          Text(valueLabel,
              style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: color)),
        ],
      ),
    );
  }
}

// ── Type toggle ───────────────────────────────────────────────────────────────

class _TypeToggle extends StatelessWidget {
  final DiscountType selected;
  final ValueChanged<DiscountType> onChanged;

  const _TypeToggle({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
          color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          _TypeOption(
            label: 'Percentage',
            icon: Icons.percent,
            isSelected: selected == DiscountType.percentage,
            onTap: () => onChanged(DiscountType.percentage),
          ),
          _TypeOption(
            label: 'Fixed Amount',
            icon: Icons.currency_rupee,
            isSelected: selected == DiscountType.fixed,
            onTap: () => onChanged(DiscountType.fixed),
          ),
        ],
      ),
    );
  }
}

class _TypeOption extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _TypeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(7),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 4,
                        offset: const Offset(0, 1))
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: isSelected
                      ? AppColors.textPrimary
                      : AppColors.textSecondary),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected
                          ? FontWeight.w600
                          : FontWeight.w400,
                      color: isSelected
                          ? AppColors.textPrimary
                          : AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Shared form helpers ───────────────────────────────────────────────────────

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
