import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/inventory_repository.dart';
import '../../domain/inventory_models.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>(
  (ref) => InventoryRepository(ref.read(apiClientProvider)),
);

final productsProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(inventoryRepositoryProvider).getProducts();
});

/// Batches expired or expiring within 90 days (the expiring-stock screen
/// filters this further).
final expiringBatchesProvider = FutureProvider<List<ProductBatch>>((ref) {
  return ref.watch(inventoryRepositoryProvider).getExpiring(days: 90);
});

final lowStockProvider = FutureProvider<List<ProductModel>>((ref) {
  return ref.watch(inventoryRepositoryProvider).getProducts(lowStock: true);
});

final inventoryLogsProvider = FutureProvider<List<InventoryLogEntry>>((ref) {
  return ref.watch(inventoryRepositoryProvider).getLogs();
});

// ─── Paginated log list with type filter ──────────────────────────────────────

class LogListState {
  const LogListState({
    this.items = const [],
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.typeFilter,
  });

  final List<InventoryLogEntry> items;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final InventoryMovementType? typeFilter;

  LogListState copyWith({
    List<InventoryLogEntry>? items,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
  }) =>
      LogListState(
        items: items ?? this.items,
        hasMore: hasMore ?? this.hasMore,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        typeFilter: typeFilter,
      );
}

class LogListNotifier extends StateNotifier<LogListState> {
  LogListNotifier(this._repo) : super(const LogListState()) {
    _fetchPage1();
  }

  final InventoryRepository _repo;
  int _page = 1;

  Future<void> _fetchPage1() async {
    _page = 1;
    state = state.copyWith(
        isLoading: true, clearError: true, items: [], hasMore: true);
    try {
      final result =
          await _repo.getLogsPaginated(page: 1, type: state.typeFilter);
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
      final result = await _repo.getLogsPaginated(
          page: _page + 1, type: state.typeFilter);
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

  Future<void> setTypeFilter(InventoryMovementType? type) async {
    state = LogListState(typeFilter: type);
    await _fetchPage1();
  }

  Future<void> refresh() => _fetchPage1();
}

final logListProvider =
    StateNotifierProvider<LogListNotifier, LogListState>(
  (ref) => LogListNotifier(ref.read(inventoryRepositoryProvider)),
);
