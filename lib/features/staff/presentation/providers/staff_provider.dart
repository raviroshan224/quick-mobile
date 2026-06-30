import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/staff_repository.dart';
import '../../domain/staff_models.dart';

final staffRepoProvider = Provider<StaffRepository>(
  (ref) => StaffRepository(ref.read(apiClientProvider)),
);

final staffListProvider = FutureProvider<List<StaffModel>>((ref) {
  return ref.watch(staffRepoProvider).getAll();
});

final activeStaffListProvider = FutureProvider<List<StaffModel>>((ref) {
  return ref.watch(staffRepoProvider).getAll(activeOnly: true);
});

final staffDetailProvider = FutureProvider.family<StaffModel, String>((ref, id) {
  return ref.watch(staffRepoProvider).getById(id);
});
