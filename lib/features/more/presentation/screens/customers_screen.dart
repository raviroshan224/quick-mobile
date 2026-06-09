import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/customers/data/mock_customers_repository.dart';
import '../../../../features/customers/domain/customer_models.dart';

// ── Providers ─────────────────────────────────────────────────────────────────

final _customerSearchQueryProvider = StateProvider<String>((ref) => '');

final _customersProvider =
    FutureProvider.family<List<CustomerModel>, String>((ref, query) {
  return MockCustomersRepository().getAll(query: query.isEmpty ? null : query);
});

// ── Screen ────────────────────────────────────────────────────────────────────

class CustomersScreen extends ConsumerStatefulWidget {
  const CustomersScreen({super.key});

  @override
  ConsumerState<CustomersScreen> createState() => _CustomersScreenState();
}

class _CustomersScreenState extends ConsumerState<CustomersScreen> {
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final query = ref.watch(_customerSearchQueryProvider);
    final customersAsync = ref.watch(_customersProvider(query));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header row ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.black),
                    onPressed: () => context.go(AppRoutes.more),
                  ),
                  const Expanded(
                    child: Text(
                      'Customers',
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: Colors.black),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add, color: Colors.black),
                    onPressed: () =>
                        context.push(AppRoutes.customerNew),
                  ),
                ],
              ),
            ),

            // ── Search bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) => ref
                    .read(_customerSearchQueryProvider.notifier)
                    .state = v.trim(),
                keyboardType: TextInputType.text,
                decoration: InputDecoration(
                  hintText: 'Search by name, phone or email…',
                  hintStyle: const TextStyle(
                      color: Color(0xFF9CA3AF), fontSize: 14),
                  prefixIcon: const Icon(Icons.search,
                      size: 18, color: Color(0xFF9CA3AF)),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close,
                              size: 16, color: Color(0xFF9CA3AF)),
                          onPressed: () {
                            _searchCtrl.clear();
                            ref
                                .read(
                                    _customerSearchQueryProvider.notifier)
                                .state = '';
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderSide:
                        const BorderSide(color: Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderSide: const BorderSide(color: Colors.black),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(vertical: 10),
                ),
              ),
            ),

            const SizedBox(height: 10),
            const Divider(height: 1, color: Color(0xFFE5E7EB)),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: customersAsync.when(
                loading: () => const Center(
                    child: CircularProgressIndicator(
                        color: Colors.black, strokeWidth: 2)),
                error: (e, _) => Center(
                    child: Text('Error: $e',
                        style: const TextStyle(
                            color: Color(0xFF6B7280)))),
                data: (customers) {
                  if (customers.isEmpty) {
                    return _EmptyState(
                      hasQuery: query.isNotEmpty,
                      onAdd: () =>
                          context.push(AppRoutes.customerNew),
                    );
                  }
                  return _CustomerSectionedList(
                      customers: customers);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Sectioned list ────────────────────────────────────────────────────────────

class _CustomerSectionedList extends StatelessWidget {
  const _CustomerSectionedList({required this.customers});
  final List<CustomerModel> customers;

  @override
  Widget build(BuildContext context) {
    // Sort alphabetically by full name
    final sorted = [...customers]
      ..sort((a, b) => a.fullName.compareTo(b.fullName));

    // Group by first letter
    final Map<String, List<CustomerModel>> grouped = {};
    for (final c in sorted) {
      final key =
          c.firstName.isNotEmpty ? c.firstName[0].toUpperCase() : '#';
      grouped.putIfAbsent(key, () => []).add(c);
    }
    final keys = grouped.keys.toList()..sort();

    // Count label
    final total = customers.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
          child: Text(
            '$total customer${total == 1 ? '' : 's'}',
            style: const TextStyle(
                fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.only(bottom: 40),
            itemCount: keys.fold<int>(
                0, (sum, k) => sum + 1 + grouped[k]!.length),
            itemBuilder: (context, index) {
              // Map index to section + item
              int offset = 0;
              for (final key in keys) {
                final section = grouped[key]!;
                if (index == offset) {
                  // Section header
                  return _SectionHeader(letter: key);
                }
                offset++;
                if (index < offset + section.length) {
                  final customer = section[index - offset];
                  final isLast =
                      index == offset + section.length - 1;
                  return _CustomerTile(
                    customer: customer,
                    isLast: isLast,
                  );
                }
                offset += section.length;
              }
              return const SizedBox.shrink();
            },
          ),
        ),
      ],
    );
  }
}

// ── Section header ────────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.letter});
  final String letter;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFFF9FAFB),
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
      child: Text(
        letter,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ── Customer tile ─────────────────────────────────────────────────────────────

class _CustomerTile extends StatelessWidget {
  const _CustomerTile({
    required this.customer,
    required this.isLast,
  });
  final CustomerModel customer;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final subtitle = customer.phone ?? customer.email ?? '';

    return Column(
      children: [
        Material(
          color: Colors.white,
          child: InkWell(
            onTap: () => context
                .push(AppRoutes.customerDetail(customer.id)),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // Avatar
                  Container(
                    width: 42,
                    height: 42,
                    decoration: const BoxDecoration(
                      color: Colors.black,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        customer.initials,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Name + subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          customer.fullName,
                          style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500),
                        ),
                        if (subtitle.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: const TextStyle(
                                fontSize: 12,
                                color: Color(0xFF6B7280)),
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Trailing: visits · spend
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '${customer.visitCount} visit${customer.visitCount == 1 ? '' : 's'}',
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF374151)),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'NPR ${_formatAmount(customer.totalSpent)}',
                        style: const TextStyle(
                            fontSize: 11,
                            color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                  const SizedBox(width: 6),
                  const Icon(Icons.chevron_right,
                      size: 16, color: Color(0xFF9CA3AF)),
                ],
              ),
            ),
          ),
        ),
        if (!isLast)
          const Divider(
            height: 1,
            indent: 70,
            color: Color(0xFFF3F4F6),
          ),
      ],
    );
  }

  String _formatAmount(double amount) {
    if (amount >= 1000) {
      return '${(amount / 1000).toStringAsFixed(amount % 1000 == 0 ? 0 : 1)}k';
    }
    return amount.toStringAsFixed(0);
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.hasQuery, required this.onAdd});
  final bool hasQuery;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(36),
              ),
              child: const Icon(Icons.people_outline_rounded,
                  size: 34, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(height: 18),
            Text(
              hasQuery ? 'No customers found' : 'No customers yet',
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              hasQuery
                  ? 'Try a different search term'
                  : 'Add customers to track visits,\nspend and notes.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF6B7280)),
            ),
            if (!hasQuery) ...[
              const SizedBox(height: 22),
              GestureDetector(
                onTap: onAdd,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 22, vertical: 13),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.person_add_outlined,
                          size: 17, color: Colors.white),
                      SizedBox(width: 8),
                      Text(
                        'Add First Customer',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
