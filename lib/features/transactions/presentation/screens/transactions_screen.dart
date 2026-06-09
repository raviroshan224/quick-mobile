import 'package:flutter/material.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({super.key});

  // Mock data
  static final _today = [
    _TxData(id: 123, type: 'SALE', amount: 100.00, time: '10:12 PM'),
    _TxData(id: 112, type: 'REFUND', amount: 100.00, time: '08:02 PM'),
    _TxData(id: 122, type: 'SALE', amount: 60.00, time: '03:12 PM'),
    _TxData(id: 121, type: 'SALE', amount: 40.00, time: '10:05 AM'),
  ];
  static final _yesterday = [
    _TxData(id: 120, type: 'SALE', amount: 100.00, time: '10:11 AM'),
    _TxData(id: 119, type: 'SALE', amount: 80.00, time: '09:45 AM'),
  ];

  @override
  Widget build(BuildContext context) {
    final todaySales = _today
        .where((t) => t.type == 'SALE')
        .fold(0.0, (s, t) => s + t.amount);
    final todayRefunds = _today
        .where((t) => t.type == 'REFUND')
        .length;
    final todaySaleCount = _today.where((t) => t.type == 'SALE').length;

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title bar
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  const Text(
                    'Transactions',
                    style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w700,
                        color: Colors.black),
                  ),
                  const Spacer(),
                  Text(
                    'May 27',
                    style: TextStyle(
                        fontSize: 15, color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // Volume card
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.black,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Today's Volume",
                      style: TextStyle(
                          color: Color(0xFF9CA3AF), fontSize: 13),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'NPR ${todaySales.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 34,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _VolumeChip(
                            label:
                                '$todaySaleCount Sale${todaySaleCount == 1 ? '' : 's'}'),
                        const SizedBox(width: 10),
                        if (todayRefunds > 0)
                          _VolumeChip(
                              label:
                                  '$todayRefunds Refund${todayRefunds == 1 ? '' : 's'}'),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Search bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: const Color(0xFFE5E7EB)),
                      ),
                      child: const Row(
                        children: [
                          SizedBox(width: 12),
                          Icon(Icons.search,
                              size: 18, color: Color(0xFF9CA3AF)),
                          SizedBox(width: 8),
                          Text('Search',
                              style: TextStyle(
                                  color: Color(0xFF9CA3AF),
                                  fontSize: 14)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border:
                          Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: const Icon(Icons.tune_rounded,
                        size: 18, color: Colors.black),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            // List
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  _DateHeader(label: 'Today, 27 May 2026'),
                  ..._today.map((t) => _TxTile(tx: t)),
                  const SizedBox(height: 8),
                  _DateHeader(label: 'Yesterday, 26 May 2026'),
                  ..._yesterday.map((t) => _TxTile(tx: t)),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VolumeChip extends StatelessWidget {
  const _VolumeChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFF1F2937),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFF9CA3AF), fontSize: 12)),
    );
  }
}

class _DateHeader extends StatelessWidget {
  const _DateHeader({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Text(label,
          style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280))),
    );
  }
}

class _TxTile extends StatelessWidget {
  const _TxTile({required this.tx});
  final _TxData tx;

  @override
  Widget build(BuildContext context) {
    final isSale = tx.type == 'SALE';
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isSale
                  ? const Color(0xFFDCFCE7)
                  : const Color(0xFFFEE2E2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSale
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 16,
              color: isSale
                  ? const Color(0xFF16A34A)
                  : const Color(0xFFDC2626),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${tx.type} #${tx.id}',
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500)),
                Text('Today, ${tx.time}',
                    style: const TextStyle(
                        fontSize: 12, color: Color(0xFF9CA3AF))),
              ],
            ),
          ),
          Text(
            'NPR ${tx.amount.toStringAsFixed(2)}',
            style: const TextStyle(
                fontSize: 15, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

class _TxData {
  const _TxData(
      {required this.id,
      required this.type,
      required this.amount,
      required this.time});
  final int id;
  final String type;
  final double amount;
  final String time;
}
