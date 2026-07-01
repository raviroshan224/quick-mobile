import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/notification_log_model.dart';

class NotificationsRepository {
  NotificationsRepository(this._api);
  final ApiClient _api;

  Future<({List<NotificationLog> items, bool hasMore})> getLogs({
    int page = 1,
    int limit = 20,
  }) async {
    final data = await _api.get('/notifications/logs', queryParameters: {
      'page': page,
      'limit': limit,
    }) as Map<String, dynamic>;
    final response = PaginatedResponse.fromJson(data, NotificationLog.fromJson);
    return (
      items: response.data,
      hasMore: response.meta.page < response.meta.totalPages,
    );
  }
}
