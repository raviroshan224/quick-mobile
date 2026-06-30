import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/staff/domain/staff_models.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/staff/presentation/providers/staff_provider.dart';
import '../../../../features/transactions/domain/transaction_models.dart';
import '../../../../features/transactions/presentation/providers/transactions_provider.dart';

// ─── Avatar colors (same cycle as staff_screen / staff_form) ─────────────────

const _kAvatarColors = [
  Color(0xFF6B7A3D), // olive
  Color(0xFF4D5A2C), // dark olive
  Color(0xFF8A9950), // medium olive
  Color(0xFF111111), // black
  Color(0xFF3A3A3A), // dark grey
  Color(0xFF5A5A5A), // grey
  Color(0xFF9A9A9A), // light grey
  Color(0xFFB5C090), // pale olive
];

Color _avatarColorFor(String staffId) {
  final seed = staffId.codeUnits.fold(0, (s, c) => s + c);
  return _kAvatarColors[seed % _kAvatarColors.length];
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _dateLabel(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(dt.year, dt.month, dt.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  return '${dt.day}/${dt.month}/${dt.year}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class StaffDetailScreen extends ConsumerWidget {
  const StaffDetailScreen({super.key, required this.staffId});
  final String staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffDetailProvider(staffId));

    return Scaffold(
      backgroundColor: AppColors.background,
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
        data: (staff) => _DetailBody(staff: staff),
      ),
    );
  }
}

// ─── Body ─────────────────────────────────────────────────────────────────────

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.staff});
  final StaffModel staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txAsync = ref.watch(staffTransactionsProvider(staff.id));
    final transactions = txAsync.valueOrNull ?? [];
    final commissionRate = staff.commissionRate ?? 0;
    final totalSales = transactions.fold(0.0, (s, t) => s + t.total);
    final totalComm = totalSales * commissionRate / 100;
    final email = staff.email;
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
                    border: Border.all(color: AppColors.divider),
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
                                        : AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(
                                    staff.isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: staff.isActive
                                          ? const Color(0xFF16A34A)
                                          : AppColors.textSecondary,
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
                                    color: AppColors.textSecondary),
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
                                    color: AppColors.primary,
                                  ),
                                if (staff.phone != null)
                                  _InfoChip(
                                    icon: Icons.phone_outlined,
                                    label: staff.phone!,
                                    color: AppColors.primary,
                                  ),
                                if (email != null)
                                  _InfoChip(
                                    icon: Icons.email_outlined,
                                    label: email,
                                    color: AppColors.textSecondary,
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
                      iconColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _StatCard(
                      label: 'Services',
                      value: '${transactions.length}',
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
                    border: Border.all(color: AppColors.divider),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: txAsync.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(24),
                          child: Center(
                              child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : transactions.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No recent activity.',
                                  style: TextStyle(
                                      fontSize: 13,
                                      color: AppColors.textSecondary)),
                            )
                          : Column(
                              children: [
                                for (int i = 0;
                                    i < transactions.length;
                                    i++) ...[
                                  if (i > 0)
                                    const Divider(
                                        height: 1,
                                        color: AppColors.surfaceVariant),
                                  _ActivityTile(
                                    transaction: transactions[i],
                                    commissionRate: commissionRate,
                                  ),
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
                      border: Border.all(color: AppColors.divider),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.email_outlined,
                            size: 18, color: AppColors.textSecondary),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(email,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                        ),
                        const Icon(Icons.lock_outline,
                            size: 16, color: AppColors.border),
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
        border: Border.all(color: AppColors.divider),
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
                  fontSize: 11, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.transaction,
    required this.commissionRate,
  });
  final Transaction transaction;
  final double commissionRate;

  @override
  Widget build(BuildContext context) {
    final service =
        transaction.items?.firstOrNull?.displayName ?? 'Service';
    final commission = transaction.total * commissionRate / 100;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.spa_outlined,
                size: 18, color: AppColors.textSecondary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(service,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500)),
                Text(
                    '${transaction.displayName} · ${_dateLabel(transaction.createdAt)}',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('NPR ${transaction.total.toStringAsFixed(0)}',
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              if (commissionRate > 0)
                Text('+NPR ${commission.toStringAsFixed(0)} comm.',
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
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w500)),
    );
  }
}
