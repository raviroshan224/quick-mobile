import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/dashboard_summary.dart';

final dashboardSummaryProvider = FutureProvider<DashboardSummary>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/dashboard');
  return DashboardSummary.fromJson(response['data'] as Map<String, dynamic>);
});
