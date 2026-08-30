enum CashDrawerTransport { network, usb }

/// Where to reach the ESC/POS printer that the drawer is wired into.
///
/// Local-only, per-device config — see [CashDrawerSettingsRepository] for
/// why this never goes through the backend.
class PrinterConnectionConfig {
  const PrinterConnectionConfig.network({required String host, this.networkPort = 9100})
      : transport = CashDrawerTransport.network,
        networkHost = host,
        usbIdentifier = null,
        usbDeviceName = null;

  const PrinterConnectionConfig.usb({
    required String identifier,
    required String deviceName,
  })  : transport = CashDrawerTransport.usb,
        usbIdentifier = identifier,
        usbDeviceName = deviceName,
        networkHost = null,
        networkPort = 9100;

  const PrinterConnectionConfig._raw({
    required this.transport,
    required this.networkHost,
    required this.networkPort,
    required this.usbIdentifier,
    required this.usbDeviceName,
  });

  final CashDrawerTransport transport;
  final String? networkHost;
  final int networkPort;

  /// `'<vendorId>:<productId>'` on Android — see [PrinterConnectionConfig.usb].
  final String? usbIdentifier;
  final String? usbDeviceName;

  bool get isValid => switch (transport) {
        CashDrawerTransport.network => networkHost != null && networkHost!.trim().isNotEmpty,
        CashDrawerTransport.usb => usbIdentifier != null && usbIdentifier!.trim().isNotEmpty,
      };

  String get label => switch (transport) {
        CashDrawerTransport.network => '$networkHost:$networkPort',
        CashDrawerTransport.usb => usbDeviceName ?? usbIdentifier ?? 'USB printer',
      };

  Map<String, dynamic> toJson() => {
        'transport': transport.name,
        'networkHost': networkHost,
        'networkPort': networkPort,
        'usbIdentifier': usbIdentifier,
        'usbDeviceName': usbDeviceName,
      };

  static PrinterConnectionConfig? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final transportName = json['transport'] as String?;
    CashDrawerTransport? transport;
    for (final t in CashDrawerTransport.values) {
      if (t.name == transportName) {
        transport = t;
        break;
      }
    }
    if (transport == null) return null;
    return PrinterConnectionConfig._raw(
      transport: transport,
      networkHost: json['networkHost'] as String?,
      networkPort: json['networkPort'] as int? ?? 9100,
      usbIdentifier: json['usbIdentifier'] as String?,
      usbDeviceName: json['usbDeviceName'] as String?,
    );
  }
}

enum CashDrawerFailureReason {
  /// No connection configured yet (or the saved config is incomplete).
  notConfigured,

  /// Couldn't reach or open the printer (bad IP, printer off, USB unplugged,
  /// USB permission denied, timed out, etc.) — see [CashDrawerResult.message].
  connectionFailed,

  /// Connected, but sending the drawer-kick bytes failed.
  writeFailed,

  unknown,
}

class CashDrawerResult {
  const CashDrawerResult.success()
      : success = true,
        reason = null,
        message = null;

  const CashDrawerResult.failure(this.reason, {this.message}) : success = false;

  final bool success;
  final CashDrawerFailureReason? reason;
  final String? message;
}
