import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';

// ─── Data models ──────────────────────────────────────────────────────────────

enum _MovementType { stockIn, stockOut }

class _MockProduct {
  const _MockProduct({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
  });
  final String id;
  final String name;
  final String unit;
  final int stock;
}

// ─── Mock products ────────────────────────────────────────────────────────────

const _mockProducts = <_MockProduct>[
  _MockProduct(id: 'p1', name: 'Loreal Shampoo', unit: 'bottles', stock: 24),
  _MockProduct(id: 'p2', name: 'Pantene Conditioner', unit: 'bottles', stock: 12),
  _MockProduct(id: 'p3', name: 'Cutting Scissors', unit: 'pcs', stock: 5),
  _MockProduct(id: 'p4', name: 'Safety Razor Blade', unit: 'packs', stock: 3),
  _MockProduct(id: 'p5', name: 'Face Wash', unit: 'tubes', stock: 18),
  _MockProduct(id: 'p6', name: 'Hair Color', unit: 'sets', stock: 9),
];

// ─── Reason chips per movement type ──────────────────────────────────────────

const _stockInReasons = ['Purchase', 'Return', 'Adjustment'];
const _stockOutReasons = ['Damaged', 'Expired', 'Theft', 'Adjustment'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class StockMovementScreen extends StatefulWidget {
  const StockMovementScreen({super.key, this.productId});

  /// Pre-selects a product when navigating from a product detail screen.
  final String? productId;

  @override
  State<StockMovementScreen> createState() => _StockMovementScreenState();
}

class _StockMovementScreenState extends State<StockMovementScreen> {
  _MovementType _movementType = _MovementType.stockIn;
  _MockProduct? _selectedProduct;
  final TextEditingController _qtyCtrl = TextEditingController();
  final TextEditingController _reasonCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    if (widget.productId != null) {
      _selectedProduct = _mockProducts
          .where((p) => p.id == widget.productId)
          .firstOrNull;
    }
  }

  @override
  void dispose() {
    _qtyCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  int get _parsedQty => int.tryParse(_qtyCtrl.text.trim()) ?? 0;

  int get _newStock {
    if (_selectedProduct == null) return 0;
    final delta = _parsedQty;
    if (_movementType == _MovementType.stockIn) {
      return _selectedProduct!.stock + delta;
    } else {
      return (_selectedProduct!.stock - delta).clamp(0, 99999);
    }
  }

  List<String> get _reasonChips =>
      _movementType == _MovementType.stockIn ? _stockInReasons : _stockOutReasons;

  void _applyChip(String chip) {
    setState(() => _reasonCtrl.text = chip);
    _reasonCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _reasonCtrl.text.length));
  }

  void _openProductPicker() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ProductPickerSheet(
        products: _mockProducts,
        selected: _selectedProduct,
        onSelected: (product) {
          setState(() => _selectedProduct = product);
          Navigator.of(ctx).pop();
        },
      ),
    );
  }

  void _recordMovement() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedProduct == null) {
      _showError('Please select a product.');
      return;
    }
    final qty = _parsedQty;
    if (qty <= 0) {
      _showError('Quantity must be greater than 0.');
      return;
    }
    final reason = _reasonCtrl.text.trim();
    if (reason.isEmpty) {
      _showError('Please enter a reason.');
      return;
    }
    final newStock = _newStock;
    final product = _selectedProduct!;
    context.go(AppRoutes.more);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        'Stock updated — ${product.name} now has $newStock ${product.unit}',
      ),
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.black,
      duration: const Duration(seconds: 3),
    ));
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      backgroundColor: const Color(0xFFEF4444),
      duration: const Duration(seconds: 2),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final isStockIn = _movementType == _MovementType.stockIn;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ────────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(children: [
                GestureDetector(
                  onTap: () => context.go(AppRoutes.more),
                  child: const Icon(Icons.close_rounded,
                      size: 22, color: Colors.black),
                ),
                const Spacer(),
                const Text('Stock Movement',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                const SizedBox(width: 22),
              ]),
            ),
            const SizedBox(height: 20),

            // ── Form ──────────────────────────────────────────────────────────
            Expanded(
              child: Form(
                key: _formKey,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                  children: [
                    // ── Movement type toggle ─────────────────────────────────
                    _SectionLabel(text: 'Movement Type'),
                    const SizedBox(height: 8),
                    _MovementTypeToggle(
                      value: _movementType,
                      onChanged: (t) => setState(() => _movementType = t),
                    ),
                    const SizedBox(height: 20),

                    // ── Product selector ─────────────────────────────────────
                    _SectionLabel(text: 'Product'),
                    const SizedBox(height: 8),
                    GestureDetector(
                      onTap: _openProductPicker,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(children: [
                          Expanded(
                            child: _selectedProduct == null
                                ? const Text('Select a product',
                                    style: TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF9CA3AF)))
                                : Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _selectedProduct!.name,
                                        style: const TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.black),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Current stock: ${_selectedProduct!.stock} ${_selectedProduct!.unit}',
                                        style: const TextStyle(
                                            fontSize: 12,
                                            color: Color(0xFF6B7280)),
                                      ),
                                    ],
                                  ),
                          ),
                          const Icon(Icons.keyboard_arrow_down_rounded,
                              size: 20, color: Color(0xFF9CA3AF)),
                        ]),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // ── Quantity field ────────────────────────────────────────
                    _SectionLabel(text: 'Quantity'),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Enter quantity',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 14),
                        prefixIcon: Icon(
                          isStockIn
                              ? Icons.add_circle_outline_rounded
                              : Icons.remove_circle_outline_rounded,
                          size: 18,
                          color: isStockIn
                              ? const Color(0xFF10B981)
                              : const Color(0xFFEF4444),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.black, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Quantity is required';
                        }
                        final n = int.tryParse(v.trim());
                        if (n == null || n <= 0) {
                          return 'Enter a valid quantity greater than 0';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Reason field ──────────────────────────────────────────
                    _SectionLabel(
                      text: 'Reason',
                      subtitle: isStockIn
                          ? 'e.g. Purchase, Return'
                          : 'e.g. Damaged, Expired',
                    ),
                    const SizedBox(height: 8),
                    // Quick chips
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _reasonChips
                          .map((chip) => GestureDetector(
                                onTap: () => _applyChip(chip),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 150),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: _reasonCtrl.text == chip
                                        ? Colors.black
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(100),
                                    border: Border.all(
                                      color: _reasonCtrl.text == chip
                                          ? Colors.black
                                          : const Color(0xFFE5E7EB),
                                    ),
                                  ),
                                  child: Text(
                                    chip,
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w500,
                                      color: _reasonCtrl.text == chip
                                          ? Colors.white
                                          : const Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _reasonCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        hintText: 'Enter or select a reason above',
                        hintStyle: const TextStyle(
                            color: Color(0xFF9CA3AF), fontSize: 14),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide:
                              const BorderSide(color: Color(0xFFE5E7EB)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                              color: Colors.black, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 14),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Reason is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 20),

                    // ── Summary card ─────────────────────────────────────────
                    if (_selectedProduct != null && _parsedQty > 0)
                      _SummaryCard(
                        product: _selectedProduct!,
                        movementType: _movementType,
                        qty: _parsedQty,
                        newStock: _newStock,
                      ),
                    if (_selectedProduct != null && _parsedQty > 0)
                      const SizedBox(height: 20),

                    // ── Record button ─────────────────────────────────────────
                    GestureDetector(
                      onTap: _recordMovement,
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: Colors.black,
                          borderRadius: BorderRadius.circular(26),
                        ),
                        alignment: Alignment.center,
                        child: const Text('Record Movement',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 15,
                                fontWeight: FontWeight.w600)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Movement type toggle ──────────────────────────────────────────────────────

class _MovementTypeToggle extends StatelessWidget {
  const _MovementTypeToggle({
    required this.value,
    required this.onChanged,
  });
  final _MovementType value;
  final ValueChanged<_MovementType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        _ToggleButton(
          label: 'Stock In',
          icon: Icons.add_rounded,
          selected: value == _MovementType.stockIn,
          activeColor: const Color(0xFF10B981),
          onTap: () => onChanged(_MovementType.stockIn),
        ),
        const SizedBox(width: 4),
        _ToggleButton(
          label: 'Stock Out',
          icon: Icons.remove_rounded,
          selected: value == _MovementType.stockOut,
          activeColor: const Color(0xFFEF4444),
          onTap: () => onChanged(_MovementType.stockOut),
        ),
      ]),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool selected;
  final Color activeColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 16,
                  color: selected ? activeColor : const Color(0xFF9CA3AF)),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.black : const Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Product picker bottom sheet ──────────────────────────────────────────────

