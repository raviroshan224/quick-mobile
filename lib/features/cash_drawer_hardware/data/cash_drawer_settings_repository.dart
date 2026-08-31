import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../domain/printer_connection_config.dart';

/// Fractional (0..1) position of the floating button, relative to screen
/// size — stable across rotation and across devices with different screens.
class CashDrawerButtonPosition {
  const CashDrawerButtonPosition({required this.dx, required this.dy});

  final double dx;
  final double dy;
}

class CashDrawerSettings {
  const CashDrawerSettings({
    this.enabled = false,
    this.connection,
    this.buttonPosition,
    this.autoOpenOnCashPayment = false,
  });

  final bool enabled;
  final PrinterConnectionConfig? connection;

  /// Null until the user has dragged the button at least once — the widget
  /// falls back to a sensible default position in that case.
  final CashDrawerButtonPosition? buttonPosition;

  /// When true, a cash-tender checkout completing successfully fires the
  /// drawer kick automatically — independent of whether the floating
  /// button itself (`enabled`) is shown.
  final bool autoOpenOnCashPayment;

  CashDrawerSettings copyWith({
    bool? enabled,
    PrinterConnectionConfig? connection,
    bool clearConnection = false,
    CashDrawerButtonPosition? buttonPosition,
    bool? autoOpenOnCashPayment,
  }) =>
      CashDrawerSettings(
        enabled: enabled ?? this.enabled,
        connection: clearConnection ? null : (connection ?? this.connection),
        buttonPosition: buttonPosition ?? this.buttonPosition,
        autoOpenOnCashPayment: autoOpenOnCashPayment ?? this.autoOpenOnCashPayment,
      );
}

/// Persists cash-drawer button settings locally on this device.
///
/// Deliberately **not** routed through the backend `SettingsRepository` —
/// this describes hardware wired to *this* physical terminal, so a
/// multi-terminal salon must not have one device's printer config overwrite
/// another's.
class CashDrawerSettingsRepository {
  static const _kEnabled = 'cash_drawer_enabled';
  static const _kConnection = 'cash_drawer_connection';
  static const _kPosDx = 'cash_drawer_button_dx';
  static const _kPosDy = 'cash_drawer_button_dy';
  static const _kAutoOpenCash = 'cash_drawer_auto_open_cash';

  Future<CashDrawerSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    PrinterConnectionConfig? connection;
    final raw = prefs.getString(_kConnection);
    if (raw != null) {
      try {
        connection = PrinterConnectionConfig.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } catch (_) {
        // Corrupt/old-shape value — treat as unconfigured rather than crash.
      }
    }

    final dx = prefs.getDouble(_kPosDx);
    final dy = prefs.getDouble(_kPosDy);

    return CashDrawerSettings(
      enabled: prefs.getBool(_kEnabled) ?? false,
      connection: connection,
      buttonPosition:
          (dx != null && dy != null) ? CashDrawerButtonPosition(dx: dx, dy: dy) : null,
      autoOpenOnCashPayment: prefs.getBool(_kAutoOpenCash) ?? false,
    );
  }

  Future<void> saveEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kEnabled, enabled);
  }

  Future<void> saveAutoOpenOnCashPayment(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kAutoOpenCash, value);
  }

  Future<void> saveConnection(PrinterConnectionConfig? connection) async {
    final prefs = await SharedPreferences.getInstance();
    if (connection == null) {
      await prefs.remove(_kConnection);
    } else {
      await prefs.setString(_kConnection, jsonEncode(connection.toJson()));
    }
  }

  Future<void> saveButtonPosition(CashDrawerButtonPosition position) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kPosDx, position.dx);
    await prefs.setDouble(_kPosDy, position.dy);
  }
}
