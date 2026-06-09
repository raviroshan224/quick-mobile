import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

// ─── Manual Discount State ────────────────────────────────────────────────────

enum ManualDiscountType { fixed, percentage }

class ManualDiscount {
  final ManualDiscountType type;
  final double value;

  const ManualDiscount({required this.type, required this.value});

  /// Calculate the actual discount amount from a subtotal.
  double apply(double subtotal) {
    if (type == ManualDiscountType.percentage) {
      final amount = subtotal * value / 100;
      return amount > subtotal ? subtotal : amount;
    }
    return value > subtotal ? subtotal : value;
  }

  String get label {
    if (type == ManualDiscountType.percentage) {
      return '${value.toStringAsFixed(value % 1 == 0 ? 0 : 1)}% off';
    }
    return 'Rs ${value.toStringAsFixed(0)} off';
  }
}

/// Provider for the manually applied discount on the checkout.
final manualDiscountProvider = StateProvider<ManualDiscount?>((ref) => null);

// ─── Manual Discount Bottom Sheet ─────────────────────────────────────────────

class ManualDiscountSheet extends HookConsumerWidget {
  const ManualDiscountSheet({super.key, required this.subtotal});
  final double subtotal;

  static Future<void> show(BuildContext context, {required double subtotal}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ManualDiscountSheet(subtotal: subtotal),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedType = useState(ManualDiscountType.fixed);
    final valueCtrl = useTextEditingController();
    final errorText = useState<String?>(null);
    final current = ref.watch(manualDiscountProvider);

    // Pre-fill if there's an existing discount
    useEffect(() {
      if (current != null) {
        selectedType.value = current.type;
        valueCtrl.text = current.value.toStringAsFixed(
          current.value % 1 == 0 ? 0 : 2,
        );
      }
      return null;
    }, []);

    void applyDiscount() {
      final val = double.tryParse(valueCtrl.text.trim());
      if (val == null || val <= 0) {
        errorText.value = 'Enter a valid amount';
        return;
      }
      if (selectedType.value == ManualDiscountType.percentage && val > 100) {
        errorText.value = 'Percentage cannot exceed 100%';
        return;
      }
      if (selectedType.value == ManualDiscountType.fixed && val > subtotal) {
        errorText.value =
            'Discount cannot exceed subtotal (Rs ${subtotal.toStringAsFixed(0)})';
        return;
      }
      errorText.value = null;
      ref.read(manualDiscountProvider.notifier).state = ManualDiscount(
        type: selectedType.value,
        value: val,
      );
      Navigator.pop(context);
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
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
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22),
                ),
                const Spacer(),
                const Text(
                  'Add Discount',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                const SizedBox(width: 22),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Subtotal display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF9FAFB),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Row(
                    children: [
                      const Text(
                        'Subtotal',
                        style: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Rs ${subtotal.toStringAsFixed(0)}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Type toggle
                const Text(
                  'Discount Type',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      _TypeOption(
                        label: 'Fixed Amount',
                        icon: Icons.currency_rupee,
                        isSelected:
                            selectedType.value == ManualDiscountType.fixed,
                        onTap: () =>
                            selectedType.value = ManualDiscountType.fixed,
                      ),
                      _TypeOption(
                        label: 'Percentage',
                        icon: Icons.percent,
                        isSelected:
                            selectedType.value == ManualDiscountType.percentage,
                        onTap: () =>
                            selectedType.value = ManualDiscountType.percentage,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Value input
                Text(
                  selectedType.value == ManualDiscountType.fixed
                      ? 'Amount (Rs)'
                      : 'Percentage (%)',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF6B7280),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: valueCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d*\.?\d{0,2}'),
                    ),
                  ],
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: selectedType.value == ManualDiscountType.fixed
                        ? 'e.g. 100'
                        : 'e.g. 10',
                    suffixText: selectedType.value == ManualDiscountType.fixed
                        ? 'Rs'
                        : '%',
                    errorText: errorText.value,
                  ),
                ),
                const SizedBox(height: 20),

                // Preview
                if (valueCtrl.text.isNotEmpty)
                  Builder(
                    builder: (_) {
                      final val = double.tryParse(valueCtrl.text) ?? 0;
                      final discountAmt = ManualDiscount(
                        type: selectedType.value,
                        value: val,
                      ).apply(subtotal);
                      final finalTotal = (subtotal - discountAmt).clamp(
                        0.0,
                        double.infinity,
                      );
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF0FDF4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFBBF7D0)),
                        ),
                        child: Column(
                          children: [
                            _PreviewRow(
                              label: 'Subtotal',
                              value: 'Rs ${subtotal.toStringAsFixed(0)}',
                            ),
                            const SizedBox(height: 6),
                            _PreviewRow(
                              label: 'Discount',
                              value: '- Rs ${discountAmt.toStringAsFixed(0)}',
                              valueColor: const Color(0xFF10B981),
                            ),
                            const Divider(height: 12, color: Color(0xFFBBF7D0)),
                            _PreviewRow(
                              label: 'Final Total',
                              value: 'Rs ${finalTotal.toStringAsFixed(0)}',
                              isBold: true,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    if (current != null)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            ref.read(manualDiscountProvider.notifier).state =
                                null;
                            Navigator.pop(context);
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFFEF4444),
                            side: const BorderSide(color: Color(0xFFEF4444)),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Remove',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    if (current != null) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: applyDiscount,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.black,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          current != null
                              ? 'Update Discount'
                              : 'Apply Discount',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Type option ───────────────────────────────────────────────────────────────

class _TypeOption extends StatelessWidget {
  const _TypeOption({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

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
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 15,
                color: isSelected ? Colors.black : const Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? Colors.black : const Color(0xFF6B7280),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Preview row ───────────────────────────────────────────────────────────────

class _PreviewRow extends StatelessWidget {
  const _PreviewRow({
    required this.label,
    required this.value,
    this.valueColor,
    this.isBold = false,
  });
  final String label;
  final String value;
  final Color? valueColor;
  final bool isBold;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w600 : FontWeight.w400,
            color: const Color(0xFF374151),
          ),
        ),
        const Spacer(),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? const Color(0xFF374151),
          ),
        ),
      ],
    );
  }
}
