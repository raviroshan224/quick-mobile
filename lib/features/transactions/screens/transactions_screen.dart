import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';

class _Txn {
  final String id;
  final bool isRefund;
  final double amount;
  final DateTime dateTime;
  const _Txn({required this.id, required this.isRefund, required this.amount, required this.dateTime});
}

class TransactionsScreen extends ConsumerWidget {
  const TransactionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));

    final txns = [
      _Txn(id: '123', isRefund: false, amount: 100.0, dateTime: now.subtract(const Duration(hours: 1))),
      _Txn(id: '112', isRefund: true, amount: 100.0, dateTime: now.subtract(const Duration(hours: 3))),
      _Txn(id: '122', isRefund: false, amount: 60.0, dateTime: now.subtract(const Duration(hours: 5))),
      _Txn(id: '121', isRefund: false, amount: 40.0, dateTime: now.subtract(const Duration(hours: 6))),
      _Txn(id: '120', isRefund: false, amount: 100.0, dateTime: yesterday),
    ];

    final groups = <String, List<_Txn>>{};
    for (final t in txns) {
      groups.putIfAbsent(_dayKey(t.dateTime, now), () => []).add(t);
    }

    final todayList = groups['Today'] ?? [];
    final sales = todayList.where((t) => !t.isRefund).toList();
    final refunds = todayList.where((t) => t.isRefund).toList();
    final volume = sales.fold(0.0, (s, t) => s + t.amount);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Transactions',
                        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700, color: AppColors.textPrimary)),
                    Text(_shortDate(now), style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: _VolumeCard(volume: volume, salesCount: sales.length, refundCount: refunds.length),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search',
                          prefixIcon: Icon(Icons.search, size: 18, color: AppColors.textTertiary),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 40, height: 40,
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.tune, size: 18, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ),
            for (final entry in groups.entries) ...[
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 6),
                  child: Text(
                    _fullLabel(entry.key, now),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textSecondary),
                  ),
                ),
              ),
              SliverList(
                delegate: SliverChildBuilderDelegate(
                  (_, i) => _TxnRow(txn: entry.value[i], now: now),
                  childCount: entry.value.length,
                ),
              ),
              const SliverToBoxAdapter(child: Divider()),
            ],
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  String _dayKey(DateTime dt, DateTime now) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final t = DateTime(now.year, now.month, now.day);
    if (d == t) return 'Today';
    if (d == t.subtract(const Duration(days: 1))) return 'Yesterday';
    return '${dt.day} ${_month(dt.month)} ${dt.year}';
  }

  String _fullLabel(String key, DateTime now) {
    if (key == 'Today') return 'Today, ${now.day} ${_month(now.month)} ${now.year}';
    if (key == 'Yesterday') {
      final y = now.subtract(const Duration(days: 1));
      return 'Yesterday, ${y.day} ${_month(y.month)} ${y.year}';
    }
    return key;
  }

  String _shortDate(DateTime dt) => '${_month(dt.month).substring(0, 3)} ${dt.day}';

  String _month(int m) => const [
        '', 'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ][m];
}

class _VolumeCard extends StatelessWidget {
  final double volume;
  final int salesCount;
  final int refundCount;
  const _VolumeCard({required this.volume, required this.salesCount, required this.refundCount});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Today's Volume", style: TextStyle(color: Colors.white70, fontSize: 13)),
          const SizedBox(height: 4),
          Text('Rs${volume.toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.w700, letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text(
            '$salesCount ${salesCount == 1 ? 'Sale' : 'Sales'}  $refundCount ${refundCount == 1 ? 'Refund' : 'Refunds'}',
            style: const TextStyle(color: Colors.white60, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _TxnRow extends StatelessWidget {
  final _Txn txn;
  final DateTime now;
  const _TxnRow({required this.txn, required this.now});

  @override
  Widget build(BuildContext context) {
    final color = txn.isRefund ? AppColors.refund : AppColors.success;
    final arrow = txn.isRefund ? Icons.arrow_downward : Icons.arrow_upward;
    final label = txn.isRefund ? 'REFUND' : 'SALE';

    return InkWell(
      onTap: () {},
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(arrow, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$label #${txn.id}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                  Text(_timeLabel(txn.dateTime, now), style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ],
              ),
            ),
            Text('Rs${txn.amount.toStringAsFixed(2)}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt, DateTime now) {
    final d = DateTime(dt.year, dt.month, dt.day);
    final t = DateTime(now.year, now.month, now.day);
    final h = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final m = dt.minute.toString().padLeft(2, '0');
    final p = dt.hour >= 12 ? 'PM' : 'AM';
    final time = '$h:$m $p';
    if (d == t) return 'Today, $time';
    if (d == t.subtract(const Duration(days: 1))) return 'Yesterday, $time';
    return time;
  }
}
