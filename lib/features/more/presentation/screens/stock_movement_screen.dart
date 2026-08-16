import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shimmer/shimmer.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/inventory/data/inventory_repository.dart';
import '../../../../features/inventory/domain/inventory_models.dart';
import '../../../../features/inventory/presentation/providers/inventory_provider.dart';
import '../../../../shared/widgets/pull_to_refresh.dart';

// ─── Local repo provider ──────────────────────────────────────────────────────

final _stockRepoProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.read(apiClientProvider)),
);

// ─── Helpers ──────────────────────────────────────────────────────────────────

final _dateFmt = DateFormat('dd MMM yyyy HH:mm');

String _fmtDate(DateTime dt) => _dateFmt.format(dt);

// ─── Movement type ────────────────────────────────────────────────────────────

enum _MovementType { stockIn, stockOut, adjustment }

const _stockInReasons = ['Purchase', 'Return', 'Adjustment'];
const _stockOutReasons = ['Damaged', 'Expired', 'Theft', 'Adjustment'];
const _adjustmentReasons = ['Stock Count', 'Correction', 'Write-off'];

// ─── Screen ───────────────────────────────────────────────────────────────────

class StockMovementScreen extends HookConsumerWidget {
  const StockMovementScreen({super.key, this.productId});
  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabCtrl = useTabController(initialLength: 2);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.more),
                    child: const Icon(Icons.close_rounded,
                        size: 22, color: Colors.black),
                  ),
                  const Spacer(),
                  const Text(
                    'Stock Movement',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  const SizedBox(width: 22),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // ── Tab bar ───────────────────────────────────────────────────
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 20),
              height: 40,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: tabCtrl,
                indicator: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(7),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                dividerColor: Colors.transparent,
                labelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w600),
                unselectedLabelStyle: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500),
                labelColor: Colors.black,
                unselectedLabelColor: AppColors.textTertiary,
                tabs: const [Tab(text: 'Record'), Tab(text: 'History')],
              ),
            ),
            const SizedBox(height: 12),

            Expanded(
              child: TabBarView(
                controller: tabCtrl,
                children: [
                  _RecordTab(productId: productId),
                  const _HistoryTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Record Movement Tab ──────────────────────────────────────────────────────

class _RecordTab extends HookConsumerWidget {
  const _RecordTab({this.productId});
  final String? productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final movementType = useState(_MovementType.stockIn);
    final selectedProduct = useState<ProductModel?>(null);
    final searchCtrl = useTextEditingController();
    final searchQuery = useState('');
    final searchResults = useState<List<ProductModel>>(const []);
    final searchLoading = useState(false);
    final showDropdown = useState(false);
    final qtyCtrl = useTextEditingController();
    final reasonCtrl = useTextEditingController();
    final reasonText = useState('');
    final submitting = useState(false);
    final formKey = useMemoized(() => GlobalKey<FormState>());

    useEffect(() {
      void onReason() => reasonText.value = reasonCtrl.text;
      reasonCtrl.addListener(onReason);
      return () => reasonCtrl.removeListener(onReason);
    }, [reasonCtrl]);

    useEffect(() {
      void onSearch() => searchQuery.value = searchCtrl.text;
      searchCtrl.addListener(onSearch);
      return () => searchCtrl.removeListener(onSearch);
    }, [searchCtrl]);

    useEffect(() {
      final query = searchQuery.value.trim();
      if (query.isEmpty) {
        searchResults.value = const [];
        showDropdown.value = false;
        searchLoading.value = false;
        return null;
      }
      searchLoading.value = true;
      final timer = Timer(const Duration(milliseconds: 400), () async {
        try {
          final results =
              await ref.read(_stockRepoProvider).searchProducts(query);
          searchResults.value = results;
          showDropdown.value = results.isNotEmpty;
        } catch (_) {
          searchResults.value = const [];
          showDropdown.value = false;
        } finally {
          searchLoading.value = false;
        }
      });
      return timer.cancel;
    }, [searchQuery.value]);

    // Pre-select product by id (when screen opens from a product context)
    useEffect(() {
      if (productId == null) return null;
      () async {
        try {
          final p = await ref.read(_stockRepoProvider).getById(productId!);
          selectedProduct.value = p;
        } catch (_) {}
      }();
      return null;
    }, const []);

    void selectProduct(ProductModel p) {
      selectedProduct.value = p;
      searchCtrl.clear();
      showDropdown.value = false;
      searchResults.value = const [];
    }

    final isIn = movementType.value == _MovementType.stockIn;
    final isAdj = movementType.value == _MovementType.adjustment;
    final parsedQty = int.tryParse(qtyCtrl.text.trim()) ?? 0;

    int newStock() {
      final p = selectedProduct.value;
      if (p == null) return 0;
      return switch (movementType.value) {
        _MovementType.stockIn => p.stock + parsedQty,
        _MovementType.stockOut => (p.stock - parsedQty).clamp(0, 999999),
        _MovementType.adjustment => p.stock + parsedQty,
      };
    }

    final presets =
        isAdj ? _adjustmentReasons : (isIn ? _stockInReasons : _stockOutReasons);

    Future<void> submit() async {
      if (submitting.value) return;
      final product = selectedProduct.value;
      if (product == null) {
        _snack(context, 'Please select a product', error: true);
        return;
      }
      if (!formKey.currentState!.validate()) return;
      if (parsedQty <= 0) {
        _snack(context, 'Quantity must be greater than 0', error: true);
        return;
      }
      submitting.value = true;
      try {
        final type = switch (movementType.value) {
          _MovementType.stockIn => InventoryMovementType.stockIn,
          _MovementType.stockOut => InventoryMovementType.stockOut,
          _MovementType.adjustment => InventoryMovementType.adjustment,
        };
        await ref.read(_stockRepoProvider).recordMovement(
              productId: product.id,
              type: type,
              quantity: parsedQty,
              reason: reasonCtrl.text.trim(),
            );
        ref.invalidate(productsProvider);
        ref.invalidate(inventoryLogsProvider);
        ref.invalidate(logListProvider);
        if (!context.mounted) return;
        context.go(AppRoutes.more);
        _snack(context, 'Stock updated — ${product.name}');
      } catch (e) {
        if (!context.mounted) return;
        _snack(context, 'Failed to record movement: $e', error: true);
      } finally {
        if (context.mounted) submitting.value = false;
      }
    }

    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          // Movement type
          const _SectionLabel(text: 'Movement Type'),
          const SizedBox(height: 8),
          _MovementTypeToggle(
            value: movementType.value,
            onChanged: (t) {
              movementType.value = t;
              reasonCtrl.clear();
            },
          ),
          const SizedBox(height: 20),

          // Product
          const _SectionLabel(text: 'Product'),
          const SizedBox(height: 8),
          if (selectedProduct.value != null)
            _SelectedProductCard(
              product: selectedProduct.value!,
              onClear: () {
                selectedProduct.value = null;
                searchCtrl.clear();
              },
            )
          else ...[
            _ProductSearchField(
              controller: searchCtrl,
              isLoading: searchLoading.value,
            ),
            if (showDropdown.value)
              _SearchDropdown(
                results: searchResults.value,
                onSelect: selectProduct,
              ),
          ],
          const SizedBox(height: 20),

          // Quantity
          _SectionLabel(
            text: 'Quantity',
            subtitle: isIn
                ? 'units to add'
                : isAdj
                    ? 'relative adjustment'
                    : 'units to remove',
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: qtyCtrl,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) {},
            decoration: InputDecoration(
              hintText: 'Enter quantity',
              hintStyle:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              prefixIcon: Icon(
                isIn
                    ? Icons.add_circle_outline_rounded
                    : isAdj
                        ? Icons.tune_rounded
                        : Icons.remove_circle_outline_rounded,
                size: 18,
                color: isIn
                    ? const Color(0xFF10B981)
                    : isAdj
                        ? AppColors.primary
                        : AppColors.danger,
              ),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Colors.black, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Quantity is required';
              final n = int.tryParse(v.trim());
              if (n == null || n <= 0) {
                return 'Enter a valid quantity greater than 0';
              }
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Reason
          const _SectionLabel(text: 'Reason'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: presets
                .map((chip) => GestureDetector(
                      onTap: () {
                        reasonCtrl.text = chip;
                        reasonCtrl.selection = TextSelection.fromPosition(
                            TextPosition(offset: chip.length));
                        reasonText.value = chip;
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: reasonText.value == chip
                              ? Colors.black
                              : Colors.white,
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: reasonText.value == chip
                                ? Colors.black
                                : AppColors.divider,
                          ),
                        ),
                        child: Text(
                          chip,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: reasonText.value == chip
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ))
                .toList(),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: reasonCtrl,
            decoration: InputDecoration(
              hintText: 'Enter or select a reason above',
              hintStyle:
                  const TextStyle(color: AppColors.textTertiary, fontSize: 14),
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.divider)),
              enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppColors.divider)),
              focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Colors.black, width: 1.5)),
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 14),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Reason is required';
              return null;
            },
          ),
          const SizedBox(height: 20),

          // Preview
          if (selectedProduct.value != null && parsedQty > 0) ...[
            _SummaryCard(
              product: selectedProduct.value!,
              movementType: movementType.value,
              qty: parsedQty,
              newStock: newStock(),
            ),
            const SizedBox(height: 20),
          ],

          // Submit
          GestureDetector(
            onTap: submitting.value ? null : submit,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 52,
              decoration: BoxDecoration(
                color: submitting.value
                    ? AppColors.textSecondary
                    : Colors.black,
                borderRadius: BorderRadius.circular(26),
              ),
              alignment: Alignment.center,
              child: submitting.value
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Record Movement',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  void _snack(BuildContext context, String message, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      backgroundColor: error ? AppColors.danger : Colors.black,
      behavior: SnackBarBehavior.floating,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    ));
  }
}

