class NotificationLog {
  const NotificationLog({
    required this.id,
    required this.type,
    required this.channel,
    required this.recipient,
    required this.subject,
    required this.body,
    required this.status,
    this.sentAt,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String channel;
  final String recipient;
  final String subject;
  final String body;
  final String status;
  final DateTime? sentAt;
  final DateTime createdAt;

  factory NotificationLog.fromJson(Map<String, dynamic> j) => NotificationLog(
        id: j['id'] as String,
        type: j['type'] as String,
        channel: j['channel'] as String,
        recipient: j['recipient'] as String,
        subject: j['subject'] as String,
        body: j['body'] as String,
        status: j['status'] as String,
        sentAt: j['sentAt'] != null ? DateTime.tryParse(j['sentAt'] as String) : null,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  bool get isSent => status == 'SENT';

  String get timeAgo {
    final diff = DateTime.now().difference(createdAt);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${createdAt.day}/${createdAt.month}/${createdAt.year}';
  }

  String get typeLabel => switch (type) {
        'APPOINTMENT_REMINDER_24H' => 'Appointment Reminder',
        'APPOINTMENT_REMINDER_1H' => 'Appointment Reminder',
        'POST_VISIT_THANKYOU' => 'Thank You',
        'BIRTHDAY_GREETING' => 'Birthday Greeting',
        'RECEIPT' => 'Receipt Sent',
        'CUSTOM' => 'Custom',
        _ => type,
      };

  String get channelLabel => switch (channel) {
        'EMAIL' => 'Email',
        'SMS' => 'SMS',
        'PUSH' => 'Push',
        _ => channel,
      };
}
