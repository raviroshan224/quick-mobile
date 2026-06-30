import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/customers_repository.dart';
import '../../domain/customer_models.dart';

final customersRepoProvider = Provider<CustomersRepository>(
  (ref) => CustomersRepository(ref.read(apiClientProvider)),
);

final customerSearchQueryProvider = StateProvider<String>((ref) => '');

final customersProvider = FutureProvider<List<CustomerModel>>((ref) {
  final query = ref.watch(customerSearchQueryProvider);
  return ref.watch(customersRepoProvider).getAll(query: query.isEmpty ? null : query);
});

final customerDetailProvider =
    FutureProvider.family<CustomerModel, String>((ref, id) {
  return ref.watch(customersRepoProvider).getById(id);
});
