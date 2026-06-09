import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

// ─── Mock data model ──────────────────────────────────────────────────────────

class _MockTransaction {
  const _MockTransaction({
    required this.id,
    required this.amount,
    required this.services,
    required this.date,
    required this.paymentMethod,
    this.refunded = false,
  });
  final String id;
  final double amount;
  final List<String> services;
  final DateTime date;
  final String paymentMethod;
  final bool refunded;
}

final _now = DateTime.now();

final _mockTransactions = <_MockTransaction>[
  _MockTransaction(
    id: 'TXN-001',
    amount: 2800,
    services: ['Hair Cut', 'Hair Wash'],
    date: _now,
    paymentMethod: 'Cash',
  ),
  _MockTransaction(
    id: 'TXN-002',
    amount: 4500,
    services: ['Manicure', 'Pedicure', 'Nail Art'],
    date: _now,
    paymentMethod: 'Fonepay',
  ),
  _MockTransaction(
    id: 'TXN-003',
    amount: 1200,
    services: ['Eyebrow Threading'],
    date: _now.subtract(const Duration(hours: 3)),
    paymentMethod: 'Cash',
    refunded: true,
  ),
  _MockTransaction(
    id: 'TXN-004',
    amount: 6000,
    services: ['Facial', 'Head Massage'],
    date: _now.subtract(const Duration(days: 1)),
    paymentMethod: 'Fonepay',
  ),
  _MockTransaction(
    id: 'TXN-005',
    amount: 3200,
    services: ['Hair Colour', 'Blow Dry'],
    date: _now.subtract(const Duration(days: 1)),
    paymentMethod: 'Cash',
    refunded: true,
  ),
  _MockTransaction(
    id: 'TXN-006',
    amount: 1800,
    services: ['Waxing — Full Arms'],
    date: _now.subtract(const Duration(days: 2)),
    paymentMethod: 'Cash',
  ),
  _MockTransaction(
    id: 'TXN-007',
    amount: 5500,
    services: ['Bridal Makeup', 'Hair Styling'],
    date: _now.subtract(const Duration(days: 4)),
    paymentMethod: 'Fonepay',
  ),
  _MockTransaction(
    id: 'TXN-008',
    amount: 900,
    services: ['Lip Wax'],
    date: _now.subtract(const Duration(days: 5)),
    paymentMethod: 'Cash',
  ),
];

// ─── Provider ─────────────────────────────────────────────────────────────────

/// Tracks IDs that have been refunded in this session (seeded with any
/// transactions already marked `refunded: true` in mock data).
final _refundedProvider = StateProvider<Set<String>>((ref) {
  return {
    for (final t in _mockTransactions)
      if (t.refunded) t.id,
  };
});

// ─── Helpers ──────────────────────────────────────────────────────────────────

String _formatDate(DateTime dt) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final d = DateTime(dt.year, dt.month, dt.day);

  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final m = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  final timeStr = '$h:$m $period';

  if (d == today) return 'Today · $timeStr';
  if (d == yesterday) return 'Yesterday · $timeStr';

  const months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  return '${months[dt.month - 1]} ${dt.day} · $timeStr';
}

String _formatNpr(double amount) {
  final whole = amount.toInt();
  final str = whole.toString();
  // Nepali comma formatting (2,2,3 grouping from right) — simplified to 3,3
  final buf = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buf.write(',');
    buf.write(str[i]);
    count++;
  }
  return 'NPR ${buf.toString().split('').reversed.join()}';
}

// ─── Screen ───────────────────────────────────────────────────────────────────

class RefundsScreen extends HookConsumerWidget {
  const RefundsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final refundedIds = ref.watch(_refundedProvider);
    final searchCtrl = useTextEditingController();
    final searchQuery = useState('');
    final tabIndex = useState(0); // 0=All  1=Refunded

    useEffect(() {
      void listener() => searchQuery.value = searchCtrl.text;
      searchCtrl.addListener(listener);
      return () => searchCtrl.removeListener(listener);
    }, [searchCtrl]);

