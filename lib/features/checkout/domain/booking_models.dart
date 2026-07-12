enum BookingStatus { scheduled, completed, cancelled }

BookingStatus _parseBookingStatus(String? s) => switch (s) {
      'COMPLETED' => BookingStatus.completed,
      'CANCELLED' => BookingStatus.cancelled,
      _ => BookingStatus.scheduled,
    };

String bookingStatusToApi(BookingStatus s) => switch (s) {
      BookingStatus.completed => 'COMPLETED',
      BookingStatus.cancelled => 'CANCELLED',
      BookingStatus.scheduled => 'SCHEDULED',
    };

class Booking {
  const Booking({
    required this.id,
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.serviceName,
    this.staffId,
    this.staffName,
    required this.duration,
    required this.date,
    required this.time,
    this.notes,
    this.status = BookingStatus.scheduled,
  });

  final String id;
  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String serviceName;
  final String? staffId;
  final String? staffName;
  final int duration;
  final DateTime date;
  // "HH:mm", 24-hour.
  final String time;
  final String? notes;
  final BookingStatus status;

  String get statusLabel => switch (status) {
        BookingStatus.scheduled => 'Scheduled',
        BookingStatus.completed => 'Completed',
        BookingStatus.cancelled => 'Cancelled',
      };

  String get timeLabel {
    final parts = time.split(':');
    final h = int.tryParse(parts[0]) ?? 0;
    final m = parts.length > 1 ? parts[1] : '00';
    final hourOfPeriod = h % 12 == 0 ? 12 : h % 12;
    final period = h < 12 ? 'AM' : 'PM';
    return '$hourOfPeriod:$m $period';
  }

  factory Booking.fromJson(Map<String, dynamic> j) => Booking(
        id: j['id'] as String,
        customerName: j['customerName'] as String? ?? '',
        customerPhone: j['customerPhone'] as String? ?? '',
        customerEmail: j['customerEmail'] as String?,
        serviceName: j['serviceName'] as String? ?? '',
        staffId: j['staffId'] as String?,
        staffName: j['staffName'] as String?,
        duration: j['duration'] as int? ?? 30,
        date: DateTime.parse(j['date'] as String).toLocal(),
        time: j['time'] as String? ?? '00:00',
        notes: j['notes'] as String?,
        status: _parseBookingStatus(j['status'] as String?),
      );
}

// ─── Create/update request ──────────────────────────────────────────────────

class BookingRequest {
  const BookingRequest({
    required this.customerName,
    required this.customerPhone,
    this.customerEmail,
    required this.serviceName,
    this.staffId,
    this.staffName,
    required this.duration,
    required this.date,
    required this.time,
    this.notes,
  });

  final String customerName;
  final String customerPhone;
  final String? customerEmail;
  final String serviceName;
  final String? staffId;
  final String? staffName;
  final int duration;
  final DateTime date;
  final String time;
  final String? notes;

  Map<String, dynamic> toJson() => {
        'customerName': customerName,
        'customerPhone': customerPhone,
        if (customerEmail != null && customerEmail!.isNotEmpty)
          'customerEmail': customerEmail,
        'serviceName': serviceName,
        if (staffId != null) 'staffId': staffId,
        if (staffName != null && staffName!.isNotEmpty) 'staffName': staffName,
        'duration': duration,
        'date':
            '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
        'time': time,
        if (notes != null && notes!.isNotEmpty) 'notes': notes,
      };
}
