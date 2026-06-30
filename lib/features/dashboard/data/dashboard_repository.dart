import '../../../core/network/api_client.dart';
import '../models/dashboard_summary.dart';

class DashboardRepository {
  DashboardRepository(this._api);
  final ApiClient _api;

  Future<DashboardSummary> getSummary() async {
    final data = await _api.get('/dashboard') as Map<String, dynamic>;
    return DashboardSummary.fromJson(data);
  }
}