    final filtered = _mockTransactions.where((t) {
      final q = searchQuery.value.toLowerCase();
      final matchesSearch = q.isEmpty ||
          t.id.toLowerCase().contains(q) ||
          t.services.any((s) => s.toLowerCase().contains(q)) ||
          t.paymentMethod.toLowerCase().contains(q);
      final isRefunded = refundedIds.contains(t.id);
      final matchesTab = tabIndex.value == 0 || isRefunded;
      return matchesSearch && matchesTab;
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.more),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Refunds',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  const SizedBox(width: 18),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // ── Search bar ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: TextField(
                  controller: searchCtrl,
                  style: const TextStyle(fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Search transactions…',
                    hintStyle: const TextStyle(
                      fontSize: 15,
                      color: Color(0xFF9CA3AF),
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      size: 20,
                      color: Color(0xFF9CA3AF),
                    ),
                    suffixIcon: searchQuery.value.isNotEmpty
                        ? GestureDetector(
                            onTap: searchCtrl.clear,
                            child: const Icon(
                              Icons.close_rounded,
                              size: 18,
                              color: Color(0xFF9CA3AF),
                            ),
                          )
                        : null,
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Tab filter ────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  _TabChip(
                    label: 'All Transactions',
                    selected: tabIndex.value == 0,
                    onTap: () => tabIndex.value = 0,
                  ),
                  const SizedBox(width: 8),
                  _TabChip(
                    label: 'Refunded',
                    selected: tabIndex.value == 1,
                    onTap: () => tabIndex.value = 1,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Transaction list ──────────────────────────────────────────
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(
                      isFiltered: searchQuery.value.isNotEmpty ||
                          tabIndex.value == 1,
                    )
                  : ListView.separated(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (context, i) {
                        final tx = filtered[i];
                        final isRefunded = refundedIds.contains(tx.id);
                        return _TransactionCard(
                          transaction: tx,
                          isRefunded: isRefunded,
                          onIssueRefund: isRefunded
                              ? null
                              : () => _showRefundSheet(context, ref, tx),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRefundSheet(
    BuildContext context,
    WidgetRef ref,
    _MockTransaction tx,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RefundSheet(transaction: tx, parentRef: ref),
    );
  }
}

// ─── Transaction card ─────────────────────────────────────────────────────────

class _TransactionCard extends StatelessWidget {
  const _TransactionCard({
    required this.transaction,
    required this.isRefunded,
    required this.onIssueRefund,
  });

  final _MockTransaction transaction;
  final bool isRefunded;
  final VoidCallback? onIssueRefund;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ID + amount
          Row(
            children: [
              Text(
                transaction.id,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF6B7280),
                  letterSpacing: 0.4,
                ),
              ),
              const Spacer(),
              Text(
                _formatNpr(transaction.amount),
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Services
          Text(
            transaction.services.join(' · '),
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),

          const SizedBox(height: 10),

          // Date + badge + button
          Row(
            children: [
              const Icon(
                Icons.access_time_rounded,
                size: 13,
                color: Color(0xFF9CA3AF),
              ),
              const SizedBox(width: 4),
              Text(
                _formatDate(transaction.date),
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
              const SizedBox(width: 8),
              _PaymentBadge(method: transaction.paymentMethod),
              const Spacer(),
              if (isRefunded)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF3F4F6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: const Text(
                    'Refunded',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                )
              else
                GestureDetector(
                  onTap: onIssueRefund,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Issue Refund',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Payment badge ────────────────────────────────────────────────────────────

class _PaymentBadge extends StatelessWidget {
  const _PaymentBadge({required this.method});
  final String method;

  @override
  Widget build(BuildContext context) {
    final isFonepay = method == 'Fonepay';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isFonepay
            ? const Color(0xFFEEF2FF)
            : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        method,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: isFonepay
              ? const Color(0xFF4F46E5)
              : const Color(0xFF16A34A),
        ),
      ),
    );
  }
}

// ─── Tab chip ─────────────────────────────────────────────────────────────────

class _TabChip extends StatelessWidget {
  const _TabChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Empty state ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.isFiltered});
  final bool isFiltered;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 48,
            color: Color(0xFF9CA3AF),
          ),
          const SizedBox(height: 14),
          Text(
            isFiltered ? 'No matching transactions' : 'No transactions yet',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 6),
          Text(
            isFiltered
                ? 'Try adjusting your search or filter'
                : 'Completed sales will appear here',
            style: const TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
          ),
        ],
      ),
    );
  }
}

// ─── Refund bottom sheet ──────────────────────────────────────────────────────

class _RefundSheet extends HookWidget {
  const _RefundSheet({
    required this.transaction,
    required this.parentRef,
  });

