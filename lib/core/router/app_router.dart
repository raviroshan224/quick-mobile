import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/checkout/presentation/screens/checkout_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/more/presentation/screens/setup_guide_screen.dart';
import '../../features/discounts/screens/discounts_screen.dart';
import '../../features/discounts/screens/discount_form_screen.dart';
import '../../features/more/presentation/screens/items_screen.dart';
import '../../features/more/presentation/screens/services_screen.dart';
import '../../features/more/presentation/screens/service_form_screen.dart';
import '../../features/more/presentation/screens/customers_screen.dart';
import '../../features/more/presentation/screens/customer_detail_screen.dart';
import '../../features/more/presentation/screens/customer_form_screen.dart';
import '../../features/more/presentation/screens/drawers_screen.dart';
import '../../features/more/presentation/screens/reports_screen.dart';
import '../../features/more/presentation/screens/settings_screen.dart';
import '../../features/more/presentation/screens/support_screen.dart';
import '../../features/more/presentation/screens/dashboard_screen.dart';
import '../../features/more/presentation/screens/staff_screen.dart';
import '../../features/more/presentation/screens/staff_detail_screen.dart';
import '../../features/more/presentation/screens/staff_form_screen.dart';
import '../../features/more/presentation/screens/refunds_screen.dart';
import '../../features/more/presentation/screens/image_library_screen.dart';
import '../../features/more/presentation/screens/stock_movement_screen.dart';
import '../../features/more/presentation/screens/my_profile_screen.dart';
import '../../shared/widgets/main_shell.dart';
import '../constants/app_constants.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final authNotifier = ref.watch(authProvider.notifier);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;

      if (loc == AppRoutes.splash) return null;

      final isLoggedIn = auth.isAuthenticated;
      final goingToLogin = loc == AppRoutes.login;

      if (!isLoggedIn && !goingToLogin) return AppRoutes.login;
      if (isLoggedIn && goingToLogin) return AppRoutes.dashboard;
      return null;
    },
    refreshListenable: _RouterRefresh(authNotifier),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
              path: AppRoutes.dashboard,
              builder: (_, _) => const DashboardScreen()),
          GoRoute(
              path: AppRoutes.checkout,
              builder: (_, _) => const CheckoutScreen()),
          GoRoute(
              path: AppRoutes.transactions,
              builder: (_, _) => const TransactionsScreen()),
          GoRoute(
              path: AppRoutes.notifications,
              builder: (_, _) => const NotificationsScreen()),
          GoRoute(
              path: AppRoutes.more,
              builder: (_, _) => const MoreScreen()),
          GoRoute(
              path: AppRoutes.moreSetupGuide,
              builder: (_, _) => const SetupGuideScreen()),
          GoRoute(
              path: AppRoutes.moreItems,
              builder: (_, _) => const ItemsScreen()),
          GoRoute(
              path: AppRoutes.moreServices,
              builder: (_, _) => const ServicesScreen()),
          GoRoute(
              path: AppRoutes.serviceNew,
              builder: (_, _) => const ServiceFormScreen()),
          GoRoute(
              path: '/more/services/:id/edit',
              builder: (_, state) => ServiceFormScreen(
                    serviceId: state.pathParameters['id'],
                  )),
          GoRoute(
              path: AppRoutes.moreCustomers,
              builder: (_, _) => const CustomersScreen()),
          GoRoute(
              path: '/more/customers/new',
              builder: (_, _) => const CustomerFormScreen()),
          GoRoute(
              path: '/more/customers/:id',
              builder: (_, state) => CustomerDetailScreen(
                    customerId: state.pathParameters['id']!,
                  )),
          GoRoute(
              path: '/more/customers/:id/edit',
              builder: (_, state) => CustomerFormScreen(
                    customerId: state.pathParameters['id'],
                  )),
          GoRoute(
              path: AppRoutes.moreDrawers,
              builder: (_, _) => const DrawersScreen()),
          GoRoute(
              path: AppRoutes.moreReports,
              builder: (_, _) => const ReportsScreen()),
          GoRoute(
              path: AppRoutes.moreSettings,
              builder: (_, _) => const SettingsScreen()),
          GoRoute(
              path: AppRoutes.moreSupport,
              builder: (_, _) => const SupportScreen()),
          GoRoute(
              path: '/more/my-profile',
              builder: (_, _) => const MyProfileScreen()),
          GoRoute(
              path: AppRoutes.moreDiscounts,
              builder: (_, _) => const DiscountsScreen()),
          GoRoute(
              path: AppRoutes.moreDiscountsNew,
              builder: (_, _) => const DiscountFormScreen()),
          GoRoute(
              path: '/more/discounts/:id',
              builder: (_, state) => DiscountFormScreen(
                    discountId: state.pathParameters['id'],
                  )),
          GoRoute(
              path: AppRoutes.moreStaff,
              builder: (_, _) => const StaffScreen()),
          GoRoute(
              path: AppRoutes.moreStaffNew,
              builder: (_, _) => const StaffFormScreen()),
          GoRoute(
              path: '/more/staff/:id',
              builder: (_, state) => StaffDetailScreen(
                    staffId: state.pathParameters['id']!,
                  )),
          GoRoute(
              path: '/more/staff/:id/edit',
              builder: (_, state) => StaffFormScreen(
                    staffId: state.pathParameters['id'],
                  )),
          GoRoute(
              path: AppRoutes.moreRefunds,
              builder: (_, _) => const RefundsScreen()),
          GoRoute(
              path: AppRoutes.moreImageLibrary,
              builder: (_, _) => const ImageLibraryScreen()),
          GoRoute(
              path: AppRoutes.moreStockMovement,
              builder: (_, _) => const StockMovementScreen()),
        ],
      ),
    ],
  );
});

class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(StateNotifier notifier) {
    notifier.addListener((_) => notifyListeners());
  }
}