// ─── History Tab ──────────────────────────────────────────────────────────────

class _HistoryTab extends HookConsumerWidget {
  const _HistoryTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logState = ref.watch(logListProvider);
    final notifier = ref.read(logListProvider.notifier);
    final scrollCtrl = useScrollController();

    useEffect(() {
      void listener() {
        if (scrollCtrl.position.pixels >=
            scrollCtrl.position.maxScrollExtent - 300) {
          notifier.loadMore();
        }
      }
      scrollCtrl.addListener(listener);
      return () => scrollCtrl.removeListener(listener);
    }, [scrollCtrl]);

    return Column(
      children: [
        // Filter chips
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            children: [
              _HistoryFilterChip(
                label: 'All',
                selected: logState.typeFilter == null,
                onTap: () => notifier.setTypeFilter(null),
              ),
              const SizedBox(width: 8),
              _HistoryFilterChip(
                label: 'Stock In',
                selected:
                    logState.typeFilter == InventoryMovementType.stockIn,
                onTap: () =>
                    notifier.setTypeFilter(InventoryMovementType.stockIn),
              ),
              const SizedBox(width: 8),
              _HistoryFilterChip(
                label: 'Stock Out',
                selected:
                    logState.typeFilter == InventoryMovementType.stockOut,
                onTap: () =>
                    notifier.setTypeFilter(InventoryMovementType.stockOut),
              ),
              const SizedBox(width: 8),
              _HistoryFilterChip(
                label: 'Adjustment',
                selected:
                    logState.typeFilter == InventoryMovementType.adjustment,
                onTap: () => notifier
                    .setTypeFilter(InventoryMovementType.adjustment),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Expanded(
          child: PullToRefresh(
            onRefresh: notifier.refresh,
            child: logState.isLoading
              ? const _HistorySkeleton()
              : logState.error != null && logState.items.isEmpty
                  ? _HistoryError(onRetry: notifier.refresh)
                  : logState.items.isEmpty
                      ? const _HistoryEmpty()
                      : ListView.builder(
                          physics: const AlwaysScrollableScrollPhysics(),
                          controller: scrollCtrl,
                          padding:
                              const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: logState.items.length +
                              (logState.isLoadingMore ? 1 : 0),
                          itemBuilder: (_, i) {
                            if (i == logState.items.length) {
                              return const Padding(
                                padding: EdgeInsets.all(16),
                                child: Center(
                                  child: SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                        color: Colors.black,
                                        strokeWidth: 2),
                                  ),
                                ),
                              );
                            }
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _LogRow(log: logState.items[i]),
                            );
                          },
                        ),
          ),
        ),
      ],
    );
  }
}