  final _MockTransaction transaction;
  final WidgetRef parentRef;

  @override
  Widget build(BuildContext context) {
    final amountCtrl = useTextEditingController(
      text: transaction.amount.toStringAsFixed(0),
    );
    final reasonCtrl = useTextEditingController();
    final reasonError = useState<String?>(null);
    final processing = useState(false);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Drag handle
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE5E7EB),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Title
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 20),
                  child: Text(
                    'Issue Refund',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Transaction detail card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFB),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              transaction.id,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF6B7280),
                                letterSpacing: 0.4,
                              ),
                            ),
                            const Spacer(),
                            _PaymentBadge(method: transaction.paymentMethod),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          transaction.services.join(' · '),
                          style: const TextStyle(
                            fontSize: 14,
                            color: Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _formatDate(transaction.date),
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Refund amount
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REFUND AMOUNT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              decoration: const BoxDecoration(
                                border: Border(
                                  right: BorderSide(
                                    color: Color(0xFFE5E7EB),
                                  ),
                                ),
                              ),
                              child: const Text(
                                'NPR',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF6B7280),
                                ),
                              ),
                            ),
                            Expanded(
                              child: TextField(
                                controller: amountCtrl,
                                keyboardType: TextInputType.number,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                ],
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                                decoration: const InputDecoration(
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 14,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Reason
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'REASON',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B7280),
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: reasonError.value != null
                                ? const Color(0xFFDC2626)
                                : const Color(0xFFE5E7EB),
                          ),
                        ),
                        child: TextField(
                          controller: reasonCtrl,
                          maxLines: 3,
                          minLines: 2,
                          style: const TextStyle(fontSize: 15),
                          onChanged: (_) {
                            if (reasonError.value != null) {
                              reasonError.value = null;
                            }
                          },
                          decoration: const InputDecoration(
                            hintText: 'Enter reason for refund…',
                            hintStyle: TextStyle(
                              fontSize: 15,
                              color: Color(0xFF9CA3AF),
                            ),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(14),
                          ),
                        ),
                      ),
                      if (reasonError.value != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          reasonError.value!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(height: 14),

                // Cash-only notice
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF9C3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: const [
                        Icon(
                          Icons.info_outline_rounded,
                          size: 16,
                          color: Color(0xFF92400E),
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Refunds are issued in cash only',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF92400E),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Process refund button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GestureDetector(
                    onTap: processing.value
                        ? null
                        : () {
                            if (!parentRef.read(isOwnerProvider)) {
                              showDialog(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Owner Required'),
                                  content: const Text(
                                      'Only the owner can process refunds. Please ask the owner to approve this refund.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(ctx),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                              return;
                            }
                            _processRefund(
                              context,
                              amountCtrl,
                              reasonCtrl,
                              reasonError,
                              processing,
                            );
                          },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: processing.value
                            ? const Color(0xFF374151)
                            : Colors.black,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Center(
                        child: processing.value
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text(
                                'Process Refund',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _processRefund(
    BuildContext context,
    TextEditingController amountCtrl,
    TextEditingController reasonCtrl,
    ValueNotifier<String?> reasonError,
    ValueNotifier<bool> processing,
  ) {
    final reason = reasonCtrl.text.trim();
    if (reason.isEmpty) {
      reasonError.value = 'Please enter a reason for the refund';
      return;
    }

    final rawAmount =
        double.tryParse(amountCtrl.text) ?? transaction.amount;

    processing.value = true;

    Future.delayed(const Duration(milliseconds: 600), () {
      if (!context.mounted) return;

      // Mark as refunded in the parent's provider
      parentRef
          .read(_refundedProvider.notifier)
          .update((s) => {...s, transaction.id});

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Refund of ${_formatNpr(rawAmount)} processed — cash drawer updated',
          ),
          backgroundColor: Colors.black,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        ),
      );
    });
  }
}
