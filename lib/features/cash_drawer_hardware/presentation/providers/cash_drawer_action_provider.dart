import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cash_drawer_service.dart';
import '../../domain/printer_connection_config.dart';
import 'cash_drawer_settings_provider.dart';

enum CashDrawerActionStatus { idle, sending, success, error }

class CashDrawerActionState {
  const CashDrawerActionState({
    this.status = CashDrawerActionStatus.idle,
    this.result,
  });

  final CashDrawerActionStatus status;
  final CashDrawerResult? result;
}

final _cashDrawerServiceProvider = Provider<CashDrawerService>((ref) => CashDrawerService());

class CashDrawerActionNotifier extends StateNotifier<CashDrawerActionState> {
  CashDrawerActionNotifier(this._ref) : super(const CashDrawerActionState());

  final Ref _ref;
  Timer? _resetTimer;

  /// Fires the drawer-kick. Ignored while a previous tap is still in
  /// flight, so double-taps can't queue multiple kicks.
  Future<void> open() async {
    if (state.status == CashDrawerActionStatus.sending) return;

    _resetTimer?.cancel();
    state = const CashDrawerActionState(status: CashDrawerActionStatus.sending);

    final connection = _ref.read(cashDrawerSettingsProvider).connection;
    final result = await _ref.read(_cashDrawerServiceProvider).openDrawer(connection);

    state = CashDrawerActionState(
      status: result.success ? CashDrawerActionStatus.success : CashDrawerActionStatus.error,
      result: result,
    );

    _resetTimer = Timer(const Duration(milliseconds: 800), () {
      if (mounted) state = const CashDrawerActionState();
    });
  }

  @override
  void dispose() {
    _resetTimer?.cancel();
    super.dispose();
  }
}

final cashDrawerActionProvider =
    StateNotifierProvider<CashDrawerActionNotifier, CashDrawerActionState>(
  (ref) => CashDrawerActionNotifier(ref),
);
