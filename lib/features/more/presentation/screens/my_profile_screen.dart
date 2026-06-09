import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../../features/auth/data/mock_auth_repository.dart';
import '../../../../features/staff/data/mock_staff_repository.dart';
import '../../../../features/staff/domain/staff_models.dart';
import '../../../../core/constants/app_constants.dart';

// ─── File-level provider ──────────────────────────────────────────────────────

final _myStaffProfileProvider = FutureProvider<StaffModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final all = await MockStaffRepository().getAll();
  return all.where((s) => s.userId == user.id).firstOrNull;
});

// ─── Screen ───────────────────────────────────────────────────────────────────

class MyProfileScreen extends ConsumerWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final staffAsync = ref.watch(_myStaffProfileProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
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
    final email =
        MockAuthRepository.getEmailByUserId(user.id) ?? user.email;
    final commissionRate = staff?.commissionRate;
    final mockTotal = 480.0;
    final commissionEarned = commissionRate != null
        ? (commissionRate * mockTotal / 100).truncate()
        : 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // ── Profile hero card ─────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            children: [
              // Avatar
              CircleAvatar(
                radius: 36,
                backgroundColor: const Color(0xFF6366F1),
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
                      : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  user.isOwner ? 'Owner' : 'Staff',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: user.isOwner
                        ? Colors.white
                        : const Color(0xFF6B7280),
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
                value: '12 services',
                label: 'This Week',
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                value: '48 services',
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
            border: Border.all(color: const Color(0xFFE5E7EB)),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(Icons.email_outlined,
                  size: 18, color: Color(0xFF6B7280)),
              const SizedBox(width: 12),
              const Text(
                'Email',
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF6B7280),
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
            icon: const Icon(Icons.logout_rounded, size: 18),
            label: const Text('Sign Out'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF6B7280),
              side: const BorderSide(color: Color(0xFFE5E7EB)),
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
              await innerRef.read(authProvider.notifier).logout();
              if (context.mounted) context.go(AppRoutes.login);
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
        color: Color(0xFF9CA3AF),
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
        Icon(icon, size: 14, color: const Color(0xFF9CA3AF)),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF6B7280),
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
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
              color: Color(0xFF9CA3AF),
            ),
            textAlign: TextAlign.center,
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
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 13,
          color: Color(0xFF6B7280),
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
