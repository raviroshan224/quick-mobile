import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/staff/domain/staff_models.dart';
import '../../../../features/staff/presentation/providers/staff_provider.dart';
import 'settings_screen.dart' show salonSettingsProvider;
import '../../../../shared/widgets/pull_to_refresh.dart';

// ─── Avatar colors (cycle by index) ───────────────────────────────────────────

const _avatarColors = [
  Color(0xFF6B7A3D), // olive
  Color(0xFF4D5A2C), // dark olive
  Color(0xFF8A9950), // medium olive
  Color(0xFF111111), // black
  Color(0xFF3A3A3A), // dark grey
  Color(0xFF5A5A5A), // grey
  Color(0xFF9A9A9A), // light grey
  Color(0xFFB5C090), // pale olive
];

Color _avatarColor(int index) => _avatarColors[index % _avatarColors.length];

// ─── Screen ───────────────────────────────────────────────────────────────────

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key});

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  String _search = '';
  bool _activeOnly = true; // true = Active tab, false = Inactive tab

  @override
  Widget build(BuildContext context) {
    final staffAsync = ref.watch(staffListProvider);
    final commissionEnabled =
        ref.watch(salonSettingsProvider).commissionEnabled;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => context.go(AppRoutes.more),
        ),
        title: const Text('Staff',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () => context.push('/more/staff/new'),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // ── Search bar ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _SearchBar(
                onChanged: (v) => setState(() => _search = v),
              ),
            ),
            // ── Active / Inactive tabs ─────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _TabToggle(
                activeOnly: _activeOnly,
                onChanged: (v) => setState(() => _activeOnly = v),
              ),
            ),
            const SizedBox(height: 8),
            // ── List ───────────────────────────────────────────────────────
            Expanded(
              child: PullToRefresh(
                onRefresh: () => ref.refresh(staffListProvider.future),
                child: staffAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    Center(child: Text('Error: $e')),
                data: (allStaff) {
                  final filtered = allStaff.where((s) {
                    final matchActive = s.isActive == _activeOnly;
                    final q = _search.toLowerCase();
                    final matchSearch = q.isEmpty ||
                        s.fullName.toLowerCase().contains(q) ||
                        s.specialties
                            .any((sp) => sp.toLowerCase().contains(q));
                    return matchActive && matchSearch;
                  }).toList();

                  if (filtered.isEmpty) {
                    return _EmptyState(activeOnly: _activeOnly);
                  }

                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return _StaffTile(
                        staff: s,
                        avatarColor: _avatarColor(
                            allStaff.indexOf(s)),
                        showCommission: commissionEnabled,
                        onTap: () =>
                            context.push('/more/staff/${s.id}'),
                      );
                    },
                  );
                },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: 'Search by name or specialty',
        hintStyle: const TextStyle(
            color: AppColors.textTertiary, fontSize: 14),
        prefixIcon: const Icon(Icons.search,
            size: 18, color: AppColors.textTertiary),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: AppColors.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Colors.black, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 10),
      ),
    );
  }
}

// ─── Active / Inactive tab toggle ────────────────────────────────────────────

class _TabToggle extends StatelessWidget {
  const _TabToggle({required this.activeOnly, required this.onChanged});
  final bool activeOnly;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.divider,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          _Tab(
            label: 'Active',
            isSelected: activeOnly,
            onTap: () => onChanged(true),
          ),
          _Tab(
            label: 'Inactive',
            isSelected: !activeOnly,
            onTap: () => onChanged(false),
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(
            color: isSelected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.07),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight:
                  isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? Colors.black
                  : AppColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Staff tile ───────────────────────────────────────────────────────────────

class _StaffTile extends StatelessWidget {
  const _StaffTile({
    required this.staff,
    required this.avatarColor,
    required this.onTap,
    this.showCommission = true,
  });
  final StaffModel staff;
  final Color avatarColor;
  final VoidCallback onTap;
  final bool showCommission;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            // Colored circle avatar
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: avatarColor,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                staff.initials,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Name row
                  Row(
                    children: [
                      Text(
                        staff.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Active indicator dot
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: staff.isActive
                              ? const Color(0xFF10B981)
                              : AppColors.border,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Specialties chip row
                  if (staff.specialties.isNotEmpty)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: staff.specialties
                            .take(3)
                            .map((sp) => _SpecialtyChip(label: sp))
                            .toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Commission rate badge
            if (showCommission && staff.commissionRate != null)
              _CommissionBadge(rate: staff.commissionRate!),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.border),
          ],
        ),
      ),
    );
  }
}

// ─── Specialty chip ───────────────────────────────────────────────────────────

class _SpecialtyChip extends StatelessWidget {
  const _SpecialtyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 5),
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: AppColors.textSecondary,
        ),
      ),
    );
  }
}

// ─── Commission badge ─────────────────────────────────────────────────────────

class _CommissionBadge extends StatelessWidget {
  const _CommissionBadge({required this.rate});
  final double rate;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 4),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primaryLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${rate.toStringAsFixed(0)}%',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.activeOnly});
  final bool activeOnly;

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
              decoration: const BoxDecoration(
                color: AppColors.surfaceVariant,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded,
                  size: 36, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            Text(
              activeOnly
                  ? 'No active staff members'
                  : 'No inactive staff members',
              style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              activeOnly
                  ? 'Add your first team member to get started.'
                  : 'All your staff are currently active.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
