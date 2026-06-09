import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class _NotifItem {
  final String title;
  final String body;
  final String ago;
  final bool isNew;
  const _NotifItem({required this.title, required this.body, required this.ago, required this.isNew});
}

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const items = [
      _NotifItem(
        title: 'New features: Video Calls',
        body: 'Video Call is available now. You can call to your friends, family and other whom you want.',
        ago: '5 min ago',
        isNew: true,
      ),
      _NotifItem(
        title: 'Payment In: Rs. 100.00',
        body: 'Recently Rs. 100.00 is credited to your account. Go to wallet to see your earnings.',
        ago: '20 min ago',
        isNew: true,
      ),
      _NotifItem(
        title: 'New features: Video Calls',
        body: 'Video Call is available now. You can call to your friends, family and other whom you want.',
        ago: '1 day ago',
        isNew: false,
      ),
      _NotifItem(
        title: 'Payment In: Rs. 100.00',
        body: 'Recently Rs. 100.00 is credited to your account. Go to wallet to see your earnings.',
        ago: '2 day ago',
        isNew: false,
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Notifications',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                    ),
                    TextButton(
                      onPressed: () {},
                      child: const Text(
                        'Mark All Read',
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (context, i) => _NotifRow(item: items[i]),
                childCount: items.length,
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  final _NotifItem item;
  const _NotifRow({required this.item});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 18,
              child: item.isNew
                  ? Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(top: 5),
                      decoration: const BoxDecoration(
                        color: AppColors.accent,
                        shape: BoxShape.circle,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                  const SizedBox(height: 2),
                  Text(item.body, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                  const SizedBox(height: 4),
                  Text(item.ago, style: const TextStyle(fontSize: 11, color: AppColors.textTertiary)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
