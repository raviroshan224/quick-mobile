import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../features/notifications/presentation/providers/notifications_provider.dart';
import 'quick_logo.dart';

class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.child});
  final Widget child;

  static const _tabs = [
    AppRoutes.dashboard,
    AppRoutes.checkout,
    AppRoutes.transactions,
    AppRoutes.more,
  ];

  int _locationToIndex(String loc) {
    if (loc.startsWith(AppRoutes.checkout)) return 1;
    if (loc.startsWith(AppRoutes.transactions)) return 2;
    if (loc.startsWith(AppRoutes.more)) return 3;
    return 0;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _locationToIndex(location);
    final logs = ref.watch(notificationLogsProvider).valueOrNull ?? [];
    final failedCount = logs.where((l) => !l.isSent).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _TopBar(),
      body: child,
      bottomNavigationBar: _BottomNav(
        selectedIndex: index,
        failedCount: failedCount,
        onTap: (i) => context.go(_tabs[i]),
      ),
    );
  }
}

class _TopBar extends StatelessWidget implements PreferredSizeWidget {
  @override
  Size get preferredSize => const Size.fromHeight(52);

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 52,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          const QuickLogo(size: 28),
          const SizedBox(width: 8),
          Text(
            'Quick',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({
    required this.selectedIndex,
    required this.onTap,
    required this.failedCount,
  });
  final int selectedIndex;
  final ValueChanged<int> onTap;
  final int failedCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
        elevation: 0,
        items: [
          const BottomNavigationBarItem(
            icon: _NavIcon(icon: Icons.home_outlined),
            activeIcon: _NavIcon(icon: Icons.home_rounded, active: true),
            label: 'Dashboard',
          ),
          const BottomNavigationBarItem(
            icon: _NavIcon(icon: Icons.grid_view_rounded),
            activeIcon: _NavIcon(icon: Icons.grid_view_rounded, active: true),
            label: 'Checkout',
          ),
          const BottomNavigationBarItem(
            icon: _NavIcon(icon: Icons.swap_horiz_rounded),
            activeIcon: _NavIcon(icon: Icons.swap_horiz_rounded, active: true),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: _BadgedNavIcon(
              icon: Icons.menu_rounded,
              count: failedCount,
            ),
            activeIcon: _BadgedNavIcon(
              icon: Icons.menu_rounded,
              active: true,
              count: failedCount,
            ),
            label: 'More',
          ),
        ],
      ),
    );
  }
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({required this.icon, this.active = false});
  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Icon(icon, size: 22,
          color: active ? AppColors.primary : AppColors.textTertiary),
    );
  }
}

class _BadgedNavIcon extends StatelessWidget {
  const _BadgedNavIcon({
    required this.icon,
    required this.count,
    this.active = false,
  });
  final IconData icon;
  final int count;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Icon(icon, size: 22,
              color: active ? AppColors.primary : AppColors.textTertiary),
          if (count > 0)
            Positioned(
              top: -4,
              right: -6,
              child: Container(
                width: 14,
                height: 14,
                decoration: const BoxDecoration(
                  color: AppColors.danger,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    count > 9 ? '9+' : '$count',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
