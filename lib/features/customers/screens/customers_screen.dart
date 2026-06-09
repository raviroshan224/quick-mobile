import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/customer_model.dart';
import '../providers/customers_provider.dart';

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(customersProvider);

    final filtered = _query.isEmpty
        ? all
        : all.where((c) {
            return c.name.toLowerCase().contains(_query) ||
                c.phone.contains(_query);
          }).toList();

    // sort: most recent visit first
    filtered.sort((a, b) {
      if (a.lastVisitDate == null && b.lastVisitDate == null) return 0;
      if (a.lastVisitDate == null) return 1;
      if (b.lastVisitDate == null) return -1;
      return b.lastVisitDate!.compareTo(a.lastVisitDate!);
    });

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Customers')),
      body: Column(
        children: [
          _SearchBar(
            controller: _searchCtrl,
            onChanged: (v) => setState(() => _query = v.toLowerCase()),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
            child: Row(
              children: [
                Text(
                  '${all.length} customer${all.length == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: filtered.isEmpty
                ? _EmptyState(
                    hasQuery: _query.isNotEmpty,
                    searchQuery: _searchCtrl.text.trim(),
                    onAdd: (name, phone) =>
                        _quickAdd(context, name: name, phone: phone),
                    onAddNew: () => context.push('/customers/new'),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.only(bottom: 100),
                    itemCount: filtered.length,
                    separatorBuilder: (context, i) =>
                        const Divider(height: 1, indent: 68),
                    itemBuilder: (_, i) => _CustomerRow(
                      customer: filtered[i],
                      onTap: () =>
                          context.push('/customers/${filtered[i].id}'),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/customers/new'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 2,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('New Customer',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }

  void _quickAdd(BuildContext context,
      {required String name, required String phone}) {
    ref.read(customersProvider.notifier).add(
          Customer.create(name: name, phone: phone),
        );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$name added'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

// ── Search bar ────────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchBar({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.text,
        decoration: InputDecoration(
          hintText: 'Search by name or phone…',
          prefixIcon:
              const Icon(Icons.search, size: 20, color: AppColors.textTertiary),
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                )
              : null,
        ),
      ),
    );
  }
}

// ── Customer row ──────────────────────────────────────────────────────────────

class _CustomerRow extends StatelessWidget {
  final Customer customer;
  final VoidCallback onTap;

  const _CustomerRow({required this.customer, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CustomerAvatar(name: customer.name, size: 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(customer.name,
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 2),
                  Text(customer.phone,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (customer.visitCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${customer.visitCount} visit${customer.visitCount == 1 ? '' : 's'}',
                      style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: AppColors.textSecondary),
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  customer.lastVisitLabel,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textTertiary),
                ),
              ],
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

// ── Shared avatar widget ──────────────────────────────────────────────────────

class CustomerAvatar extends StatelessWidget {
  final String name;
  final double size;

  const CustomerAvatar({super.key, required this.name, this.size = 40});

  static const _colors = [
    Color(0xFF5856D6),
    Color(0xFF34AADC),
    Color(0xFF4CD964),
    Color(0xFFFF9500),
    Color(0xFFFF3B30),
    Color(0xFFFF2D55),
    Color(0xFF007AFF),
    Color(0xFF5AC8FA),
  ];

  Color get _color =>
      _colors[name.isNotEmpty ? name.codeUnitAt(0) % _colors.length : 0];

  String get _initials {
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          _initials,
          style: TextStyle(
            fontSize: size * 0.38,
            fontWeight: FontWeight.w700,
            color: _color,
          ),
        ),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final bool hasQuery;
  final String searchQuery;
  final void Function(String name, String phone) onAdd;
  final VoidCallback onAddNew;

  const _EmptyState({
    required this.hasQuery,
    required this.searchQuery,
    required this.onAdd,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(32)),
              child: const Icon(Icons.people_outline,
                  size: 32, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              hasQuery ? 'No customer found' : 'No customers yet',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'No match for "$searchQuery"'
                  : 'Add customers to track visits,\nspend and notes.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAddNew,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.person_add_outlined, size: 18),
              label: const Text('Add Customer',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
