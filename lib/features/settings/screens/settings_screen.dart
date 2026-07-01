import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 16),
                child: Text('More',
                    style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
            ),
            SliverList(
              delegate: SliverChildListDelegate([
                _Row(
                  icon: Icons.design_services_outlined,
                  label: 'Services',
                  subtitle: 'Haircuts, facials, massage & more',
                  onTap: () => context.push(AppRoutes.moreServices),
                ),
                const Divider(indent: 56, height: 0),
                _Row(
                  icon: Icons.inventory_2_outlined,
                  label: 'Items',
                  subtitle: 'Retail products like shampoo, gel, polish',
                  onTap: () => context.push(AppRoutes.moreItems),
                ),
                const Divider(indent: 56, height: 0),
                _Row(
                  icon: Icons.local_offer_outlined,
                  label: 'Discounts',
                  subtitle: 'Percentage and fixed amount presets',
                  onTap: () => context.push(AppRoutes.moreDiscounts),
                ),
                const Divider(indent: 56, height: 0),
                _Row(
                  icon: Icons.people_outline,
                  label: 'Customers',
                  onTap: () => context.push(AppRoutes.customers),
                ),
                const Divider(indent: 56, height: 0),
                _Row(
                  icon: Icons.inbox_outlined,
                  label: 'Cash Drawer',
                  onTap: () {},
                ),
                const Divider(indent: 56, height: 0),
                _Row(
                  icon: Icons.bar_chart_outlined,
                  label: 'Reports',
                  onTap: () {},
                ),
                const Divider(indent: 56, height: 0),
                _Row(
                  icon: Icons.badge_outlined,
                  label: 'Staff',
                  onTap: () {},
                ),
                const Divider(indent: 56, height: 0),
                _Row(
                  icon: Icons.settings_outlined,
                  label: 'Settings',
                  onTap: () {},
                ),
                const Divider(indent: 56, height: 0),
                _Row(
                  icon: Icons.help_outline,
                  label: 'Setup Guide',
                  onTap: () {},
                ),
              ]),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _Row({
    required this.icon,
    required this.label,
    this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: AppColors.textPrimary, size: 22),
      title: Text(label,
          style: const TextStyle(
              fontSize: 15, fontWeight: FontWeight.w400)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(
                  fontSize: 12, color: AppColors.textSecondary))
          : null,
      trailing: const Icon(Icons.chevron_right,
          color: AppColors.textTertiary, size: 20),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}
