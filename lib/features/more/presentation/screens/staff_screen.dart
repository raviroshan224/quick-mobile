import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/staff/data/mock_staff_repository.dart';
import '../../../../features/staff/domain/staff_models.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final _allStaffProvider = FutureProvider<List<StaffModel>>((ref) {
  return MockStaffRepository().getAll();
});

// ─── Avatar colors (cycle by index) ───────────────────────────────────────────

const _avatarColors = [
  Color(0xFF6366F1),
  Color(0xFF10B981),
  Color(0xFFF59E0B),
  Color(0xFF0EA5E9),
  Color(0xFFEC4899),
  Color(0xFF8B5CF6),
  Color(0xFFEF4444),
  Color(0xFF14B8A6),
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
    final staffAsync = ref.watch(_allStaffProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Custom header ──────────────────────────────────────────────
            _Header(
              onAdd: () => context.push('/more/staff/new'),
            ),
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
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const SizedBox(height: 10),
                    itemBuilder: (_, i) {
                      final s = filtered[i];
                      return _StaffTile(
                        staff: s,
                        avatarColor: _avatarColor(
                            allStaff.indexOf(s)),
                        onTap: () =>
                            context.push('/more/staff/${s.id}'),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
      // ── FAB-style Add Staff button ────────────────────────────────────────
      floatingActionButton: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FloatingActionButton.extended(
            onPressed: () => context.push('/more/staff/new'),
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(26),
            ),
            icon: const Icon(Icons.add, size: 20),
            label: const Text(
              'Add Staff',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.1,
              ),
            ),
          ),
        ),
      ),
      floatingActionButtonLocation:
          FloatingActionButtonLocation.centerFloat,
    );
  }
}

// ─── Header ───────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({required this.onAdd});
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      child: Row(
        children: [
          GestureDetector(
            onTap: () => context.go(AppRoutes.more),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 18, color: Colors.black),
          ),
          const Spacer(),
          const Text(
            'Staff',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
          const Spacer(),
          GestureDetector(
            onTap: onAdd,
            child: const Icon(Icons.add, size: 24, color: Colors.black),
          ),
        ],
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
            color: Color(0xFF9CA3AF), fontSize: 14),
        prefixIcon: const Icon(Icons.search,
            size: 18, color: Color(0xFF9CA3AF)),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
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
        color: const Color(0xFFE5E7EB),
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
                  : const Color(0xFF6B7280),
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
  });
  final StaffModel staff;
  final Color avatarColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE5E7EB)),
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
                          color: Color(0xFF111827),
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
                              : const Color(0xFFD1D5DB),
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
            if (staff.commissionRate != null)
              _CommissionBadge(rate: staff.commissionRate!),
            const Icon(Icons.chevron_right,
                size: 18, color: Color(0xFFD1D5DB)),
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
        color: const Color(0xFFF3F4F6),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: Color(0xFF374151),
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
        color: const Color(0xFFEEF2FF),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${rate.toStringAsFixed(0)}%',
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6366F1),
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
                color: Color(0xFFF3F4F6),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.people_outline_rounded,
                  size: 36, color: Color(0xFF9CA3AF)),
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
                  fontSize: 13, color: Color(0xFF6B7280)),
            ),
          ],
        ),
      ),
    );
  }
}
