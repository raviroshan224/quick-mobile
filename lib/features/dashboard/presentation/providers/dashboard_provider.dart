import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/dashboard_repository.dart';
import '../../models/dashboard_summary.dart';

final _dashboardRepoProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.read(apiClientProvider)),
);

final dashboardProvider = FutureProvider<DashboardSummary>((ref) {
  return ref.watch(_dashboardRepoProvider).getSummary();
});
