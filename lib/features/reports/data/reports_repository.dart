import '../../../core/network/api_client.dart';
import '../domain/reports_models.dart';

class ReportsRepository {
  ReportsRepository(this._api);
  final ApiClient _api;

  Future<SalesSummary> getSalesSummary({String? from, String? to}) async {
    final j = await _api.get('/reports/sales-summary', queryParameters: {
      'from': from,
      'to': to,
    }..removeWhere((_, v) => v == null)) as Map<String, dynamic>;
    return SalesSummary.fromJson(j);
  }

  Future<List<StaffPerformance>> getStaffPerformance({String? from, String? to}) async {
    final list = await _api.get('/reports/staff-performance', queryParameters: {
      'from': from,
      'to': to,
    }..removeWhere((_, v) => v == null)) as List<dynamic>;
    return list.map((e) => StaffPerformance.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<List<ServicePopularity>> getServicePopularity({String? from, String? to}) async {
    final list = await _api.get('/reports/service-popularity', queryParameters: {
      'from': from,
      'to': to,
    }..removeWhere((_, v) => v == null)) as List<dynamic>;
    return list.map((e) => ServicePopularity.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<InventoryReport> getInventoryReport() async {
    final j = await _api.get('/reports/inventory') as Map<String, dynamic>;
    return InventoryReport.fromJson(j);
  }
}