// ─── Log row ──────────────────────────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final InventoryLogEntry log;

  @override
  Widget build(BuildContext context) {
    final isIn = log.type == InventoryMovementType.stockIn;
    final isAdj = log.type == InventoryMovementType.adjustment;
    final qtyText = isIn ? '+${log.quantity}' : isAdj ? '±${log.quantity}' : '-${log.quantity}';
    final qtyColor = isIn
        ? const Color(0xFF10B981)
        : isAdj
            ? AppColors.primary
            : AppColors.danger;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  log.productName,
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              _TypeBadge(type: log.type),
              const SizedBox(width: 8),
              Text(
                qtyText,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: qtyColor),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                '${log.stockBefore} → ${log.stockAfter}',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500),
              ),
              const SizedBox(width: 8),
              Container(
                  width: 3,
                  height: 3,
                  decoration: const BoxDecoration(
                      color: AppColors.border, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  log.reason,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _fmtDate(log.createdAt),
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textTertiary),
              ),
              if (log.createdByName != null) ...[
                const SizedBox(width: 4),
                Text(
                  '· ${log.createdByName}',
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Type badge ───────────────────────────────────────────────────────────────

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final InventoryMovementType type;

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (type) {
      InventoryMovementType.stockIn =>
        ('IN', AppColors.successLight, AppColors.success),
      InventoryMovementType.stockOut =>
        ('OUT', AppColors.dangerLight, AppColors.danger),
      InventoryMovementType.adjustment =>
        ('ADJ', AppColors.primaryLight, AppColors.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(5)),
      child: Text(label,
          style: TextStyle(
              fontSize: 11, fontWeight: FontWeight.w700, color: fg)),
    );
  }
}

