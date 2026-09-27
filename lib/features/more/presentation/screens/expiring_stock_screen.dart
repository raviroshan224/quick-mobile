import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/models/app_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/inventory/domain/inventory_models.dart';
import '../../../../features/inventory/presentation/providers/inventory_provider.dart';
import '../../../../shared/widgets/pull_to_refresh.dart';

final _expiryFmt = DateFormat('dd MMM yyyy');

enum _Window {
  expired('Expired'),
  days30('Next 30 days'),
  days90('Next 90 days');

  const _Window(this.label);
  final String label;

  bool includes(ProductBatch b) {
    final d = b.daysToExpiry;
    if (d == null) return false;
    return switch (this) {
      _Window.expired => b.isExpired,
      _Window.days30 => !b.isExpired && d <= 30,
      _Window.days90 => !b.isExpired && d <= 90,
    };
  }
}

/// Batches that have expired or will soon, so they can be sold first or
/// written off. Sales already skip expired batches and take the soonest
/// expiry first; this screen is for acting on what's left.
class ExpiringStockScreen extends HookConsumerWidget {
  const ExpiringStockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchesAsync = ref.watch(expiringBatchesProvider);
    final window = useState(_Window.expired);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => context.go(AppRoutes.more),
        ),
        title: const Text('Expiring Stock',
            style: TextStyle(
                fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black)),
        centerTitle: true,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
              children: [
                for (final w in _Window.values) ...[
                  _WindowChip(
                    label: batchesAsync.hasValue
                        ? '${w.label} (${batchesAsync.value!.where(w.includes).length})'
                        : w.label,
                    selected: window.value == w,
                    danger: w == _Window.expired,
                    onTap: () => window.value = w,
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
          Expanded(
            child: PullToRefresh(
              onRefresh: () => ref.refresh(expiringBatchesProvider.future),
              child: batchesAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(color: Colors.black)),
                error: (e, _) => _Message(
                  icon: Icons.cloud_off_rounded,
                  text: e is AppException ? e.message : 'Could not load expiring stock.',
                  onRetry: () => ref.invalidate(expiringBatchesProvider),
                ),
                data: (all) {
                  final shown = all.where(window.value.includes).toList();
                  if (shown.isEmpty) {
                    return _Message(
                      icon: Icons.verified_outlined,
                      text: window.value == _Window.expired
                          ? 'No expired stock.'
                          : 'Nothing expires in this period.',
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    itemCount: shown.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BatchRow(
                      batch: shown[i],
                      onWriteOff: () => _writeOff(context, ref, shown[i]),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _writeOff(
      BuildContext context, WidgetRef ref, ProductBatch batch) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Write off batch?', style: TextStyle(fontSize: 16)),
        content: Text(
          'Remove ${batch.quantity} unit(s) of ${batch.productName ?? 'this item'} '
          '(${batch.label}) from stock. This is recorded in Stock Movement '
          'history.',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel',
                style: TextStyle(color: AppColors.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Write off',
                style: TextStyle(
                    color: AppColors.danger, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(inventoryRepositoryProvider).recordMovement(
            productId: batch.productId,
            type: InventoryMovementType.stockOut,
            quantity: batch.quantity,
            reason: batch.isExpired ? 'Expired' : 'Near expiry write-off',
            batchId: batch.id,
          );
      ref.invalidate(expiringBatchesProvider);
      ref.invalidate(productsProvider);
      ref.invalidate(logListProvider);
      if (context.mounted) {
        _snack(context, 'Written off ${batch.quantity} unit(s)');
      }
    } catch (e) {
      if (context.mounted) {
        _snack(context, e is AppException ? e.message : 'Could not write off',
            error: true);
      }
    }
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : Colors.black,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }
}

class _WindowChip extends StatelessWidget {
  const _WindowChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.danger = false,
  });
  final String label;
  final bool selected;
  final bool danger;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = danger ? AppColors.danger : Colors.black;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? accent : Colors.white,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: selected ? accent : AppColors.divider),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _BatchRow extends StatelessWidget {
  const _BatchRow({required this.batch, required this.onWriteOff});
  final ProductBatch batch;
  final VoidCallback onWriteOff;

  @override
  Widget build(BuildContext context) {
    final days = batch.daysToExpiry ?? 0;
    final (color, expiryText) = batch.isExpired
        ? (AppColors.danger, 'Expired ${_expiryFmt.format(batch.expiryDate!)}')
        : days == 0
            ? (AppColors.danger, 'Expires today')
            : days <= 30
                ? (const Color(0xFFD97706),
                    'Expires in $days day${days == 1 ? '' : 's'}')
                : (AppColors.textSecondary,
                    'Expires ${_expiryFmt.format(batch.expiryDate!)}');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  [batch.productName ?? 'Item', ?batch.productDetail]
                      .join(' · '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 3),
                Text('${batch.label} · ${batch.quantity} unit${batch.quantity == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 3),
                Text(expiryText,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton(
            onPressed: onWriteOff,
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.danger,
              side: const BorderSide(color: AppColors.divider),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 12),
              visualDensity: VisualDensity.compact,
            ),
            child: const Text('Write off', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.text, this.onRetry});
  final IconData icon;
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    // Scrollable so pull-to-refresh works on the empty/error state too.
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(40, 120, 40, 40),
      children: [
        Icon(icon, size: 36, color: AppColors.textTertiary),
        const SizedBox(height: 12),
        Text(text,
            textAlign: TextAlign.center,
            style: const TextStyle(
                fontSize: 14, color: AppColors.textSecondary)),
        if (onRetry != null) ...[
          const SizedBox(height: 16),
          Center(
            child: TextButton(
              onPressed: onRetry,
              child: const Text('Retry',
                  style: TextStyle(color: Colors.black)),
            ),
          ),
        ],
      ],
    );
  }
}
