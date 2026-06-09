import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/staff_provider.dart';
import '../models/staff_model.dart';

class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(staffListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Staff')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (staff) => ListView.builder(
          itemCount: staff.length,
          itemBuilder: (_, i) => _StaffTile(staff: staff[i]),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        child: const Icon(Icons.person_add),
      ),
    );
  }
}

class _StaffTile extends StatelessWidget {
  final StaffMember staff;
  const _StaffTile({required this.staff});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: staff.photoUrl != null ? NetworkImage(staff.photoUrl!) : null,
        child: staff.photoUrl == null ? Text(staff.initials) : null,
      ),
      title: Text(staff.fullName),
      subtitle: staff.specialties.isNotEmpty ? Text(staff.specialties.join(', ')) : null,
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (staff.commissionRate != null) Text('${staff.commissionRate!.toStringAsFixed(0)}% comm.', style: const TextStyle(fontSize: 12)),
          Icon(Icons.circle, size: 10, color: staff.isActive ? Colors.green : Colors.grey),
        ],
      ),
    );
  }
}
