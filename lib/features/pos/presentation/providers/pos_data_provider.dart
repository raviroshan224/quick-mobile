import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../services/data/services_repository.dart';
import '../../../services/domain/service_models.dart';
import '../../../staff/data/staff_repository.dart';
import '../../../staff/domain/staff_models.dart';

// ─── Repos ────────────────────────────────────────────────────────────────────

final _servicesRepoProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(ref.read(apiClientProvider)),
);
final _staffRepoProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.read(apiClientProvider)),
);

// ─── Services & categories ────────────────────────────────────────────────────

final serviceCategoriesProvider = FutureProvider<List<ServiceCategory>>((ref) {
  return ref.watch(_servicesRepoProvider).getCategories();
});

final selectedCategoryProvider = StateProvider<String?>((ref) => null);

final servicesProvider = FutureProvider<List<ServiceModel>>((ref) {
  final categoryId = ref.watch(selectedCategoryProvider);
  return ref.watch(_servicesRepoProvider).getServices(categoryId: categoryId);
});

final serviceSearchQueryProvider = StateProvider<String>((ref) => '');

final filteredServicesProvider = Provider<AsyncValue<List<ServiceModel>>>((ref) {
  final query = ref.watch(serviceSearchQueryProvider).toLowerCase().trim();
  final servicesAsync = ref.watch(servicesProvider);
  if (query.isEmpty) return servicesAsync;
  return servicesAsync.whenData(
    (services) => services.where((s) => s.name.toLowerCase().contains(query)).toList(),
  );
});

// ─── Staff ────────────────────────────────────────────────────────────────────

final activeStaffProvider = FutureProvider<List<StaffModel>>((ref) {
  return ref.watch(_staffRepoProvider).getAll(activeOnly: true);
});
