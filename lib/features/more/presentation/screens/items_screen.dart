import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/inventory/domain/inventory_models.dart';
import '../../../../features/inventory/presentation/providers/inventory_provider.dart';

class ItemsScreen extends ConsumerStatefulWidget {
  const ItemsScreen({super.key});

  @override
  ConsumerState<ItemsScreen> createState() => _ItemsScreenState();
}

class _ItemsScreenState extends ConsumerState<ItemsScreen> {
  String _search = '';
  String? _selectedCategory;

  static const _categoryColors = {
    'Shampoo': Color(0xFFE8EDD6),
    'Conditioner': Color(0xFFE0E4D0),
    'Scissors': Color(0xFFFEF9C3),
    'Combs': Color(0xFFD1FAE5),
    'Blades': Color(0xFFFEE2E2),
    'Hair Color': Color(0xFFEEEEEB),
    'Treatment': Color(0xFFDCE0C8),
    'Skin Care': Color(0xFFFFEDD5),
    'Nails': Color(0xFFF8F8F5),
    'Massage': Color(0xFFD1FAE5),
  };

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);
    final itemsAsync = ref.watch(productsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => context.go(AppRoutes.more),
        ),
        title: const Text('Items',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: isOwner ? () => context.go('/more/items/new') : null,
          ),
        ],
      ),
      body: itemsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (products) {
          // Build category list
          final cats = products
              .map((p) => p.category ?? 'Other')
              .toSet()
              .toList()
            ..sort();

          final filtered = products.where((p) {
            final matchCat = _selectedCategory == null ||
                p.category == _selectedCategory;
            final matchSearch = _search.isEmpty ||
                p.name
                    .toLowerCase()
                    .contains(_search.toLowerCase());
            return matchCat && matchSearch;
          }).toList();

          return Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search items',
                    hintStyle: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.textTertiary),
                    filled: true,
                    fillColor: AppColors.surfaceVariant,
                    border: OutlineInputBorder(
                      borderSide: BorderSide.none,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                  ),
                ),
              ),
              // Category chips
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 8),
                  children: [
                    _CategoryChip(
                      label: 'All',
                      selected: _selectedCategory == null,
                      onTap: () =>
                          setState(() => _selectedCategory = null),
                    ),
                    ...cats.map((c) => _CategoryChip(
                          label: c,
                          selected: _selectedCategory == c,
                          onTap: () => setState(
                              () => _selectedCategory = c),
                        )),
                  ],
                ),
              ),
              const Divider(height: 1, color: AppColors.surfaceVariant),
              // Count
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${filtered.length} item${filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ),
              ),
              // Grid
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 8, 14, 16),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    childAspectRatio: 1,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _ItemGridCard(
                    product: filtered[i],
                    bg: _categoryColors[filtered[i].category] ??
                        AppColors.surfaceVariant,
                    onTap: isOwner
                        ? () => context.go('/more/items/${filtered[i].id}/edit')
                        : null,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip(
      {required this.label,
      required this.selected,
      required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(right: 6),
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(
          color: selected ? Colors.black : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected ? Colors.white : AppColors.textSecondary)),
      ),
    );
  }
}

class _ItemGridCard extends StatelessWidget {
  const _ItemGridCard(
      {required this.product, required this.bg, this.onTap});
  final ProductModel product;
  final Color bg;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  product.name,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Rs ${product.price.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  product.isLowStock
                      ? 'Low stock · ${product.stock}'
                      : '${product.stock} in stock',
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: product.isLowStock
                        ? AppColors.danger
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
