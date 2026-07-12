import 'package:uuid/uuid.dart';
import '../../../core/models/paginated_response.dart';
import '../../../core/network/api_client.dart';
import '../domain/booking_models.dart';

const _uuid = Uuid();

class BookingsRepository {
  BookingsRepository(this._api);
  final ApiClient _api;

  Future<({List<Booking> items, bool hasMore})> getAll({
    String? date,
    String? staffId,
    String? status,
    int page = 1,
    int limit = 50,
  }) async {
    final data = await _api.get('/bookings', queryParameters: {
      'page': page,
      'limit': limit,
      'date': ?date,
      'staffId': ?staffId,
      'status': ?status,
    }) as Map<String, dynamic>;
    final response = PaginatedResponse.fromJson(data, Booking.fromJson);
    return (
      items: response.data,
      hasMore: response.meta.page < response.meta.totalPages,
    );
  }

  Future<Booking> create(BookingRequest req) async {
    // Generated once per logical create — a stable key across Dio's
    // connection-drop retries so the backend dedupes a resubmit instead of
    // creating a second booking.
    final idempotencyKey = _uuid.v4();
    final data = await _api.post(
      '/bookings',
      data: req.toJson(),
      headers: {'Idempotency-Key': idempotencyKey},
    ) as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<Booking> update(String id, BookingRequest req) async {
    final data = await _api.patch('/bookings/$id', data: req.toJson()) as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<Booking> updateStatus(String id, BookingStatus status) async {
    final data = await _api.patch('/bookings/$id/status', data: {
      'status': bookingStatusToApi(status),
    }) as Map<String, dynamic>;
    return Booking.fromJson(data);
  }

  Future<void> delete(String id) async {
    await _api.delete('/bookings/$id');
  }
}