// ─── History filter chip ──────────────────────────────────────────────────────

class _HistoryFilterChip extends StatelessWidget {
  const _HistoryFilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? Colors.black : AppColors.divider),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}

// ─── History skeleton ─────────────────────────────────────────────────────────

class _HistorySkeleton extends StatelessWidget {
  const _HistorySkeleton();

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: AppColors.divider,
      highlightColor: AppColors.background,
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        itemCount: 8,
        itemBuilder: (_, i) => Container(
          height: 86,
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }
}

// ─── History empty / error ────────────────────────────────────────────────────

class _HistoryEmpty extends StatelessWidget {
  const _HistoryEmpty();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.swap_vert_rounded, size: 48, color: AppColors.textTertiary),
          SizedBox(height: 14),
          Text('No movements yet',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          SizedBox(height: 6),
          Text('Stock changes will appear here',
              style:
                  TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _HistoryError extends StatelessWidget {
  const _HistoryError({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded,
              size: 48, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text('Failed to load history',
              style:
                  TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: onRetry,
            child: Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(10)),
              child: const Text('Retry',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Product search field ─────────────────────────────────────────────────────

class _ProductSearchField extends StatelessWidget {
  const _ProductSearchField(
      {required this.controller, required this.isLoading});
  final TextEditingController controller;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: 'Search product by name…',
        hintStyle:
            const TextStyle(color: AppColors.textTertiary, fontSize: 14),
        prefixIcon: const Icon(Icons.search_rounded,
            size: 18, color: AppColors.textTertiary),
        suffixIcon: isLoading
            ? const Padding(
                padding: EdgeInsets.all(12),
                child: SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.black),
                ),
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(color: AppColors.divider)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide:
                const BorderSide(color: Colors.black, width: 1.5)),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }
}

// ─── Search dropdown ──────────────────────────────────────────────────────────

class _SearchDropdown extends StatelessWidget {
  const _SearchDropdown(
      {required this.results, required this.onSelect});
  final List<ProductModel> results;
  final ValueChanged<ProductModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.07),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: results
            .map((p) => InkWell(
                  onTap: () => onSelect(p),
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(p.name,
                                  style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600)),
                              Text(
                                '${p.stock} in stock',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: p.isLowStock
                                      ? const Color(0xFFF59E0B)
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppColors.textTertiary),
                      ],
                    ),
                  ),
                ))
            .toList(),
      ),
    );
  }
}

// ─── Selected product card ────────────────────────────────────────────────────

