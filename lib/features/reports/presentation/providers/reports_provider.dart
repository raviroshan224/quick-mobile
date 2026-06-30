import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';
import '../../data/reports_repository.dart';
import '../../domain/reports_models.dart';

// ── Enums ─────────────────────────────────────────────────────────────────────

enum ReportsTab { sales, staff, services, inventory }

enum ReportsPeriod { today, thisWeek, thisMonth, custom }

// ── State ─────────────────────────────────────────────────────────────────────

class ReportsState {
  const ReportsState({
    required this.dateRange,
    required this.period,
    required this.activeTab,
    this.salesSummary,
    this.staffPerformance,
    this.servicePopularity,
    this.inventoryReport,
    this.isLoading = false,
    this.error,
  });

  final DateTimeRange dateRange;
  final ReportsPeriod period;
  final ReportsTab activeTab;
  final SalesSummary? salesSummary;
  final List<StaffPerformance>? staffPerformance;
  final List<ServicePopularity>? servicePopularity;
  final InventoryReport? inventoryReport;
  final bool isLoading;
  final String? error;

  ReportsState copyWith({
    DateTimeRange? dateRange,
    ReportsPeriod? period,
    ReportsTab? activeTab,
    SalesSummary? salesSummary,
    List<StaffPerformance>? staffPerformance,
    List<ServicePopularity>? servicePopularity,
    InventoryReport? inventoryReport,
    bool? isLoading,
    String? error,
    bool clearSales = false,
    bool clearStaff = false,
    bool clearServices = false,
    bool clearInventory = false,
  }) =>
      ReportsState(
        dateRange: dateRange ?? this.dateRange,
        period: period ?? this.period,
        activeTab: activeTab ?? this.activeTab,
        salesSummary: clearSales ? null : (salesSummary ?? this.salesSummary),
        staffPerformance: clearStaff ? null : (staffPerformance ?? this.staffPerformance),
        servicePopularity: clearServices ? null : (servicePopularity ?? this.servicePopularity),
        inventoryReport: clearInventory ? null : (inventoryReport ?? this.inventoryReport),
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

DateTimeRange _thisMonthRange() {
  final now = DateTime.now();
  final start = DateTime(now.year, now.month, 1);
  final end = DateTime(now.year, now.month + 1, 1).subtract(const Duration(milliseconds: 1));
  return DateTimeRange(start: start, end: end);
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class ReportsNotifier extends StateNotifier<ReportsState> {
  ReportsNotifier(this._repo)
      : super(ReportsState(
          dateRange: _thisMonthRange(),
          period: ReportsPeriod.thisMonth,
          activeTab: ReportsTab.sales,
        )) {
    _fetch();
  }

  final ReportsRepository _repo;

  String get _from => _dateOnly(state.dateRange.start);
  String get _to => _dateOnly(state.dateRange.end);

  static String _dateOnly(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> setTab(ReportsTab tab) async {
    if (state.activeTab == tab) return;
    state = state.copyWith(activeTab: tab, error: null);
    await _fetch();
  }

  Future<void> setPeriod(ReportsPeriod period, {DateTimeRange? custom}) async {
    final range = switch (period) {
      ReportsPeriod.today => () {
          final now = DateTime.now();
          final start = DateTime(now.year, now.month, now.day);
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          return DateTimeRange(start: start, end: end);
        }(),
      ReportsPeriod.thisWeek => () {
          final now = DateTime.now();
          final weekday = now.weekday;
          final start = DateTime(now.year, now.month, now.day - (weekday - 1));
          final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
          return DateTimeRange(start: start, end: end);
        }(),
      ReportsPeriod.thisMonth => _thisMonthRange(),
      ReportsPeriod.custom => custom ?? state.dateRange,
    };

    state = state.copyWith(
      period: period,
      dateRange: range,
      error: null,
      clearSales: true,
      clearStaff: true,
      clearServices: true,
      clearInventory: true,
    );
    await _fetch();
  }

  Future<void> retry() => _fetch();

  Future<void> _fetch() async {
    final tab = state.activeTab;
    final alreadyLoaded = switch (tab) {
      ReportsTab.sales => state.salesSummary != null,
      ReportsTab.staff => state.staffPerformance != null,
      ReportsTab.services => state.servicePopularity != null,
      ReportsTab.inventory => state.inventoryReport != null,
    };
    if (alreadyLoaded) return;

    state = state.copyWith(isLoading: true, error: null);
    try {
      switch (tab) {
        case ReportsTab.sales:
          final data = await _repo.getSalesSummary(from: _from, to: _to);
          state = state.copyWith(salesSummary: data, isLoading: false);
        case ReportsTab.staff:
          final data = await _repo.getStaffPerformance(from: _from, to: _to);
          state = state.copyWith(staffPerformance: data, isLoading: false);
        case ReportsTab.services:
          final data = await _repo.getServicePopularity(from: _from, to: _to);
          state = state.copyWith(servicePopularity: data, isLoading: false);
        case ReportsTab.inventory:
          final data = await _repo.getInventoryReport();
          state = state.copyWith(inventoryReport: data, isLoading: false);
      }
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }
}

// ── Providers ─────────────────────────────────────────────────────────────────

final reportsRepoProvider = Provider<ReportsRepository>(
  (ref) => ReportsRepository(ref.read(apiClientProvider)),
);

final reportsProvider = StateNotifierProvider<ReportsNotifier, ReportsState>(
  (ref) => ReportsNotifier(ref.read(reportsRepoProvider)),
);
