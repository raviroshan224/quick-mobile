import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mock_services_repository.dart';
import '../../domain/service_models.dart';

final _servicesRepoProvider = Provider((_) => MockServicesRepository());

final servicesListProvider = FutureProvider<List<ServiceModel>>((ref) {
  return ref.watch(_servicesRepoProvider).getServices();
});

final serviceCategoriesListProvider =
    FutureProvider<List<ServiceCategory>>((ref) {
  return ref.watch(_servicesRepoProvider).getCategories();
});
