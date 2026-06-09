import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/constants/app_constants.dart';

class MainShell extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).matchedLocation;
    final index = _locationToIndex(location);

    return Scaffold(
      backgroundColor: Colors.white,
      body: child,
      bottomNavigationBar: _BottomNav(
        selectedIndex: index,
        onTap: (i) => context.go(_tabs[i]),
      ),
    );
  }
}

class _BottomNav extends StatelessWidget {
  const _BottomNav({required this.selectedIndex, required this.onTap});
  final int selectedIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB), width: 0.5)),
      ),
      child: BottomNavigationBar(
        currentIndex: selectedIndex,
        onTap: onTap,
        type: BottomNavigationBarType.fixed,
        backgroundColor: Colors.white,
        selectedItemColor: Colors.black,
        unselectedItemColor: const Color(0xFF9CA3AF),
        selectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w400,
        ),
        elevation: 0,
        items: const [
          BottomNavigationBarItem(
            icon: _NavIcon(icon: Icons.home_outlined),
            activeIcon: _NavIcon(icon: Icons.home_rounded, active: true),
            label: 'Dashboard',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(icon: Icons.grid_view_rounded),
            activeIcon: _NavIcon(icon: Icons.grid_view_rounded, active: true),
            label: 'Checkout',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(icon: Icons.swap_horiz_rounded),
            activeIcon: _NavIcon(icon: Icons.swap_horiz_rounded, active: true),
            label: 'Transactions',
          ),
          BottomNavigationBarItem(
            icon: _NavIcon(icon: Icons.menu_rounded),
            activeIcon: _NavIcon(icon: Icons.menu_rounded, active: true),
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
          color: active ? Colors.black : const Color(0xFF9CA3AF)),
    );
  }
}
