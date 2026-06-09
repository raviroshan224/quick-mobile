import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/mock_dashboard_repository.dart';

final _dashboardRepoProvider = Provider((_) => MockDashboardRepository());

final dashboardProvider = FutureProvider<DashboardSummary>((ref) {
  return ref.watch(_dashboardRepoProvider).getSummary();
});
