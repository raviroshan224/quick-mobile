import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pos/domain/pos_models.dart';
import '../../../staff/presentation/providers/staff_provider.dart';

/// Staff picker bottom sheet — used for per-item staff assignment overrides
/// on the review sale sheet. Returns null if the sheet is dismissed/skipped.
Future<StaffMember?> pickStaffMember(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) {
  return showModalBottomSheet<StaffMember?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StaffPickerSheet(title: title),
  );
}

class _StaffPickerSheet extends ConsumerWidget {
  const _StaffPickerSheet({required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(activeStaffListProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: staffAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load staff: $e'),
                ),
                data: (staffList) => staffList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No staff added yet',
                            style: TextStyle(color: AppColors.textTertiary)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: staffList.length,
                        itemBuilder: (_, i) {
                          final s = staffList[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                s.firstName.isNotEmpty ? s.firstName[0] : '?',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text('${s.firstName} ${s.lastName}'),
                            onTap: () => Navigator.pop(context, s),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