class _ProductPickerSheet extends StatelessWidget {
  const _ProductPickerSheet({
    required this.products,
    required this.selected,
    required this.onSelected,
  });
  final List<_MockProduct> products;
  final _MockProduct? selected;
  final ValueChanged<_MockProduct> onSelected;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.85,
      expand: false,
      builder: (ctx, scrollCtrl) => Column(
        children: [
          // Handle
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              Text('Select Product',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ]),
          ),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          Expanded(
            child: ListView.separated(
              controller: scrollCtrl,
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: products.length,
              separatorBuilder: (_, _) =>
                  const Divider(height: 1, color: Color(0xFFF3F4F6)),
              itemBuilder: (_, i) {
                final product = products[i];
                final isSelected = selected?.id == product.id;
                return InkWell(
                  onTap: () => onSelected(product),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                    child: Row(children: [
                      // Icon
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF3F4F6),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.inventory_2_outlined,
                            size: 18, color: Color(0xFF6B7280)),
                      ),
                      const SizedBox(width: 12),
                      // Name + stock
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(product.name,
                                style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600)),
                            const SizedBox(height: 2),
                            Text(
                              '${product.stock} ${product.unit} in stock',
                              style: TextStyle(
                                fontSize: 12,
                                color: product.stock <= 5
                                    ? const Color(0xFFF59E0B)
                                    : const Color(0xFF6B7280),
                                fontWeight: product.stock <= 5
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isSelected)
                        const Icon(Icons.check_circle_rounded,
                            size: 20, color: Colors.black),
                    ]),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.product,
    required this.movementType,
    required this.qty,
    required this.newStock,
  });
  final _MockProduct product;
  final _MovementType movementType;
  final int qty;
  final int newStock;

  @override
  Widget build(BuildContext context) {
    final isStockIn = movementType == _MovementType.stockIn;
    final accentColor =
        isStockIn ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final bgColor =
        isStockIn ? const Color(0xFFF0FDF4) : const Color(0xFFFFF1F2);
    final qtyText = isStockIn ? '+$qty' : '-$qty';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accentColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(
              isStockIn
                  ? Icons.trending_up_rounded
                  : Icons.trending_down_rounded,
              size: 16,
              color: accentColor,
            ),
            const SizedBox(width: 6),
            Text(
              isStockIn ? 'Stock In Preview' : 'Stock Out Preview',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: accentColor,
                letterSpacing: 0.3,
              ),
            ),
          ]),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Product', value: product.name),
          const SizedBox(height: 6),
          _SummaryRow(
            label: 'Change',
            value: '$qtyText ${product.unit}',
            valueColor: accentColor,
            valueBold: true,
          ),
          const SizedBox(height: 6),
          _SummaryRow(
            label: 'Current stock',
            value: '${product.stock} ${product.unit}',
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: Color(0xFFE5E7EB)),
          ),
          _SummaryRow(
            label: 'New stock total',
            value: '$newStock ${product.unit}',
            valueBold: true,
            valueColor: newStock <= 5
                ? const Color(0xFFF59E0B)
                : const Color(0xFF374151),
          ),
          if (newStock <= 5) ...[
            const SizedBox(height: 8),
            Row(children: [
              const Icon(Icons.warning_amber_rounded,
                  size: 14, color: Color(0xFFF59E0B)),
              const SizedBox(width: 4),
              Text(
                newStock == 0
                    ? 'This will leave the product out of stock.'
                    : 'Low stock warning after this movement.',
                style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFFF59E0B),
                    fontWeight: FontWeight.w500),
              ),
            ]),
          ],
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.valueBold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool valueBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label,
            style: const TextStyle(
                fontSize: 13, color: Color(0xFF6B7280))),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: valueBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text, this.subtitle});
  final String text;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(text,
            style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        if (subtitle != null) ...[
          const SizedBox(width: 6),
          Text(subtitle!,
              style: const TextStyle(
                  fontSize: 12, color: Color(0xFF9CA3AF))),
        ],
      ],
    );
  }
}
