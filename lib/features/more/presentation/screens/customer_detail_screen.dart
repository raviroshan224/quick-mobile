import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/customers/data/mock_customers_repository.dart';
import '../../../../features/customers/domain/customer_models.dart';

// ── Provider ──────────────────────────────────────────────────────────────────

final _customerByIdProvider =
    FutureProvider.family<CustomerModel?, String>((ref, id) {
  return MockCustomersRepository().getById(id);
});

// ── Mock visit history ────────────────────────────────────────────────────────

class _VisitRecord {
  _VisitRecord({
    required this.date,
    required this.services,
    required this.amount,
  });
  final DateTime date;
  final List<String> services;
  final double amount;
}

// Three pools of 5 visits; chosen by a hash of the customer ID.
List<_VisitRecord> _mockVisitsFor(String customerId) {
  final pools = [
    [
      _VisitRecord(date: DateTime(2026, 6, 3),  services: ['Haircut & Blow Dry'],                       amount: 800),
      _VisitRecord(date: DateTime(2026, 5, 15), services: ['Hair Color (Full)', 'Classic Facial'],       amount: 3700),
      _VisitRecord(date: DateTime(2026, 4, 20), services: ['Haircut & Blow Dry', 'Keratin Shampoo'],     amount: 1250),
      _VisitRecord(date: DateTime(2026, 3, 10), services: ['Manicure'],                                  amount: 600),
      _VisitRecord(date: DateTime(2026, 2, 2),  services: ['Swedish Massage (60 min)'],                  amount: 1800),
    ],
    [
      _VisitRecord(date: DateTime(2026, 6, 1),  services: ['Manicure', 'Pedicure'],                      amount: 1300),
      _VisitRecord(date: DateTime(2026, 5, 5),  services: ['Classic Facial'],                            amount: 1200),
      _VisitRecord(date: DateTime(2026, 4, 14), services: ['Waxing (Full Legs)', 'Eyebrow Threading'],   amount: 950),
      _VisitRecord(date: DateTime(2026, 3, 22), services: ['Haircut & Blow Dry'],                        amount: 800),
      _VisitRecord(date: DateTime(2026, 2, 18), services: ['Hair Color (Highlights)'],                   amount: 2800),
    ],
    [
      _VisitRecord(date: DateTime(2026, 5, 28), services: ['Swedish Massage (60 min)'],                  amount: 1800),
      _VisitRecord(date: DateTime(2026, 4, 10), services: ['Haircut & Blow Dry', 'Eyebrow Threading'],   amount: 900),
      _VisitRecord(date: DateTime(2026, 3, 3),  services: ['Classic Facial', 'Manicure'],                amount: 1800),
      _VisitRecord(date: DateTime(2026, 2, 14), services: ['Hair Color (Root Touch-Up)'],                amount: 1500),
      _VisitRecord(date: DateTime(2026, 1, 20), services: ['Pedicure'],                                  amount: 700),
    ],
  ];
  final seed =
      customerId.codeUnits.fold(0, (a, b) => a + b) % pools.length;
  return pools[seed];
}

// ── Screen ────────────────────────────────────────────────────────────────────

