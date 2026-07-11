import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/services/domain/service_models.dart';
import '../../../../features/services/presentation/providers/services_provider.dart';

class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  String _search = '';
  String? _selectedCategoryId;

  static const _catColors = {
    'cat-1': Color(0xFFE8EDD6), // Hair — olive-50
    'cat-2': Color(0xFFEEEEEB), // Nails — warm grey
    'cat-3': Color(0xFFD1FAE5), // Skin — green (keep semantic)
    'cat-4': Color(0xFFDCE0C8), // Makeup — deeper olive
    'cat-5': Color(0xFFFFEDD5), // Massage — orange (keep warm)
  };
  static const _catIcons = {
    'cat-1': Icons.content_cut_rounded,
    'cat-2': Icons.back_hand_outlined,
    'cat-3': Icons.face_retouching_natural,
    'cat-4': Icons.auto_awesome,
    'cat-5': Icons.self_improvement,
  };

  @override
  Widget build(BuildContext context) {
    final isOwner = ref.watch(isOwnerProvider);
    final servicesAsync = ref.watch(servicesListProvider);
    final catsAsync = ref.watch(serviceCategoriesListProvider);

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
        title: const Text('Services',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: isOwner ? () => context.push(AppRoutes.serviceNew) : null,
          ),
        ],
      ),
      body: servicesAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (services) {
          final cats = catsAsync.valueOrNull ?? [];

          final filtered = services.where((s) {
            final matchCat = _selectedCategoryId == null ||
                s.category?.id == _selectedCategoryId;
            final matchSearch = _search.isEmpty ||
                s.name.toLowerCase().contains(_search.toLowerCase());
            return matchCat && matchSearch;
          }).toList();

          return Column(
            children: [
              // Search
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: InputDecoration(
                    hintText: 'Search services',
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
                    _Chip(
                      label: 'All',
                      selected: _selectedCategoryId == null,
                      onTap: () => setState(
                          () => _selectedCategoryId = null),
                    ),
                    ...cats.map((c) => _Chip(
                          label: c.name,
                          selected: _selectedCategoryId == c.id,
                          onTap: () => setState(
                              () => _selectedCategoryId = c.id),
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
                    '${filtered.length} service${filtered.length == 1 ? '' : 's'}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary),
                  ),
                ),
              ),
              // List grouped by category
              Expanded(
                child: ListView.separated(
                  padding: EdgeInsets.zero,
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(
                      height: 1,
                      indent: 62,
                      color: AppColors.surfaceVariant),
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    final catId = s.category?.id ?? '';
                    return _ServiceTile(
                      service: s,
                      iconBg: _catColors[catId] ?? AppColors.surfaceVariant,
                      icon: _catIcons[catId] ?? Icons.spa_outlined,
                      onTap: isOwner ? () => context.push(
                          AppRoutes.serviceEdit(s.id)) : null,
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(
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
          color:
              selected ? Colors.black : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: selected
                    ? Colors.white
                    : AppColors.textSecondary)),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile(
      {required this.service,
      required this.iconBg,
      required this.icon,
      this.onTap});
  final ServiceModel service;
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
      title: Text(service.name,
          style: const TextStyle(fontSize: 14)),
      subtitle: service.durationLabel.isEmpty
          ? null
          : Text(service.durationLabel,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textTertiary)),
      trailing: Text(
        'NPR ${service.price.toStringAsFixed(0)}',
        style: const TextStyle(
            fontSize: 14, fontWeight: FontWeight.w500),
      ),
    );
  }
}
