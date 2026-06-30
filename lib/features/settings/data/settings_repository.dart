import '../../../core/network/api_client.dart';

class SettingsRepository {
  SettingsRepository(this._api);
  final ApiClient _api;

  Future<Map<String, dynamic>> get() async {
    return await _api.get('/settings') as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> update(Map<String, dynamic> fields) async {
    return await _api.put('/settings', data: fields) as Map<String, dynamic>;
  }
}
