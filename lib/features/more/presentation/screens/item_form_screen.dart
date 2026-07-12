import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/inventory/data/inventory_repository.dart';
import '../../../../features/inventory/presentation/providers/inventory_provider.dart';

final _inventoryRepoProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.read(apiClientProvider)),
);

class ItemFormScreen extends ConsumerStatefulWidget {
  const ItemFormScreen({super.key, this.productId});
  final String? productId;

  bool get isEditing => productId != null;

  @override
  ConsumerState<ItemFormScreen> createState() => _ItemFormScreenState();
}

class _ItemFormScreenState extends ConsumerState<ItemFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _skuCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _costCtrl = TextEditingController();
  final _stockCtrl = TextEditingController(text: '0');
  final _thresholdCtrl = TextEditingController(text: '5');
  final _descCtrl = TextEditingController();
  final _categoryCtrl = TextEditingController();

  bool _isActive = true;
  bool _loading = false;


  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadProduct());
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _skuCtrl.dispose();
    _priceCtrl.dispose();
    _costCtrl.dispose();
    _stockCtrl.dispose();
    _thresholdCtrl.dispose();
    _descCtrl.dispose();
    _categoryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadProduct() async {
    try {
      final repo = ref.read(_inventoryRepoProvider);
      final product = await repo.getById(widget.productId!);
      if (!mounted) return;
      _nameCtrl.text = product.name;
      _skuCtrl.text = product.sku ?? '';
      _priceCtrl.text = product.price.toStringAsFixed(0);
      _costCtrl.text = product.cost?.toStringAsFixed(0) ?? '';
      _stockCtrl.text = product.stock.toString();
      _thresholdCtrl.text = product.lowStockThreshold.toString();
      _descCtrl.text = product.description ?? '';
      _categoryCtrl.text = product.category ?? '';
      setState(() {
        _isActive = product.isActive;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load item: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      final repo = ref.read(_inventoryRepoProvider);
      final price = double.parse(_priceCtrl.text.trim());
      final stock = int.tryParse(_stockCtrl.text.trim()) ?? 0;
      final cost = double.tryParse(_costCtrl.text.trim());
      final threshold = int.tryParse(_thresholdCtrl.text.trim()) ?? 5;
      final sku = _skuCtrl.text.trim().isEmpty ? null : _skuCtrl.text.trim();
      final desc = _descCtrl.text.trim().isEmpty ? null : _descCtrl.text.trim();
      final category =
          _categoryCtrl.text.trim().isEmpty ? null : _categoryCtrl.text.trim();

      if (widget.isEditing) {
        await repo.update(
          widget.productId!,
          name: _nameCtrl.text.trim(),
          price: price,
          stock: stock,
          cost: cost,
          sku: sku,
          description: desc,
          category: category,
          lowStockThreshold: threshold,
          isActive: _isActive,
        );
      } else {
        await repo.create(
          name: _nameCtrl.text.trim(),
          price: price,
          stock: stock,
          cost: cost,
          sku: sku,
          description: desc,
          category: category,
          lowStockThreshold: threshold,
          isActive: _isActive,
        );
      }

      ref.invalidate(productsProvider);
      if (mounted) context.go(AppRoutes.moreItems);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => context.go(AppRoutes.moreItems),
        ),
        title: Text(
          widget.isEditing ? 'Edit Item' : 'New Item',
          style: const TextStyle(
              fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const _SectionLabel(text: 'Basic Information'),
            _FormCard(children: [
              _Field(
                label: 'Item Name *',
                child: TextFormField(
                  controller: _nameCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(hintText: 'e.g. Shampoo 200ml'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Item name is required' : null,
                ),
              ),
              const _FieldDivider(),
              _Field(
                label: 'SKU / Barcode',
                child: TextFormField(
                  controller: _skuCtrl,
                  decoration:
                      const InputDecoration(hintText: 'e.g. SKU-001 (optional)'),
                ),
              ),
            ]),

            const SizedBox(height: 16),
            const _SectionLabel(text: 'Pricing'),
            _FormCard(children: [
              _Field(
                label: 'Selling Price (Rs) *',
                child: TextFormField(
                  controller: _priceCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  decoration: const InputDecoration(hintText: 'e.g. 500'),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'Price is required';
                    if (double.tryParse(v.trim()) == null) {
                      return 'Enter a valid price';
                    }
                    return null;
                  },
                ),
              ),
              const _FieldDivider(),
              _Field(
                label: 'Cost Price (Rs)',
                child: TextFormField(
                  controller: _costCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d{0,2}'))
                  ],
                  decoration:
                      const InputDecoration(hintText: 'e.g. 300 (optional)'),
                ),
              ),
            ]),

            const SizedBox(height: 16),
            const _SectionLabel(text: 'Inventory'),
            _FormCard(children: [
              _Field(
                label: 'Stock Quantity *',
                child: TextFormField(
                  controller: _stockCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: 'e.g. 20'),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? 'Stock is required' : null,
                ),
              ),
              const _FieldDivider(),
              _Field(
                label: 'Low Stock Threshold',
                child: TextFormField(
                  controller: _thresholdCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(hintText: '5'),
                ),
              ),
            ]),

            const SizedBox(height: 16),
            const _SectionLabel(text: 'Details'),
            _FormCard(children: [
              _Field(
                label: 'Category',
                child: TextFormField(
                  controller: _categoryCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                      hintText: 'e.g. Hair Care (optional)'),
                ),
              ),
              const _FieldDivider(),
              _Field(
                label: 'Description',
                child: TextFormField(
                  controller: _descCtrl,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration:
                      const InputDecoration(hintText: 'Optional description'),
                ),
              ),
            ]),

            if (widget.isEditing) ...[
              const SizedBox(height: 16),
              const _SectionLabel(text: 'Status'),
              _FormCard(children: [
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Active',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  subtitle: Text(
                    _isActive ? 'Visible in checkout' : 'Hidden from checkout',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                  activeThumbColor: Colors.black,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ]),
            ],

            const SizedBox(height: 100),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: GestureDetector(
            onTap: _loading ? null : _save,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                color: _loading ? Colors.black54 : Colors.black,
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: _loading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : Text(
                      widget.isEditing ? 'Save Changes' : 'Add Item',
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

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _FormCard extends StatelessWidget {
  const _FormCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
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

class _FieldDivider extends StatelessWidget {
  const _FieldDivider();

  @override
  Widget build(BuildContext context) => const Divider(
      height: 1, indent: 16, endIndent: 16, color: AppColors.divider);
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(text.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
                letterSpacing: 0.8)),
      );
}
