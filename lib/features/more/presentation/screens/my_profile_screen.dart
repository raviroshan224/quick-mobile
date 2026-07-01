import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/staff/domain/staff_models.dart';
import '../../../../features/staff/presentation/providers/staff_provider.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/transactions/data/transactions_repository.dart';
import '../../../../features/transactions/domain/transaction_models.dart';
import '../../../../core/network/api_client.dart';

// UTC ISO string with ms precision — Dart's toIso8601String() produces 6-decimal
// microseconds that JS's Date constructor rejects.
String _utcMs(DateTime local) {
  final u = local.toUtc();
  String p2(int n) => n.toString().padLeft(2, '0');
  String p3(int n) => n.toString().padLeft(3, '0');
  return '${u.year}-${p2(u.month)}-${p2(u.day)}'
      'T${p2(u.hour)}:${p2(u.minute)}:${p2(u.second)}.${p3(u.millisecond)}Z';
}

// ─── File-level providers ─────────────────────────────────────────────────────

final _myStaffProfileProvider = FutureProvider<StaffModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final all = await ref.watch(staffListProvider.future);
  return all.where((s) => s.userId == user.id).firstOrNull;
});

final _txRepoProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.read(apiClientProvider)),
);

// Transactions processed by this user (as cashier), newest first.
final _myRecentTxProvider =
    FutureProvider.autoDispose<List<Transaction>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  final result = await ref
      .read(_txRepoProvider)
      .getAll(limit: 15, userId: user.id);
  return result.items;
});

typedef _TxStats = ({int count, double revenue});

// Transactions processed this week (by cashier userId).
final _myWeekStatsProvider =
    FutureProvider.autoDispose<_TxStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return (count: 0, revenue: 0.0);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, now.day - (now.weekday - 1));
  final result = await ref.read(_txRepoProvider).getAll(
        limit: 100,
        userId: user.id,
        from: _utcMs(start),
        to: _utcMs(DateTime(now.year, now.month, now.day, 23, 59, 59, 999)),
      );
  final revenue = result.items.fold(0.0, (s, t) {
    if (t.status == TransactionStatus.completed ||
        t.status == TransactionStatus.partiallyRefunded) {
      return s + t.total;
    }
    return s;
  });
  return (count: result.items.length, revenue: revenue);
});

