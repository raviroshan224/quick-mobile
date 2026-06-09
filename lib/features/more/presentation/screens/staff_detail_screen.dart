import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/data/mock_auth_repository.dart';
import '../../../../features/staff/data/mock_staff_repository.dart';
import '../../../../features/staff/domain/staff_models.dart';

// ─── Avatar colors (same cycle as staff_screen / staff_form) ─────────────────

const _kAvatarColors = [
  Color(0xFF6366F1),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF14B8A6),
];

Color _avatarColorFor(String staffId) {
  final seed = staffId.codeUnits.fold(0, (s, c) => s + c);
  return _kAvatarColors[seed % _kAvatarColors.length];
}

// ─── Mock activity data ───────────────────────────────────────────────────────

class _ActivityEntry {
  const _ActivityEntry({
    required this.date,
    required this.service,
    required this.amount,
    required this.commission,
    required this.customer,
  });
  final String date;
  final String service;
  final double amount;
  final double commission;
  final String customer;
}

List<_ActivityEntry> _buildActivity(String staffId) {
  final seed = staffId.codeUnits.fold(0, (s, c) => s + c);
  const services = ['Haircut', 'Hair Color', 'Facial', 'Manicure', 'Blow Dry', 'Waxing', 'Massage'];
  const customers = ['Sita Rai', 'Anita Gurung', 'Bipana Thapa', 'Nirmala KC', 'Sabita Shrestha'];
  final base = 800.0 + (seed % 600);
  return List.generate(6, (i) {
    final amt = base + i * 150;
    final rate = 10.0 + (seed % 3) * 5;
    return _ActivityEntry(
      date: i == 0
          ? 'Today'
          : i == 1
              ? 'Yesterday'
              : '${i + 1} days ago',
      service: services[(seed + i * 3) % services.length],
      amount: amt,
      commission: amt * rate / 100,
      customer: customers[(seed + i) % customers.length],
    );
  });
}

// ─── Provider ─────────────────────────────────────────────────────────────────

