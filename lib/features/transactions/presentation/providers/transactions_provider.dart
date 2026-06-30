import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/transactions_repository.dart';
import '../../domain/transaction_models.dart';

final _transactionsRepoProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.read(apiClientProvider)),
);

// ─── Paginated list ───────────────────────────────────────────────────────────

class TransactionListState {
  const TransactionListState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.statusFilter,
    this.paymentFilter,
    this.dateFrom,
    this.dateTo,
  });

  final List<Transaction> items;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String? statusFilter;
  final String? paymentFilter;
  final DateTime? dateFrom;
  final DateTime? dateTo;

  TransactionListState copyWith({
    List<Transaction>? items,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) =>
      TransactionListState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        statusFilter: statusFilter,
        paymentFilter: paymentFilter,
        dateFrom: dateFrom,
        dateTo: dateTo,
      );
}

class TransactionListNotifier extends StateNotifier<TransactionListState> {
  TransactionListNotifier(this._repo) : super(const TransactionListState()) {
    _fetchPage1();
  }

  final TransactionsRepository _repo;
  int _page = 1;

  Future<void> _fetchPage1() async {
    _page = 1;
    state = state.copyWith(isLoading: true, clearError: true, items: [], hasMore: true);
    try {
      final result = await _repo.getAll(
        page: 1,
        status: state.statusFilter,
        paymentMethod: state.paymentFilter,
        from: state.dateFrom?.toIso8601String(),
        to: _endOfDay(state.dateTo),
      );
      if (!mounted) return;
      state = state.copyWith(
        items: result.items,
        hasMore: result.hasMore,
        isLoading: false,
      );
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getAll(
        page: _page + 1,
        status: state.statusFilter,
        paymentMethod: state.paymentFilter,
        from: state.dateFrom?.toIso8601String(),
        to: _endOfDay(state.dateTo),
      );
      if (!mounted) return;
      _page++;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> setStatusFilter(String? status) async {
    state = TransactionListState(
      statusFilter: status,
      paymentFilter: state.paymentFilter,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
    );
    await _fetchPage1();
  }

  Future<void> setPaymentFilter(String? method) async {
    state = TransactionListState(
      statusFilter: state.statusFilter,
      paymentFilter: method,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
    );
    await _fetchPage1();
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    state = TransactionListState(
      statusFilter: state.statusFilter,
      paymentFilter: state.paymentFilter,
      dateFrom: from,
      dateTo: to,
    );
    await _fetchPage1();
  }

  Future<void> refresh() => _fetchPage1();

  String? _endOfDay(DateTime? dt) {
    if (dt == null) return null;
    return DateTime(dt.year, dt.month, dt.day, 23, 59, 59).toIso8601String();
  }
}

final transactionListProvider =
    StateNotifierProvider<TransactionListNotifier, TransactionListState>(
  (ref) => TransactionListNotifier(ref.read(_transactionsRepoProvider)),
);

// ─── Detail ───────────────────────────────────────────────────────────────────

final transactionDetailProvider =
    FutureProvider.family<Transaction, String>((ref, id) {
  return ref.watch(_transactionsRepoProvider).getById(id);
});

// ─── Refunds screen list (all recent, filtered to non-voided/pending) ─────────

final refundsListProvider = FutureProvider<List<Transaction>>((ref) async {
  final result = await ref.watch(_transactionsRepoProvider).getAll(limit: 100);
  return result.items
      .where((t) =>
          t.status == TransactionStatus.completed ||
          t.status == TransactionStatus.partiallyRefunded ||
          t.status == TransactionStatus.refunded)
      .toList();
});

// ─── Refund history (GET /refunds, paginated) ────────────────────────────────

class RefundHistoryState {
  const RefundHistoryState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
  });

  final List<RefundRecord> items;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;

  RefundHistoryState copyWith({
    List<RefundRecord>? items,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) =>
      RefundHistoryState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
      );
}

class RefundHistoryNotifier extends StateNotifier<RefundHistoryState> {
  RefundHistoryNotifier(this._repo) : super(const RefundHistoryState()) {
    _fetchPage1();
  }

  final TransactionsRepository _repo;
  int _page = 1;

  Future<void> _fetchPage1() async {
    _page = 1;
    state = state.copyWith(
        isLoading: true, clearError: true, items: [], hasMore: true);
    try {
      final result = await _repo.getRefundHistory(page: 1);
      if (!mounted) return;
      state = state.copyWith(
          items: result.items, hasMore: result.hasMore, isLoading: false);
    } catch (e) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true);
    try {
      final result = await _repo.getRefundHistory(page: _page + 1);
      if (!mounted) return;
      _page++;
      state = state.copyWith(
        items: [...state.items, ...result.items],
        hasMore: result.hasMore,
        isLoadingMore: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoadingMore: false);
    }
  }

  Future<void> refresh() => _fetchPage1();
}

final refundHistoryProvider =
    StateNotifierProvider<RefundHistoryNotifier, RefundHistoryState>(
  (ref) => RefundHistoryNotifier(ref.read(_transactionsRepoProvider)),
);

// ─── Last completed transaction (set after checkout) ─────────────────────────

final lastTransactionIdProvider = StateProvider<String?>((ref) => null);

// ─── Customer visit history ───────────────────────────────────────────────────

final customerTransactionsProvider =
    FutureProvider.autoDispose.family<List<Transaction>, String>(
        (ref, customerId) async {
  final result = await ref
      .read(_transactionsRepoProvider)
      .getAll(limit: 20, customerId: customerId);
  return result.items;
});

// ─── Staff recent activity ────────────────────────────────────────────────────

final staffTransactionsProvider =
    FutureProvider.autoDispose.family<List<Transaction>, String>(
        (ref, staffId) async {
  final result = await ref
      .read(_transactionsRepoProvider)
      .getAll(limit: 10, staffId: staffId);
  return result.items;
});

// ─── Today's volume (for transactions screen summary card) ────────────────────

final todayRevenueProvider =
    FutureProvider.autoDispose<({double revenue, int sales, int refunds})>(
        (ref) async {
  final now = DateTime.now();
  final from = DateTime(now.year, now.month, now.day).toIso8601String();
  final to =
      DateTime(now.year, now.month, now.day, 23, 59, 59).toIso8601String();
  final result = await ref
      .read(_transactionsRepoProvider)
      .getAll(limit: 100, from: from, to: to);
  var revenue = 0.0;
  var sales = 0;
  var refunds = 0;
  for (final t in result.items) {
    if (t.status == TransactionStatus.completed ||
        t.status == TransactionStatus.partiallyRefunded) {
      revenue += t.total;
      sales++;
    }
    if (t.status == TransactionStatus.refunded ||
        t.status == TransactionStatus.partiallyRefunded) {
      refunds++;
    }
  }
  return (revenue: revenue, sales: sales, refunds: refunds);
});
