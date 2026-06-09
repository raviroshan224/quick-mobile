import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/image_picker_sheet.dart';
import '../models/item_model.dart';
import '../providers/items_provider.dart';

class ItemFormScreen extends ConsumerStatefulWidget {
  final String? itemId;

  const ItemFormScreen({super.key, this.itemId});

  bool get isEditing => itemId != null;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController();
  final _thresholdCtrl = TextEditingController(text: '5');
  final _adjustCtrl = TextEditingController();

  PickedImage? _pickedImage;

  String _category = 'Hair Care';
  bool _isActive = true;
  bool _hasChanges = false;

  Item? _original;

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadItem());
    }
  }

  void _loadItem() {
    final items = ref.read(itemsProvider);
    final item = items.where((i) => i.id == widget.itemId).firstOrNull;
    if (item == null) return;
    _original = item;
    _nameCtrl.text = item.name;
    _skuCtrl.text = item.sku ?? '';
    _priceCtrl.text = item.price.toStringAsFixed(0);
    _costCtrl.text = item.costPrice?.toStringAsFixed(0) ?? '';
    _stockCtrl.text = item.stockQty.toString();
    _thresholdCtrl.text = item.lowStockThreshold.toString();
    setState(() {
      _category = item.category;
      _isActive = item.isActive;
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    _adjustCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePickerSheet.show(
      context,
      initialCategory: ImagePickerCategory.product,
      title: 'Pick Item Image',
    );
    if (picked != null) setState(() => _pickedImage = picked);
  }

  void _markChanged() {
    if (!_hasChanges) setState(() => _hasChanges = true);
  }

  void _save() {
    if (!_formKey.currentState!.validate()) return;
    final price = double.tryParse(_priceCtrl.text.trim()) ?? 0;
    final costPrice = _costCtrl.text.trim().isEmpty
        ? null
        : double.tryParse(_costCtrl.text.trim());
    final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
    final threshold = int.tryParse(_thresholdCtrl.text.trim()) ?? 5;

    if (widget.isEditing && _original != null) {
      ref.read(itemsProvider.notifier).update(
            _original!.copyWith(
              name: _nameCtrl.text.trim(),
              sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
              price: price,
              costPrice: costPrice,
              stockQty: stock,
              category: _category,
              lowStockThreshold: threshold,
              isActive: _isActive,
            ),
          );
    } else {
      ref.read(itemsProvider.notifier).add(
            Item.create(
              name: _nameCtrl.text.trim(),
              sku: _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim(),
              price: price,
              costPrice: costPrice,
              stockQty: stock,
              category: _category,
              lowStockThreshold: threshold,
              isActive: _isActive,
            ),
          );
    }
    context.pop();
  }

  void _delete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Item'),
        content: Text('Remove "${_nameCtrl.text}"? This cannot be undone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(itemsProvider.notifier).delete(widget.itemId!);
              context.pop();
            },
            child: const Text('Delete',
                style: TextStyle(color: AppColors.refund)),
          ),
        ],
      ),
    );
  }

  void _showAdjustSheet() {
    _adjustCtrl.clear();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const Expanded(
                  child: Text('Adjust Stock',
                      style: TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600))),
              IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx)),
            ]),
            const SizedBox(height: 4),
            Text(
              'Current stock: ${_stockCtrl.text} units',
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _adjustCtrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(signed: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
              ],
              decoration: const InputDecoration(
                labelText: 'Adjustment (e.g. +10 or -3)',
                hintText: 'Enter positive or negative number',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  final delta = int.tryParse(_adjustCtrl.text);
                  if (delta == null) return;
                  final current =
                      int.tryParse(_stockCtrl.text.trim()) ?? 0;
                  final newQty = (current + delta).clamp(0, 99999);
                  setState(() => _stockCtrl.text = newQty.toString());
                  _markChanged();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Apply Adjustment',
                    style: TextStyle(fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(widget.isEditing ? 'Edit Item' : 'New Item'),
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
        onChanged: _markChanged,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 40),
          children: [
            const SizedBox(height: 20),
            Center(
              child: GestureDetector(
                onTap: _pickImage,
                child: Stack(
                  children: [
                    Container(
                      width: 72,
                      height: 72,
                      decoration: BoxDecoration(
                        color: _pickedImage != null
                            ? _pickedImage!.color.withValues(alpha: 0.12)
                            : AppColors.primary.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        _pickedImage != null
                            ? _pickedImage!.iconData
                            : Icons.inventory_2_outlined,
                        size: 34,
                        color: _pickedImage != null
                            ? _pickedImage!.color
                            : AppColors.primary,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: const Icon(
                          Icons.photo_library_outlined,
                          size: 11,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            _SectionHeader(label: widget.isEditing ? 'Item Details' : 'Basic Info'),
            _FormCard(children: [
              _Field(
                label: 'Item Name',
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Keratin Shampoo'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
              ),
              const Divider(height: 1),
              _Field(
                label: 'Category',
                child: DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(),
                  items: itemCategories
                      .where((c) => c != 'All')
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) {
                    if (v != null) setState(() => _category = v);
                    _markChanged();
                  },
                ),
              ),
              const Divider(height: 1),
              _Field(
                label: 'SKU',
                child: TextFormField(
                  controller: _skuCtrl,
                  decoration:
                      const InputDecoration(hintText: 'Optional barcode/SKU'),
                ),
              ),
            ]),
            const _SectionHeader(label: 'Pricing'),
            _FormCard(children: [
              _Field(
                label: 'Selling Price (Rs)',
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration: const InputDecoration(hintText: '0'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Price is required';
                    if ((double.tryParse(v) ?? -1) < 0) return 'Enter a valid price';
                    return null;
                  },
                ),
              ),
              const Divider(height: 1),
              _Field(
                label: 'Cost Price (Rs)',
                child: TextFormField(
                  controller: _costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
                  ],
                  decoration:
                      const InputDecoration(hintText: 'Optional — for margin tracking'),
                ),
              ),
            ]),
            const _SectionHeader(label: 'Stock'),
            _FormCard(children: [
              _Field(
                label: 'Quantity in Stock',
                trailing: widget.isEditing
                    ? GestureDetector(
                        onTap: _showAdjustSheet,
                        child: const Text('Adjust',
                            style: TextStyle(
                                fontSize: 14,
                                color: AppColors.accent,
                                fontWeight: FontWeight.w500)),
                      )
                    : null,
                child: TextFormField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '0'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Required' : null,
                ),
              ),
              const Divider(height: 1),
              _Field(
                label: 'Low Stock Alert',
                child: TextFormField(
                  controller: _thresholdCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      const InputDecoration(hintText: 'Alert when stock reaches this'),
                ),
              ),
            ]),
            const _SectionHeader(label: 'Visibility'),
            _FormCard(children: [
              SwitchListTile.adaptive(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                title: const Text('Active',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w400)),
                subtitle: const Text(
                  'Active items appear in the checkout Library',
                  style:
                      TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                value: _isActive,
                onChanged: (v) {
                  setState(() => _isActive = v);
                  _markChanged();
                },
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
                      Text('Delete Item',
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

// ── Shared form helpers ───────────────────────────────────────────────────────

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
  final Widget? trailing;

  const _Field({required this.label, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 4),
          child,
        ],
      ),
    );
  }
}
