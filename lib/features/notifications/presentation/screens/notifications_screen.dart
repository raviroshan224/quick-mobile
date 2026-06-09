import 'package:flutter/material.dart';

class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  static const _items = [
    _NotifData(
      dot: true,
      title: 'New features: Video Calls',
      body:
          'Video Call is available now. You can call to your friends, family and other whom you want.',
      time: '1 min ago',
    ),
    _NotifData(
      dot: true,
      title: 'Payment In: NPR 100.00',
      body:
          'Recently NPR 100.00 is credited to your account. Go to wallet to see your earnings.',
      time: '20 min ago',
    ),
    _NotifData(
      dot: false,
      title: 'New features: Video Calls',
      body:
          'Video Call is available now. You can call to your friends, family and other whom you want.',
      time: '1 day ago',
    ),
    _NotifData(
      dot: false,
      title: 'Payment In: NPR 100.00',
      body:
          'Recently NPR 100.00 is credited to your account. Go to wallet to see your earnings.',
      time: '2 day ago',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding:
                  const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  const Text(
                    'Notifications',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {},
                    child: const Text(
                      'Mark All Read',
                      style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.black),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView.separated(
                padding: EdgeInsets.zero,
                itemCount: _items.length,
                separatorBuilder: (_, _) => const Divider(
                    height: 1, color: Color(0xFFF3F4F6)),
                itemBuilder: (_, i) =>
                    _NotifTile(item: _items[i]),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotifTile extends StatelessWidget {
  const _NotifTile({required this.item});
  final _NotifData item;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: item.dot
          ? Colors.white
          : const Color(0xFFFAFAFA),
      padding: const EdgeInsets.symmetric(
          horizontal: 20, vertical: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Dot indicator
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: item.dot
                    ? Colors.black
                    : Colors.transparent,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: item.dot
                            ? FontWeight.w600
                            : FontWeight.w400)),
                const SizedBox(height: 4),
                Text(item.body,
                    style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                        height: 1.4)),
                const SizedBox(height: 6),
                Text(item.time,
                    style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifData {
  const _NotifData({
    required this.dot,
    required this.title,
    required this.body,
    required this.time,
  });
  final bool dot;
  final String title;
  final String body;
  final String time;
}
