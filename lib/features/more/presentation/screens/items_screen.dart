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

  static const _categoryIcons = {
    'Shampoo': Icons.water_drop_outlined,
    'Conditioner': Icons.water_drop_outlined,
    'Scissors': Icons.content_cut_rounded,
    'Combs': Icons.horizontal_rule_rounded,
    'Blades': Icons.spa_outlined,
    'Hair Color': Icons.color_lens_outlined,
    'Treatment': Icons.science_outlined,
    'Skin Care': Icons.face_retouching_natural,
    'Nails': Icons.back_hand_outlined,
    'Massage': Icons.self_improvement,
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
              // List
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 62,
                      color: AppColors.surfaceVariant),
                  itemBuilder: (_, i) => _ItemTile(
                    product: filtered[i],
                    iconBg: _categoryColors[filtered[i].category] ??
                        AppColors.surfaceVariant,
                    icon: _categoryIcons[filtered[i].category] ??
                        Icons.inventory_2_outlined,
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

class _ItemTile extends StatelessWidget {
  const _ItemTile(
      {required this.product,
      required this.iconBg,
      required this.icon,
      this.onTap});
  final ProductModel product;
  final Color iconBg;
  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: iconBg,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, size: 18, color: Colors.black54),
      ),
      title: Text(product.name,
          style: const TextStyle(fontSize: 14)),
      subtitle: Row(
        children: [
          Text(product.category ?? '',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary)),
          if (product.isLowStock) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Text('Low stock',
                  style: TextStyle(
                      fontSize: 10,
                      color: AppColors.danger,
                      fontWeight: FontWeight.w500)),
            ),
          ],
        ],
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text('Rs ${product.price.toStringAsFixed(0)}',
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          Text('${product.stock} in stock',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}
