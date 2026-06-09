import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mock_staff_repository.dart';
import '../../domain/staff_models.dart';

final _staffRepoProvider = Provider((_) => MockStaffRepository());

final staffListProvider = FutureProvider<List<StaffModel>>((ref) {
  return ref.watch(_staffRepoProvider).getAll();
});

final activeStaffListProvider = FutureProvider<List<StaffModel>>((ref) {
  return ref.watch(_staffRepoProvider).getAll(activeOnly: true);
});
