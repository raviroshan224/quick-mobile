import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Settings', style: AppTextStyles.headlineMedium),
            const SizedBox(height: AppSpacing.lg),
            // Profile section
            _Section(
              title: 'Profile',
              children: [
                _SettingTile(
                  icon: Icons.person_outline,
                  title: user?.fullName ?? 'Unknown',
                  subtitle: user?.email ?? '',
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () {},
                ),
                _SettingTile(
                  icon: user?.isOwner == true
                      ? Icons.admin_panel_settings_outlined
                      : Icons.badge_outlined,
                  title: 'Role',
                  subtitle: user?.isOwner == true ? 'Owner / Admin' : 'Staff',
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Salon section
            _Section(
              title: 'Salon',
              children: [
                _SettingTile(
                  icon: Icons.store_outlined,
                  title: 'Salon Name',
                  subtitle: 'My Salon',
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () {},
                ),
                _SettingTile(
                  icon: Icons.location_on_outlined,
                  title: 'Address',
                  subtitle: 'Kathmandu, Nepal',
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // Payment section
            _Section(
              title: 'Payment',
              children: [
                _SettingTile(
                  icon: Icons.qr_code_rounded,
                  title: 'Fonepay Merchant ID',
                  subtitle: 'Not configured',
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () {},
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.lg),
            // System section
            _Section(
              title: 'System',
              children: [
                _SettingTile(
                  icon: Icons.info_outline_rounded,
                  title: 'App Version',
                  subtitle: '1.0.0 (Phase 1)',
                ),
                _SettingTile(
                  icon: Icons.logout_rounded,
                  title: 'Logout',
                  subtitle: 'Sign out of this account',
                  titleColor: AppColors.danger,
                  onTap: () => ref.read(authProvider.notifier).logout(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
              left: AppSpacing.sm, bottom: AppSpacing.sm),
          child: Text(title.toUpperCase(),
              style: AppTextStyles.labelSmall
                  .copyWith(letterSpacing: 1.0)),
        ),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
              borderRadius: AppRadius.lgBR,
              side: BorderSide(color: AppColors.divider)),
          child: Column(
            children: children
                .asMap()
                .entries
                .map((e) => Column(
                      children: [
                        e.value,
                        if (e.key < children.length - 1)
                          const Divider(height: 1, indent: 56),
                      ],
                    ))
                .toList(),
          ),
        ),
      ],
    );
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.titleColor,
  });
  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon,
          color: titleColor ?? AppColors.textSecondary, size: 22),
      title: Text(title,
          style: AppTextStyles.titleMedium
              .copyWith(color: titleColor ?? AppColors.textPrimary)),
      subtitle:
          subtitle != null ? Text(subtitle!, style: AppTextStyles.bodySmall) : null,
      trailing: trailing,
      onTap: onTap,
    );
  }
}