class CustomerDetailScreen extends ConsumerWidget {
  const CustomerDetailScreen({super.key, required this.customerId});
  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final customerAsync = ref.watch(_customerByIdProvider(customerId));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: customerAsync.when(
          loading: () => Column(
            children: [
              _Header(
                customerId: customerId,
                onEdit: () {},
              ),
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(
                      color: Colors.black, strokeWidth: 2),
                ),
              ),
            ],
          ),
          error: (e, _) => Column(
            children: [
              _Header(customerId: customerId, onEdit: () {}),
              Expanded(
                child: Center(
                  child: Text('Error: $e',
                      style: const TextStyle(
                          color: Color(0xFF6B7280))),
                ),
              ),
            ],
          ),
          data: (customer) {
            if (customer == null) {
              return Column(
                children: [
                  _Header(customerId: customerId, onEdit: () {}),
                  const Expanded(
                    child: Center(
                      child: Text('Customer not found',
                          style: TextStyle(
                              color: Color(0xFF6B7280))),
                    ),
                  ),
                ],
              );
            }
            return _CustomerDetailBody(
              customer: customer,
              visits: _mockVisitsFor(customerId),
              onEdit: () =>
                  context.push(AppRoutes.customerEdit(customerId)),
            );
          },
        ),
      ),
    );
  }
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.customerId, required this.onEdit});
  final String customerId;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 8, 8, 0),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.black),
            onPressed: () => context.go(AppRoutes.moreCustomers),
          ),
          const Expanded(
            child: Text(
              'Customer',
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
          ),
          TextButton(
            onPressed: onEdit,
            child: const Text(
              'Edit',
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Full body ─────────────────────────────────────────────────────────────────

class _CustomerDetailBody extends StatelessWidget {
  const _CustomerDetailBody({
    required this.customer,
    required this.visits,
    required this.onEdit,
  });
  final CustomerModel customer;
  final List<_VisitRecord> visits;
  final VoidCallback onEdit;

  String _fmt(double v) {
    if (v >= 1000) {
      return '${(v / 1000).toStringAsFixed(v % 1000 == 0 ? 0 : 1)}k';
    }
    return v.toStringAsFixed(0);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Header(customerId: customer.id, onEdit: onEdit),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              // ── Hero section ──────────────────────────────────────
              _HeroSection(customer: customer),
              const SizedBox(height: 16),

              // ── Stats row ─────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: _StatCard(
                        label: 'Visits',
                        value: '${customer.visitCount}',
                        icon: Icons.calendar_today_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Total Spent',
                        value: 'NPR ${_fmt(customer.totalSpent)}',
                        icon: Icons.payments_outlined,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _StatCard(
                        label: 'Last Visit',
                        value: customer.lastVisitLabel,
                        icon: Icons.access_time_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Visit History section label ────────────────────────
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Text(
                  'VISIT HISTORY',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.8,
                  ),
                ),
              ),

              // ── Visit history card ────────────────────────────────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: Column(
                  children: [
                    for (int i = 0; i < visits.length; i++) ...[
                      _VisitRow(visit: visits[i]),
                      if (i < visits.length - 1)
                        const Divider(
                          height: 1,
                          indent: 36,
                          endIndent: 16,
                          color: Color(0xFFF3F4F6),
                        ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Start Sale button ─────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: GestureDetector(
                  onTap: () => context.go(AppRoutes.checkout),
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(vertical: 15),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.point_of_sale_outlined,
                            size: 18, color: Colors.white),
                        SizedBox(width: 8),
                        Text(
                          'Start Sale',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ── Hero section ──────────────────────────────────────────────────────────────

class _HeroSection extends StatelessWidget {
  const _HeroSection({required this.customer});
  final CustomerModel customer;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                customer.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 28,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            customer.fullName,
            style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          if (customer.phone != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.phone_outlined,
                    size: 13, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  customer.phone!,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (customer.email != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.mail_outline_rounded,
                    size: 13, color: Color(0xFF6B7280)),
                const SizedBox(width: 4),
                Text(
                  customer.email!,
                  style: const TextStyle(
                      fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          if (customer.notes != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.sticky_note_2_outlined,
                      size: 14, color: Color(0xFF9CA3AF)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      customer.notes!,
                      style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF374151),
                          height: 1.4),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stat card ─────────────────────────────────────────────────────────────────

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:
          const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: const Color(0xFF6B7280)),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w700),
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            label,
            style: const TextStyle(
                fontSize: 10,
                color: Color(0xFF9CA3AF),
                fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

// ── Visit row ─────────────────────────────────────────────────────────────────

class _VisitRow extends StatelessWidget {
  const _VisitRow({required this.visit});
  final _VisitRecord visit;

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  String _formatDate(DateTime d) =>
      '${d.day} ${_months[d.month - 1]} ${d.year}';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.only(top: 5),
            decoration: const BoxDecoration(
              color: Colors.black,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(visit.date),
                  style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 3),
                Text(
                  visit.services.join(', '),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
          Text(
            'NPR ${visit.amount.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
