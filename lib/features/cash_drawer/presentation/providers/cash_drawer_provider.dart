import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mock_cash_drawer_repository.dart';
import '../../domain/cash_drawer_models.dart';

final _cashDrawerRepoProvider = Provider((_) => MockCashDrawerRepository());

final currentDrawerProvider = FutureProvider<CashDrawerSession?>((ref) {
  return ref.watch(_cashDrawerRepoProvider).getCurrent();
});
