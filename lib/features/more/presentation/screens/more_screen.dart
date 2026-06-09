import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Color(0xFF9CA3AF),
            letterSpacing: 0.8,
          ),
        ),
      );
}

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final isOwner = ref.watch(isOwnerProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: const Text(
                'More',
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  if (!isOwner) ...[
                    _SectionLabel(text: 'ACCOUNT'),
                    _MoreTile(
                      icon: Icons.account_circle_outlined,
                      label: 'My Profile',
                      onTap: () => context.go('/more/my-profile'),
                    ),
                    const SizedBox(height: 8),
                  ],
                  _SectionLabel(text: 'MANAGE'),
                  _MoreTile(
                    icon: Icons.menu_book_outlined,
                    label: 'Setup Guide',
                    onTap: () => context.go(AppRoutes.moreSetupGuide),
                  ),
                  _MoreTile(
                    icon: Icons.spa_outlined,
                    label: 'Services',
                    onTap: () => context.go(AppRoutes.moreServices),
                  ),
                  _MoreTile(
                    icon: Icons.tag,
                    label: 'Inventory',
                    onTap: () => context.go(AppRoutes.moreItems),
                  ),
                  _MoreTile(
                    icon: Icons.local_offer_outlined,
                    label: 'Discounts',
                    onTap: () => context.go(AppRoutes.moreDiscounts),
                  ),
                  _MoreTile(
                    icon: Icons.person_outline_rounded,
                    label: 'Customers',
                    onTap: () => context.go(AppRoutes.moreCustomers),
                  ),
                  if (isOwner)
                    _MoreTile(
                      icon: Icons.people_outline_rounded,
                      label: 'Staff',
                      onTap: () => context.go(AppRoutes.moreStaff),
                    ),
                  const SizedBox(height: 8),
                  _SectionLabel(text: 'FINANCE'),
                  _MoreTile(
                    icon: Icons.point_of_sale_outlined,
                    label: 'Cash Drawer',
                    onTap: () => context.go(AppRoutes.moreDrawers),
                  ),
                  _MoreTile(
                    icon: Icons.assignment_return_outlined,
                    label: 'Refunds',
                    onTap: () => context.go(AppRoutes.moreRefunds),
                  ),
                  if (isOwner)
                    _MoreTile(
                      icon: Icons.bar_chart_rounded,
                      label: 'Reports',
                      onTap: () => context.go(AppRoutes.moreReports),
                    ),
                  const SizedBox(height: 8),
                  _SectionLabel(text: 'TOOLS'),
                  _MoreTile(
                    icon: Icons.photo_library_outlined,
                    label: 'Image Library',
                    onTap: () => context.go(AppRoutes.moreImageLibrary),
                  ),
                  _MoreTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Stock Movement',
                    onTap: () => context.go(AppRoutes.moreStockMovement),
                  ),
                  if (isOwner)
                    _MoreTile(
                      icon: Icons.settings_outlined,
                      label: 'Settings',
                      onTap: () => context.go(AppRoutes.moreSettings),
                    ),
                  _MoreTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Support',
                    onTap: () => context.go(AppRoutes.moreSupport),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
            // User profile at bottom
            if (user != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor: const Color(0xFFF3F4F6),
                      child: Text(user.initials,
                          style: const TextStyle(
                              color: Colors.black,
                              fontWeight: FontWeight.w600,
                              fontSize: 13)),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(user.fullName,
                              style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500)),
                          Text(user.email,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF9CA3AF))),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () =>
                          ref.read(authProvider.notifier).logout(),
                      child: const Icon(Icons.logout_rounded,
                          size: 20, color: Color(0xFF9CA3AF)),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MoreTile extends StatelessWidget {
  const _MoreTile(
      {required this.icon,
      required this.label,
      required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: Colors.black87),
            const SizedBox(width: 16),
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w400)),
            ),
          ],
        ),
      ),
    );
  }
}