class _SelectedProductCard extends StatelessWidget {
  const _SelectedProductCard(
      {required this.product, required this.onClear});
  final ProductModel product;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.black, width: 1.5),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.inventory_2_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w600)),
                Text(
                  'Current stock: ${product.stock}',
                  style: TextStyle(
                    fontSize: 12,
                    color: product.isLowStock
                        ? const Color(0xFFF59E0B)
                        : AppColors.textSecondary,
                    fontWeight: product.isLowStock
                        ? FontWeight.w600
                        : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: onClear,
            child: const Icon(Icons.close_rounded,
                size: 18, color: AppColors.textTertiary),
          ),
        ],
      ),
    );
  }
}

// ─── Movement type toggle ─────────────────────────────────────────────────────

class _MovementTypeToggle extends StatelessWidget {
  const _MovementTypeToggle(
      {required this.value, required this.onChanged});
  final _MovementType value;
  final ValueChanged<_MovementType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleButton(
            label: 'Stock In',
            selected: value == _MovementType.stockIn,
            activeColor: const Color(0xFF10B981),
            onTap: () => onChanged(_MovementType.stockIn),
          ),
          const SizedBox(width: 4),
          _ToggleButton(
            label: 'Stock Out',
            selected: value == _MovementType.stockOut,
            activeColor: AppColors.danger,
            onTap: () => onChanged(_MovementType.stockOut),
          ),
          const SizedBox(width: 4),
          _ToggleButton(
            label: 'Adjust',
            selected: value == _MovementType.adjustment,
            activeColor: AppColors.primary,
            onTap: () => onChanged(_MovementType.adjustment),
          ),
        ],
      ),
    );
  }
}

class _ToggleButton extends StatelessWidget {
  const _ToggleButton({
    required this.label,
    required this.selected,
    required this.activeColor,
    required this.onTap,
  });
  final String label;
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
            borderRadius: BorderRadius.circular(8),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color:
                  selected ? Colors.black : AppColors.textTertiary,
            ),
          ),
        ),
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
  final ProductModel product;
  final _MovementType movementType;
  final int qty;
  final int newStock;

  @override
  Widget build(BuildContext context) {
    final isIn = movementType == _MovementType.stockIn;
    final isAdj = movementType == _MovementType.adjustment;
    final accent = isIn
        ? const Color(0xFF10B981)
        : isAdj
            ? AppColors.primary
            : AppColors.danger;
    final bg = isIn
        ? AppColors.successLight
        : isAdj
            ? AppColors.primaryLight
            : AppColors.dangerLight;
    final qtyText =
        isIn ? '+$qty' : isAdj ? '±$qty' : '-$qty';
    final label = isIn
        ? 'Stock In Preview'
        : isAdj
            ? 'Adjustment Preview'
            : 'Stock Out Preview';
    final icon = isIn
        ? Icons.trending_up_rounded
        : isAdj
            ? Icons.tune_rounded
            : Icons.trending_down_rounded;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: accent),
              const SizedBox(width: 6),
              Text(label,
                  style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: accent,
                      letterSpacing: 0.3)),
            ],
          ),
          const SizedBox(height: 12),
          _SummaryRow(label: 'Product', value: product.name),
          const SizedBox(height: 6),
          _SummaryRow(
              label: 'Change',
              value: qtyText,
              valueColor: accent,
              valueBold: true),
          const SizedBox(height: 6),
          _SummaryRow(
              label: 'Current stock', value: '${product.stock}'),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(height: 1, color: AppColors.divider),
          ),
          _SummaryRow(
            label: 'New stock total',
            value: '$newStock',
            valueBold: true,
            valueColor: newStock <= product.lowStockThreshold
                ? const Color(0xFFF59E0B)
                : AppColors.textSecondary,
          ),
          if (newStock <= product.lowStockThreshold) ...[
            const SizedBox(height: 8),
            Row(
              children: [
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
              ],
            ),
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
                fontSize: 13, color: AppColors.textSecondary)),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight:
                valueBold ? FontWeight.w700 : FontWeight.w500,
            color: valueColor ?? AppColors.textSecondary,
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
                  fontSize: 12, color: AppColors.textTertiary)),
        ],
      ],
    );
  }
}
