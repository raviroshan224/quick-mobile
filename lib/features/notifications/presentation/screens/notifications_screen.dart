import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/notification_log_model.dart';
import '../providers/notifications_provider.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logsAsync = ref.watch(notificationLogsProvider);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(fontSize: 28, fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => ref.refresh(notificationLogsProvider),
                    child: const Text(
                      'Refresh',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: logsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => _ErrorState(onRetry: () => ref.refresh(notificationLogsProvider)),
                data: (logs) => logs.isEmpty
                    ? const _EmptyState()
                    : ListView.separated(
                        padding: EdgeInsets.zero,
                        itemCount: logs.length,
                        separatorBuilder: (_, _) =>
                            const Divider(height: 1, color: AppColors.surfaceVariant),
                        itemBuilder: (_, i) => _NotifTile(log: logs[i]),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.log});
  final NotificationLog log;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: log.isSent ? Colors.white : AppColors.background,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _iconBg(log.type),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_iconFor(log.type), size: 18, color: _iconColor(log.type)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        log.typeLabel,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      log.timeAgo,
                      style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  log.subject,
                  style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, height: 1.3),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _Tag(log.channelLabel),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        log.recipient,
                        style: const TextStyle(fontSize: 11, color: AppColors.textTertiary),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: log.isSent ? AppColors.success : AppColors.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  IconData _iconFor(String type) => switch (type) {
        'APPOINTMENT_REMINDER_24H' || 'APPOINTMENT_REMINDER_1H' => Icons.calendar_today_rounded,
        'POST_VISIT_THANKYOU' => Icons.favorite_rounded,
        'BIRTHDAY_GREETING' => Icons.cake_rounded,
        'RECEIPT' => Icons.receipt_long_rounded,
        _ => Icons.notifications_rounded,
      };

  Color _iconBg(String type) => switch (type) {
        'APPOINTMENT_REMINDER_24H' || 'APPOINTMENT_REMINDER_1H' => const Color(0xFFEDE9FE),
        'POST_VISIT_THANKYOU' => const Color(0xFFFFE4E6),
        'BIRTHDAY_GREETING' => const Color(0xFFFEF9C3),
        'RECEIPT' => const Color(0xFFDCFCE7),
        _ => AppColors.surfaceVariant,
      };

  Color _iconColor(String type) => switch (type) {
        'APPOINTMENT_REMINDER_24H' || 'APPOINTMENT_REMINDER_1H' => const Color(0xFF7C3AED),
        'POST_VISIT_THANKYOU' => const Color(0xFFE11D48),
        'BIRTHDAY_GREETING' => const Color(0xFFD97706),
        'RECEIPT' => const Color(0xFF16A34A),
        _ => AppColors.textSecondary,
      };
}

class _Tag extends StatelessWidget {
  const _Tag(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.surfaceVariant,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(Icons.notifications_none_rounded,
                size: 32, color: AppColors.textTertiary),
          ),
          const SizedBox(height: 16),
          const Text('No notifications yet',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          const Text('Sent emails and SMS to customers will appear here.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textTertiary)),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 40, color: AppColors.textTertiary),
          const SizedBox(height: 12),
          const Text('Could not load notifications',
              style: TextStyle(fontSize: 15, color: AppColors.textSecondary)),
          const SizedBox(height: 4),
          const Text('Only owners can view notification logs.',
              style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
          const SizedBox(height: 16),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
