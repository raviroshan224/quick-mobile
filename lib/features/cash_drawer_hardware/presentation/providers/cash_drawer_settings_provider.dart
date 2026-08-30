import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/cash_drawer_settings_repository.dart';
import '../../domain/printer_connection_config.dart';

final _cashDrawerSettingsRepoProvider =
    Provider<CashDrawerSettingsRepository>((ref) => CashDrawerSettingsRepository());

class _CashDrawerSettingsNotifier extends StateNotifier<CashDrawerSettings> {
  _CashDrawerSettingsNotifier(this._repo) : super(const CashDrawerSettings()) {
    _load();
  }

  final CashDrawerSettingsRepository _repo;

  Future<void> _load() async {
    state = await _repo.load();
  }

  Future<void> setEnabled(bool enabled) async {
    state = state.copyWith(enabled: enabled);
    await _repo.saveEnabled(enabled);
  }

  Future<void> setConnection(PrinterConnectionConfig? connection) async {
    state = state.copyWith(connection: connection, clearConnection: connection == null);
    await _repo.saveConnection(connection);
  }

  Future<void> setButtonPosition(CashDrawerButtonPosition position) async {
    state = state.copyWith(buttonPosition: position);
    await _repo.saveButtonPosition(position);
  }
}

final cashDrawerSettingsProvider =
    StateNotifierProvider<_CashDrawerSettingsNotifier, CashDrawerSettings>(
  (ref) => _CashDrawerSettingsNotifier(ref.read(_cashDrawerSettingsRepoProvider)),
);
