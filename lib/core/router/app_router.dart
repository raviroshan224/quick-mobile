import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/auth/domain/user_model.dart';
import '../../features/auth/presentation/screens/splash_screen.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/signup_screen.dart';
import '../../features/auth/presentation/screens/otp_screen.dart';
import '../../features/auth/presentation/screens/forgot_password_screen.dart';
import '../../features/auth/presentation/screens/verify_reset_code_screen.dart';
import '../../features/auth/presentation/screens/reset_password_screen.dart';
import '../../features/auth/presentation/screens/profile_picker_screen.dart';
import '../../features/checkout/presentation/screens/checkout_screen.dart';
import '../../features/transactions/presentation/screens/transactions_screen.dart';
import '../../features/transactions/presentation/screens/transaction_detail_screen.dart';
import '../../features/notifications/presentation/screens/notifications_screen.dart';
import '../../features/more/presentation/screens/more_screen.dart';
import '../../features/more/presentation/screens/setup_guide_screen.dart';
import '../../features/discounts/screens/discounts_screen.dart';
import '../../features/discounts/screens/discount_form_screen.dart';
import '../../features/payment_modes/screens/payment_modes_screen.dart';
import '../../features/payment_modes/screens/payment_mode_form_screen.dart';
import '../../features/more/presentation/screens/items_screen.dart';
import '../../features/more/presentation/screens/item_form_screen.dart';
import '../../features/more/presentation/screens/services_screen.dart';
import '../../features/more/presentation/screens/service_form_screen.dart';
import '../../features/more/presentation/screens/customers_screen.dart';
import '../../features/more/presentation/screens/bookings_screen.dart';
import '../../features/more/presentation/screens/customer_detail_screen.dart';
import '../../features/more/presentation/screens/customer_form_screen.dart';
import '../../features/more/presentation/screens/drawers_screen.dart';
import '../../features/more/presentation/screens/reports_screen.dart';
import '../../features/more/presentation/screens/settings_screen.dart';
import '../../features/cash_drawer_hardware/presentation/screens/cash_drawer_settings_screen.dart';
import '../../features/more/presentation/screens/support_screen.dart';
import '../../features/more/presentation/screens/privacy_policy_screen.dart';
import '../../features/more/presentation/screens/terms_screen.dart';
import '../../features/more/presentation/screens/dashboard_screen.dart';
import '../../features/more/presentation/screens/staff_screen.dart';
import '../../features/more/presentation/screens/staff_detail_screen.dart';
import '../../features/more/presentation/screens/staff_form_screen.dart';
import '../../features/more/presentation/screens/staff_history_screen.dart';
import '../../features/more/presentation/screens/refunds_screen.dart';
import '../../features/more/presentation/screens/image_library_screen.dart';
import '../../features/more/presentation/screens/stock_movement_screen.dart';
import '../../features/more/presentation/screens/expiring_stock_screen.dart';
import '../../features/more/presentation/screens/my_profile_screen.dart';
import '../../features/settings/presentation/providers/business_type_provider.dart';
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

      // While checking stored token, stay on splash.
      if (auth.status == AuthStatus.initial || auth.status == AuthStatus.loading) {
        return null;
      }

      // Profile picker — owner session is valid but no profile selected yet.
      if (auth.status == AuthStatus.pickingProfile && loc != AppRoutes.profiles) {
        return AppRoutes.profiles;
      }

      // Redirect to OTP screen when login sent the OTP but not verified yet.
      if (auth.status == AuthStatus.pendingOtp && loc != '/verify-otp') {
        return '/verify-otp';
      }

      final isLoggedIn = auth.isAuthenticated;
      // Password reset is two steps: verify the code first, then set a new
      // password. Send the user to whichever step they haven't finished yet.
      if (auth.status == AuthStatus.resetPending) {
        if (auth.resetOtp == null && loc != AppRoutes.verifyResetCode) {
          return AppRoutes.verifyResetCode;
        }
        if (auth.resetOtp != null && loc != AppRoutes.resetPassword) {
          return AppRoutes.resetPassword;
        }
      }

      final onAuthScreen = loc == AppRoutes.login ||
          loc == AppRoutes.signup ||
          loc == '/verify-otp' ||
          loc == AppRoutes.forgotPassword ||
          loc == AppRoutes.verifyResetCode ||
          loc == AppRoutes.resetPassword ||
          loc == AppRoutes.profiles;

      if (!isLoggedIn && auth.status != AuthStatus.pickingProfile && !onAuthScreen) {
        return AppRoutes.login;
      }
      if (isLoggedIn && onAuthScreen) return AppRoutes.dashboard;

      // Staff cannot access owner-only routes — redirect to More.
      if (isLoggedIn && auth.user?.role == UserRole.staff) {
        const ownerOnly = [
          '/more/setup-guide',
          '/more/services',
          '/more/items',
          '/more/discounts',
          '/more/payment-modes',
          '/more/staff',
          '/more/reports',
          '/more/settings',
          '/more/cash-drawer',
          '/more/image-library',
          '/more/stock-movement',
          '/more/expiring-stock',
        ];
        if (ownerOnly.any((p) => loc == p || loc.startsWith('$p/'))) {
          return AppRoutes.more;
        }
      }

      // Features this kind of business doesn't use (e.g. a pharmacy has no
      // services or bookings) — hidden in More, and not reachable by link.
      if (isLoggedIn) {
        final businessType = ref.read(businessTypeProvider);
        final disabled = [
          if (!businessType.hasServices) AppRoutes.moreServices,
          if (!businessType.hasBookings) AppRoutes.moreBookings,
          if (!businessType.hasExpiryTracking) AppRoutes.moreExpiringStock,
        ];
        if (disabled.any((p) => loc == p || loc.startsWith('$p/'))) {
          return AppRoutes.more;
        }
      }

      return null;
    },
    refreshListenable: _RouterRefresh(authNotifier),
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (_, _) => const SplashScreen(),
      ),
      GoRoute(
        path: AppRoutes.profiles,
        builder: (_, _) => const ProfilePickerScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (_, _) => const SignupScreen(),
      ),
      GoRoute(
        path: '/verify-otp',
        builder: (_, _) => const OtpScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        builder: (_, _) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.verifyResetCode,
        builder: (_, _) => const VerifyResetCodeScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (_, _) => const ResetPasswordScreen(),
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
              path: '/transactions/:id',
              builder: (_, state) => TransactionDetailScreen(
                    transactionId: state.pathParameters['id']!,
                  )),
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
              path: '/more/items/new',
              builder: (_, state) => ItemFormScreen(
                    initialBarcode: state.uri.queryParameters['barcode'],
                  )),
          GoRoute(
              path: '/more/items/:id/edit',
              builder: (_, state) => ItemFormScreen(
                    productId: state.pathParameters['id'],
                  )),
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
              path: AppRoutes.moreBookings,
              builder: (_, _) => const BookingsScreen()),
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
              path: AppRoutes.moreCashDrawer,
              builder: (_, _) => const CashDrawerSettingsScreen()),
          GoRoute(
              path: AppRoutes.moreSupport,
              builder: (_, _) => const SupportScreen()),
          GoRoute(
              path: AppRoutes.morePrivacyPolicy,
              builder: (_, _) => const PrivacyPolicyScreen()),
          GoRoute(
              path: AppRoutes.moreTerms,
              builder: (_, _) => const TermsScreen()),
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
              path: AppRoutes.morePaymentModes,
              builder: (_, _) => const PaymentModesScreen()),
          GoRoute(
              path: AppRoutes.morePaymentModesNew,
              builder: (_, _) => const PaymentModeFormScreen()),
          GoRoute(
              path: '/more/payment-modes/:id',
              builder: (_, state) => PaymentModeFormScreen(
                    paymentModeId: state.pathParameters['id'],
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
              path: '/more/staff/:id/history',
              builder: (_, state) => StaffHistoryScreen(
                    staffId: state.pathParameters['id']!,
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
          GoRoute(
              path: AppRoutes.moreExpiringStock,
              builder: (_, _) => const ExpiringStockScreen()),
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
