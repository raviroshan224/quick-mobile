import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/services_repository.dart';
import '../../domain/service_models.dart';

final _servicesRepoProvider = Provider<ServicesRepository>(
  (ref) => ServicesRepository(ref.read(apiClientProvider)),
);

final servicesListProvider = FutureProvider<List<ServiceModel>>((ref) {
  return ref.watch(_servicesRepoProvider).getServices(isActive: null);
});

final serviceCategoriesListProvider = FutureProvider<List<ServiceCategory>>((ref) {
  return ref.watch(_servicesRepoProvider).getCategories();
});

final activeServicesProvider = FutureProvider<List<ServiceModel>>((ref) {
  return ref.watch(_servicesRepoProvider).getServices(); // isActive: true by default
});