// Transactions processed this month (by cashier userId).
final _myMonthStatsProvider =
    FutureProvider.autoDispose<_TxStats>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return (count: 0, revenue: 0.0);
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final result = await ref.read(_txRepoProvider).getAll(
        limit: 100,
        userId: user.id,
        from: _utcMs(start),
        to: _utcMs(DateTime(now.year, now.month, now.day, 23, 59, 59, 999)),
      );
  final revenue = result.items.fold(0.0, (s, t) {
    if (t.status == TransactionStatus.completed ||
        t.status == TransactionStatus.partiallyRefunded) {
      return s + t.total;
    }
    return s;
  });
  return (count: result.items.length, revenue: revenue);
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final staffAsync = ref.watch(_myStaffProfileProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom header ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 16, 4),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded,
                        size: 18, color: Colors.black),
                    onPressed: () => context.go(AppRoutes.more),
                  ),
                  const Expanded(
                    child: Text(
                      'My Profile',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // ── Body ─────────────────────────────────────────────────────
            Expanded(
              child: staffAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (err, st) =>
                    const Center(child: Text('Something went wrong.')),
                data: (staff) {
                  if (user == null) {
                    return const Center(child: Text('Not logged in.'));
                  }
                  return _ProfileBody(ref: ref, staff: staff);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Profile body ─────────────────────────────────────────────────────────────

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.ref, required this.staff});

  final WidgetRef ref;
  final StaffModel? staff;

  @override
  Widget build(BuildContext context, WidgetRef innerRef) {
    final user = innerRef.watch(currentUserProvider)!;
    final email = user.email;
    final commissionRate = staff?.commissionRate;
    final weekStats = innerRef.watch(_myWeekStatsProvider).valueOrNull;
    final monthStats = innerRef.watch(_myMonthStatsProvider).valueOrNull;
    final recentTx = innerRef.watch(_myRecentTxProvider).valueOrNull ?? [];
    final commissionEarned = (commissionRate != null && monthStats != null)
        ? (commissionRate * monthStats.revenue / 100).truncate()
        : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Profile hero card ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: AppColors.divider),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              // Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: AppColors.primary,
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Name
              Text(
                '${user.firstName} ${user.lastName}',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: Colors.black,
                ),
              ),
              const SizedBox(height: 8),

              // Role badge
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: user.isOwner
                      ? Colors.black
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.isOwner ? 'Owner' : 'Staff',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: user.isOwner
                        ? Colors.white
                        : AppColors.textSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Email row
              _InfoRow(icon: Icons.email_outlined, value: email),

              // Phone row (staff only)
              if (staff?.phone != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                    icon: Icons.phone_outlined, value: staff!.phone!),
              ],

              // Commission row (staff only)
              if (commissionRate != null) ...[
                const SizedBox(height: 8),
                _InfoRow(
                  icon: Icons.percent_rounded,
                  value:
                      '${commissionRate.toStringAsFixed(0)}% commission rate',
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // ── Stats row ─────────────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: _StatCard(
                value: weekStats != null
                    ? '${weekStats.count} txns'
                    : '—',
                label: 'This Week',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: monthStats != null
                    ? '${monthStats.count} txns'
                    : '—',
                label: 'This Month',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: 'NPR $commissionEarned',
                label: 'Commission',
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // ── Recent Transactions ───────────────────────────────────────
        const _SectionHeader(text: 'RECENT TRANSACTIONS'),
        const SizedBox(height: 8),
        if (recentTx.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Center(
              child: Text(
                'No transactions yet',
                style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
              ),
            ),
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border.all(color: AppColors.divider),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: recentTx.asMap().entries.map((entry) {
                final i = entry.key;
                final tx = entry.value;
                final isLast = i == recentTx.length - 1;
                return Column(
                  children: [
                    _TxRow(tx: tx, onTap: () => context.push('/transactions/${tx.id}')),
                    if (!isLast)
                      const Divider(height: 1, indent: 16, endIndent: 16,
                          color: AppColors.divider),
                  ],
                );
              }).toList(),
            ),
          ),
        const SizedBox(height: 20),

        // ── Specialties section (staff with specialties only) ──────────
        if (staff != null && staff!.specialties.isNotEmpty) ...[
          const _SectionHeader(text: 'SPECIALTIES'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: staff!.specialties
                .map((s) => _SpecialtyChip(label: s))
                .toList(),
          ),
          const SizedBox(height: 20),
        ],

        // ── Login section ─────────────────────────────────────────────
        const _SectionHeader(text: 'LOGIN'),
        const SizedBox(height: 8),
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
              const SizedBox(width: 12),
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Flexible(
                child: Text(
                  email,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Colors.black,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),

        // ── Sign Out button ───────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(
              user.isOwner ? Icons.logout_rounded : Icons.swap_horiz_rounded,
              size: 18,
            ),
            label: Text(user.isOwner ? 'Sign Out' : 'Switch Profile'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.textSecondary,
              side: const BorderSide(color: AppColors.divider),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            onPressed: () async {
              final notifier = innerRef.read(authProvider.notifier);
              if (user.isOwner) {
                await notifier.logout();
                if (context.mounted) context.go(AppRoutes.login);
              } else {
                // Staff: go back to profile picker (keeps owner session alive).
                await notifier.switchProfile();
              }
            },
          ),
        ),
      ],
    );
  }
}

// ─── Private widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.textTertiary,
        letterSpacing: 0.8,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.value});
  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 14, color: AppColors.textTertiary),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: AppColors.divider),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textTertiary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.tx, required this.onTap});
  final Transaction tx;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isRefunded = tx.status == TransactionStatus.refunded ||
        tx.status == TransactionStatus.partiallyRefunded;
    final isVoided = tx.status == TransactionStatus.voided;

    final statusColor = isRefunded
        ? AppColors.danger
        : isVoided
            ? AppColors.textTertiary
            : AppColors.success;

    final hour = tx.createdAt.toLocal().hour;
    final minute = tx.createdAt.toLocal().minute.toString().padLeft(2, '0');
    final amPm = hour >= 12 ? 'PM' : 'AM';
    final hour12 = hour % 12 == 0 ? 12 : hour % 12;
    final timeStr = '$hour12:$minute $amPm';

    final now = DateTime.now();
    final txDate = tx.createdAt.toLocal();
    final isToday = txDate.year == now.year &&
        txDate.month == now.month &&
        txDate.day == now.day;
    final isYesterday = txDate.year == now.year &&
        txDate.month == now.month &&
        txDate.day == now.day - 1;
    final dayLabel =
        isToday ? 'Today' : isYesterday ? 'Yesterday' : '${txDate.day}/${txDate.month}';

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              margin: const EdgeInsets.only(right: 12),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: statusColor,
              ),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '#${tx.receiptNumber ?? tx.id.substring(0, 8).toUpperCase()}',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$dayLabel · $timeStr',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'NPR ${tx.total.toStringAsFixed(2)}',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: isVoided ? AppColors.textTertiary : Colors.black,
                decoration: isVoided ? TextDecoration.lineThrough : null,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 18, color: AppColors.textTertiary),
          ],
        ),
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
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: AppColors.textSecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
