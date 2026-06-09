class Refund {
  final String id;
  final String transactionId;
  final double amount;
  final String reason;
  final String refundedById;
  final DateTime createdAt;

  const Refund({
    required this.id,
    required this.transactionId,
    required this.amount,
    required this.reason,
    required this.refundedById,
    required this.createdAt,
  });

  factory Refund.fromJson(Map<String, dynamic> j) => Refund(
        id: j['id'] as String,
        transactionId: j['transactionId'] as String,
        amount: (j['amount'] as num).toDouble(),
        reason: j['reason'] as String,
        refundedById: j['refundedById'] as String,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );
}
