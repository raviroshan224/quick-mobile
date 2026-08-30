import 'package:unified_esc_pos_printer/unified_esc_pos_printer.dart';

import '../domain/printer_connection_config.dart';

/// Talks to the ESC/POS printer wired to the cash drawer.
///
/// Stateless per call — connects, sends the drawer-kick command, and
/// disconnects immediately, rather than holding a persistent connection.
/// This action is infrequent enough that reconnect/heartbeat management
/// would be pure complexity with no payoff. This class is the single seam
/// between the app and the third-party `unified_esc_pos_printer` package —
/// swapping transports or packages later only touches this file.
class CashDrawerService {
  static const _connectTimeout = Duration(seconds: 5);
  static const _scanTimeout = Duration(seconds: 5);

  // `PrinterManager.openCashDrawer()` / `Ticket.openCashDrawer()` in
  // unified_esc_pos_printer 3.4.0 send the malformed sequence
  // `ESC p '0' '3' '0'` (commands.dart's cCashDrawerPin2/cCashDrawerPin5
  // constants build the ASCII *characters* "0"/"3"/"0" instead of raw byte
  // values) — confirmed against real hardware: the printer accepts the
  // write but the drawer never kicks. We send the correct
  // `ESC p m t1 t2` bytes ourselves instead. Standard wiring uses pin 2;
  // t1/t2 (25, 250 -> ~50ms on / ~500ms off) are the values used across
  // effectively every ESC/POS cash-drawer implementation.
  static const _drawerKickPin2 = [0x1B, 0x70, 0x00, 0x19, 0xFA];

  Future<List<PrinterConnectionConfig>> scanUsbDevices() async {
    final manager = PrinterManager();
    try {
      final devices = await manager.scanPrinters(
        types: const {PrinterConnectionType.usb},
        timeout: _scanTimeout,
      );
      return devices
          .whereType<UsbPrinterDevice>()
          .map((d) => PrinterConnectionConfig.usb(
                identifier: d.identifier,
                deviceName: d.name,
              ))
          .toList();
    } on PrinterException {
      return const [];
    } finally {
      await manager.dispose();
    }
  }

  /// Probes the phone's current WiFi subnet for printers listening on the
  /// raw ESC/POS port (9100) — a few seconds of parallel TCP connect
  /// attempts across the /24. Manual IP entry stays available in the UI
  /// since this can miss printers on a different VLAN or behind a firewall.
  Future<List<PrinterConnectionConfig>> scanNetworkDevices() async {
    final manager = PrinterManager();
    try {
      final devices = await manager.scanPrinters(
        types: const {PrinterConnectionType.network},
        timeout: _scanTimeout,
      );
      return devices
          .whereType<NetworkPrinterDevice>()
          .map((d) => PrinterConnectionConfig.network(host: d.host, networkPort: d.port))
          .toList();
    } on PrinterException {
      return const [];
    } finally {
      await manager.dispose();
    }
  }

  Future<CashDrawerResult> openDrawer(PrinterConnectionConfig? config) async {
    if (config == null || !config.isValid) {
      return const CashDrawerResult.failure(CashDrawerFailureReason.notConfigured);
    }

    final manager = PrinterManager();
    try {
      await manager.connect(_deviceFor(config), timeout: _connectTimeout);
      await manager.printBytes(_drawerKickPin2);
      return const CashDrawerResult.success();
    } on PrinterWriteException catch (e) {
      return CashDrawerResult.failure(CashDrawerFailureReason.writeFailed, message: e.message);
    } on PrinterException catch (e) {
      // Covers connection failures, timeouts, USB permission denial, and
      // "device not found" — the package doesn't expose enough detail to
      // split these further; e.message carries the specifics for the UI.
      return CashDrawerResult.failure(CashDrawerFailureReason.connectionFailed, message: e.message);
    } catch (e) {
      return CashDrawerResult.failure(CashDrawerFailureReason.unknown, message: e.toString());
    } finally {
      try {
        await manager.disconnect();
      } catch (_) {
        // Already torn down by the failure above — nothing left to clean up.
      }
      await manager.dispose();
    }
  }

  PrinterDevice _deviceFor(PrinterConnectionConfig config) {
    if (config.transport == CashDrawerTransport.network) {
      return NetworkPrinterDevice(
        name: 'Cash drawer printer',
        host: config.networkHost!,
        port: config.networkPort,
      );
    }
    return UsbPrinterDevice(
      name: config.usbDeviceName ?? 'USB printer',
      identifier: config.usbIdentifier!,
      usbPlatform: UsbPlatform.android,
    );
  }
}
