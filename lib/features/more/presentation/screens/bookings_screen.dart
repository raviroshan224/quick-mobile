import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../checkout/presentation/screens/calendar_tab.dart';
import '../../../staff/presentation/providers/staff_provider.dart';

/// Standalone "Bookings" screen reachable from More, so owners and staff can
/// view and manage bookings without going through Checkout.
///
/// Reuses [CalendarTab] (date strip + list + create/edit) which already
/// implements the full booking CRUD flow for the Checkout screen's Calendar
/// tab — this screen just adds the app bar chrome around it. Owners see every
/// booking; staff see only the bookings assigned to them.
class BookingsScreen extends ConsumerWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOwner = ref.watch(isOwnerProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => context.go(AppRoutes.more),
        ),
        title: Text(isOwner ? 'Bookings' : 'My Bookings',
            style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        centerTitle: true,
      ),
      body: SafeArea(
        child: isOwner ? const CalendarTab() : const _MyBookings(),
      ),
    );
  }
}

class _MyBookings extends ConsumerWidget {
  const _MyBookings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref.watch(myStaffProfileProvider).when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _Message(
            text: 'Could not load your staff profile.',
            onRetry: () => ref.invalidate(staffListProvider),
          ),
          data: (staff) => staff == null
              ? const _Message(
                  text: 'Your account is not linked to a staff profile, '
                      'so there are no bookings assigned to you.')
              : CalendarTab(staffId: staff.id),
        );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.text, this.onRetry});
  final String text;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(text,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, color: AppColors.textSecondary)),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              TextButton(onPressed: onRetry, child: const Text('Retry')),
            ],
          ],
        ),
      ),
    );
  }
}
