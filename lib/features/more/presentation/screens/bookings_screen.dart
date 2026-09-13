import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../checkout/presentation/screens/calendar_tab.dart';

/// Standalone "Bookings" screen reachable from More → Manage, so owners and
/// staff can view and manage all bookings without going through Checkout.
///
/// Reuses [CalendarTab] (date strip + list + create/edit) which already
/// implements the full booking CRUD flow for the Checkout screen's Calendar
/// tab — this screen just adds the app bar chrome around it.
class BookingsScreen extends StatelessWidget {
  const BookingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
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
        title: const Text('Bookings',
            style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.black)),
        centerTitle: true,
      ),
      body: const SafeArea(child: CalendarTab()),
    );
  }
}