final _staffDetailProvider =
    FutureProvider.family<StaffModel?, String>((ref, id) {
  return MockStaffRepository().getById(id);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class StaffDetailScreen extends ConsumerWidget {
  const StaffDetailScreen({super.key, required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(_staffDetailProvider(staffId));

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: staffAsync.when(
        loading: () => const SafeArea(
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, st) => SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Staff not found'),
                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => context.go('/more/staff'),
                  child: const Text('Go back'),
                ),
              ],
            ),
          ),
        ),
        data: (staff) {
          if (staff == null) {
            return SafeArea(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Staff member not found.'),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => context.go('/more/staff'),
                      child: const Text('Go back'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _DetailBody(staff: staff);
        },
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.staff});
  final StaffModel staff;

  @override
  Widget build(BuildContext context) {
    final activity = _buildActivity(staff.id);
    final totalSales = activity.fold(0.0, (s, e) => s + e.amount);
    final totalComm = activity.fold(0.0, (s, e) => s + e.commission);
    final email = MockAuthRepository.getEmailByUserId(staff.userId);
    final avatarColor = _avatarColorFor(staff.id);

    return SafeArea(
      child: Column(
        children: [
          // ── Header ──────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () => context.go('/more/staff'),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      size: 18, color: Colors.black),
                ),
                const Spacer(),
                const Text('Staff Detail',
                    style: TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
                const Spacer(),
                GestureDetector(
                  onTap: () =>
                      context.push('/more/staff/${staff.id}/edit'),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 7),
                    decoration: BoxDecoration(
                      color: Colors.black,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('Edit',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ),
          ),

          // ── Scrollable content ───────────────────────────────────────────
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                // ── Profile card ─────────────────────────────────────────
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: avatarColor,
                        child: Text(
                          staff.initials,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    staff.fullName,
                                    style: const TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700),
                                  ),
                                ),
                                // Active badge
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 9, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: staff.isActive
                                        ? const Color(0xFFDCFCE7)
                                        : const Color(0xFFF3F4F6),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    staff.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: staff.isActive
                                          ? const Color(0xFF16A34A)
                                          : const Color(0xFF6B7280),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (staff.specialties.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                staff.specialties.take(4).join(' · '),
                                style: const TextStyle(
                                    fontSize: 13,
                                    color: Color(0xFF6B7280)),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                            const SizedBox(height: 8),
                            // Info chips row
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: [
                                if (staff.commissionRate != null)
                                  _InfoChip(
                                    icon: Icons.percent_rounded,
                                    label:
                                        '${staff.commissionRate!.toStringAsFixed(0)}% commission',
                                    color: const Color(0xFF6366F1),
                                  ),
                                if (staff.phone != null)
                                  _InfoChip(
                                    icon: Icons.phone_outlined,
                                    label: staff.phone!,
                                    color: const Color(0xFF0EA5E9),
                                  ),
                                if (email != null)
                                  _InfoChip(
                                    icon: Icons.email_outlined,
                                    label: email,
                                    color: const Color(0xFF6B7280),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // ── Stats row ─────────────────────────────────────────────
                Row(children: [
                  Expanded(
                    child: _StatCard(
                      label: 'This Week',
                      value:
                          'NPR ${_fmt(totalSales)}',
                      icon: Icons.trending_up_rounded,
                      iconColor: const Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Commission',
                      value: 'NPR ${_fmt(totalComm)}',
                      icon: Icons.payments_outlined,
                      iconColor: const Color(0xFF6366F1),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Services',
                      value: '${activity.length}',
                      icon: Icons.spa_outlined,
                      iconColor: const Color(0xFFF59E0B),
                    ),
                  ),
                ]),
                const SizedBox(height: 20),

                // ── Recent Activity ───────────────────────────────────────
                const Text('Recent Activity',
                    style: TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600)),
                const SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    children: [
                      for (int i = 0; i < activity.length; i++) ...[
                        if (i > 0)
                          const Divider(
                              height: 1, color: Color(0xFFF3F4F6)),
                        _ActivityTile(entry: activity[i]),
                      ],
                    ],
                  ),
                ),

                // ── Specialties ───────────────────────────────────────────
                if (staff.specialties.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  const Text('Specialties',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: staff.specialties
                        .map((s) => _SpecialtyChip(label: s))
                        .toList(),
                  ),
                ],

                // ── Login credentials ─────────────────────────────────────
                if (email != null) ...[
                  const SizedBox(height: 20),
                  const Text('Login Credentials',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 18, color: Color(0xFF6B7280)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(email,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const Icon(Icons.lock_outline,
                            size: 16, color: Color(0xFFD1D5DB)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) {
    if (v >= 1000) {
      final k = v / 1000;
      return k == k.truncateToDouble()
          ? '${k.truncate()}k'
          : '${k.toStringAsFixed(1)}k';
    }
    return v.toStringAsFixed(0);
  }
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _InfoChip extends StatelessWidget {
  const _InfoChip(
      {required this.icon, required this.label, required this.color});
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 5),
          Text(label,
              style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.label,
      required this.value,
      required this.icon,
      required this.iconColor});
  final String label;
  final String value;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE5E7EB)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(height: 8),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(
                  fontSize: 11, color: Color(0xFF9CA3AF))),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.entry});
  final _ActivityEntry entry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.spa_outlined,
                size: 18, color: Color(0xFF6B7280)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(entry.service,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text('${entry.customer} · ${entry.date}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('NPR ${entry.amount.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              Text('+NPR ${entry.commission.toStringAsFixed(0)} comm.',
                  style: const TextStyle(
                      fontSize: 11, color: Color(0xFF10B981))),
            ],
          ),
        ],
      ),
    );
  }
}

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF374151),
              fontWeight: FontWeight.w500)),
    );
  }
}
