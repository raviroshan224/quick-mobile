import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../data/transactions_repository.dart';
import '../../domain/transaction_models.dart';

final _transactionsRepoProvider = Provider<TransactionsRepository>(
  (ref) => TransactionsRepository(ref.read(apiClientProvider)),
);

// Format DateTime as YYYY-MM-DD for backend date-only filters.
String _dateOnly(DateTime dt) =>
    '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

// UTC ISO string with ms precision (3 decimal places). Dart's toIso8601String()
// produces 6-decimal microseconds that JS's Date constructor rejects.
String _utcMs(DateTime local) {
  final u = local.toUtc();
  String p2(int n) => n.toString().padLeft(2, '0');
  String p3(int n) => n.toString().padLeft(3, '0');
  return '${u.year}-${p2(u.month)}-${p2(u.day)}'
      'T${p2(u.hour)}:${p2(u.minute)}:${p2(u.second)}.${p3(u.millisecond)}Z';
}

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
    this.staffUserId,
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
  // Non-null when a staff member is logged in — restricts list to their own.
  final String? staffUserId;

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
        staffUserId: staffUserId,
      );
}

class TransactionListNotifier extends StateNotifier<TransactionListState> {
  TransactionListNotifier(this._repo, {String? staffUserId})
      : super(TransactionListState(staffUserId: staffUserId)) {
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
        from: state.dateFrom == null ? null : _dateOnly(state.dateFrom!),
        to: state.dateTo == null ? null : _dateOnly(state.dateTo!),
        userId: state.staffUserId,
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
        from: state.dateFrom == null ? null : _dateOnly(state.dateFrom!),
        to: state.dateTo == null ? null : _dateOnly(state.dateTo!),
        userId: state.staffUserId,
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
      staffUserId: state.staffUserId,
    );
    await _fetchPage1();
  }

  Future<void> setPaymentFilter(String? method) async {
    state = TransactionListState(
      statusFilter: state.statusFilter,
      paymentFilter: method,
      dateFrom: state.dateFrom,
      dateTo: state.dateTo,
      staffUserId: state.staffUserId,
    );
    await _fetchPage1();
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    state = TransactionListState(
      statusFilter: state.statusFilter,
      paymentFilter: state.paymentFilter,
      dateFrom: from,
      dateTo: to,
      staffUserId: state.staffUserId,
    );
    await _fetchPage1();
  }

  Future<void> refresh() => _fetchPage1();
}

final transactionListProvider =
    StateNotifierProvider<TransactionListNotifier, TransactionListState>((ref) {
  final user = ref.watch(currentUserProvider);
  final staffUserId = (user != null && !user.isOwner) ? user.id : null;
  return TransactionListNotifier(
    ref.read(_transactionsRepoProvider),
    staffUserId: staffUserId,
  );
});

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
  final user = ref.watch(currentUserProvider);
  final staffUserId = (user != null && !user.isOwner) ? user.id : null;
  final now = DateTime.now();
  // Send UTC ISO timestamps so the backend gets the correct local-day boundaries
  // regardless of server timezone (e.g. NPT midnight = June 30 18:15 UTC).
  final fromUtc = _utcMs(DateTime(now.year, now.month, now.day));
  final toUtc = _utcMs(DateTime(now.year, now.month, now.day, 23, 59, 59, 999));
  final result = await ref
      .read(_transactionsRepoProvider)
      .getAll(limit: 100, from: fromUtc, to: toUtc, userId: staffUserId);
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
