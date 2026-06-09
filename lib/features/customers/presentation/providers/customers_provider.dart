import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mock_customers_repository.dart';
import '../../domain/customer_models.dart';

final _customersRepoProvider = Provider((_) => MockCustomersRepository());

final customerSearchQueryProvider = StateProvider<String>((ref) => '');

final customersProvider = FutureProvider<List<CustomerModel>>((ref) {
  final query = ref.watch(customerSearchQueryProvider);
  return ref.watch(_customersRepoProvider).getAll(query: query);
});
