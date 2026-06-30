import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/notifications_repository.dart';
import '../../domain/notification_log_model.dart';

final notificationsRepoProvider = Provider<NotificationsRepository>(
  (ref) => NotificationsRepository(ref.read(apiClientProvider)),
);

final notificationLogsProvider =
    FutureProvider.autoDispose<List<NotificationLog>>((ref) async {
  final result = await ref.read(notificationsRepoProvider).getLogs(limit: 50);
  return result.items;
});
