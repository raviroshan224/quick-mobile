import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/models/business_type.dart';
import '../../../auth/domain/user_model.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../more/presentation/screens/settings_screen.dart'
    show salonSettingsProvider;

/// Device cache of the company's business type. The backend (GET /settings)
/// is the source of truth; this only covers the moment between app start and
/// settings loading (or an offline start), so a pharmacy doesn't briefly see
/// salon tabs.
class BusinessTypeStore {
  static const _kPrefix = 'business_type_company_';

  static String _key(UserModel user) => '$_kPrefix${user.companyId ?? user.id}';

  static Future<BusinessType?> load(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    return BusinessType.tryParse(prefs.getString(_key(user)));
  }

  static Future<void> save(UserModel user, BusinessType type) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(user), type.toApi());
  }
}

final _cachedBusinessTypeProvider = FutureProvider<BusinessType?>((ref) {
  final user = ref.watch(currentUserProvider);
  return user == null ? null : BusinessTypeStore.load(user);
});

/// The signed-in business's type: the server's value once settings have
/// loaded, else the cached one, else SALON (what the app was built for).
final businessTypeProvider = Provider<BusinessType>((ref) {
  final fromServer = ref.watch(salonSettingsProvider).businessType;
  final cached = ref.watch(_cachedBusinessTypeProvider).valueOrNull;
  final user = ref.watch(currentUserProvider);
  if (fromServer != null && fromServer != cached && user != null) {
    BusinessTypeStore.save(user, fromServer);
  }
  return fromServer ?? cached ?? BusinessType.salon;
});
