import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../models/refund_model.dart';

final refundsListProvider = FutureProvider<List<Refund>>((ref) async {
  final client = ref.watch(apiClientProvider);
  final response = await client.get<Map<String, dynamic>>('/refunds');
  final list = response['data'] as List;
  return list.map((e) => Refund.fromJson(e as Map<String, dynamic>)).toList();
});

class RefundNotifier extends AsyncNotifier<void> {
  @override
  Future<void> build() async {}

  Future<Refund> issueRefund({required String transactionId, required String reason, double? amount}) async {
    final client = ref.read(apiClientProvider);
    final response = await client.post<Map<String, dynamic>>(
      '/refunds/$transactionId',
      data: {'reason': reason, 'amount': amount},
    );
    ref.invalidate(refundsListProvider);
    return Refund.fromJson(response['data'] as Map<String, dynamic>);
  }
}

final refundNotifierProvider = AsyncNotifierProvider<RefundNotifier, void>(RefundNotifier.new);
