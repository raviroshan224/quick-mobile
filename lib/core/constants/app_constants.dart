class AppConstants {
  AppConstants._();

  static const String appName = 'Salon POS';
  static const String tokenKey = 'auth_token';
  static const String userKey = 'current_user';

  static const String defaultBaseUrl = 'http://localhost:3000';
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const int defaultPageSize = 20;
}

class AppRoutes {
  AppRoutes._();

  // Auth
  static const String splash = '/splash';
  static const String login = '/login';

  // Bottom nav tabs
  static const String dashboard = '/dashboard';
  static const String checkout = '/checkout';
  static const String transactions = '/transactions';
  static const String notifications = '/notifications';
  static const String more = '/more';

  // More sub-screens
  static const String moreSetupGuide = '/more/setup-guide';
  static const String moreItems = '/more/items';
  static const String moreServices = '/more/services';
  static const String moreDiscounts = '/more/discounts';
  static const String moreDiscountsNew = '/more/discounts/new';
  static String moreDiscountEdit(String id) => '/more/discounts/$id';
  static const String moreCustomers = '/more/customers';
  static const String moreDrawers = '/more/drawers';
  static const String moreReports = '/more/reports';
  static const String moreSettings = '/more/settings';
  static const String moreSupport = '/more/support';

  // More sub-screens (continued)
  static const String moreStaff = '/more/staff';
  static const String moreStaffNew = '/more/staff/new';
  static const String moreRefunds = '/more/refunds';
  static const String moreImageLibrary = '/more/image-library';
  static const String moreStockMovement = '/more/stock-movement';

  // Legacy aliases (keep for any leftover references)
  static const String home = '/checkout';
  static const String pos = '/checkout';

  // Legacy tablet routes — unused in mobile build but kept so old screens compile
  static const String customers = '/more/customers';
  static const String customerNew = '/more/customers/new';
  static String customerDetail(String id) => '/more/customers/$id';
  static String customerEdit(String id) => '/more/customers/$id/edit';

  static const String staff = '/more/staff';
  static const String staffNew = '/more/staff/new';
  static String staffDetail(String id) => '/more/staff/$id';
  static String staffEdit(String id) => '/more/staff/$id/edit';

  static const String services = '/more/services';
  static const String serviceNew = '/more/services/new';
  static String serviceEdit(String id) => '/more/services/$id/edit';

  static const String inventory = '/more/items';
  static const String inventoryNew = '/more/items/new';
  static const String inventoryMovement = '/more/items/movement';

  static const String cashDrawer = '/more/drawers';
  static const String posReceipt = '/checkout/receipt';
}
