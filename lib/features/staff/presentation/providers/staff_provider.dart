import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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

/// The staff record of the signed-in user, or null for an owner (or a user
/// with no staff record). Matched on [StaffModel.userId].
final myStaffProfileProvider = FutureProvider<StaffModel?>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final all = await ref.watch(staffListProvider.future);
  return all.where((s) => s.userId == user.id).firstOrNull;
});
