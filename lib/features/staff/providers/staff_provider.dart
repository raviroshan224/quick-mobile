import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/staff_model.dart';

final staffListProvider = FutureProvider<List<StaffMember>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/staff');
  final list = response['data'] as List;
  return list.map((e) => StaffMember.fromJson(e as Map<String, dynamic>)).toList();
});

final activeStaffProvider = FutureProvider<List<StaffMember>>((ref) async {
  final all = await ref.watch(staffListProvider.future);
  return all.where((s) => s.isActive).toList();
});
