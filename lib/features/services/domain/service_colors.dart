import 'package:flutter/material.dart';
import 'service_models.dart';

/// A curated checkout-card color pair (soft background + a matching darker
/// accent), keyed by a short stable string stored on [ServiceModel.color].
/// Shared by the Services form (the picker) and Checkout (the renderer) so
/// neither can drift out of sync with the other.
class ServiceColorSwatch {
  const ServiceColorSwatch(this.key, this.label, this.bg, this.accent);
  final String key;
  final String label;
  final Color bg;
  final Color accent;
}

const List<ServiceColorSwatch> kServiceColorPalette = [
  ServiceColorSwatch('coral', 'Coral', Color(0xFFFFE1E1), Color(0xFFDC5A5F)),
  ServiceColorSwatch('peach', 'Peach', Color(0xFFFFEACC), Color(0xFFDB8B2A)),
  ServiceColorSwatch('yellow', 'Yellow', Color(0xFFFFF6C4), Color(0xFFC79A0A)),
  ServiceColorSwatch('mint', 'Mint', Color(0xFFD9F5E3), Color(0xFF119A62)),
  ServiceColorSwatch('teal', 'Teal', Color(0xFFD3F1F1), Color(0xFF0E9A9A)),
  ServiceColorSwatch('sky', 'Sky Blue', Color(0xFFDCEAFF), Color(0xFF3A78C2)),
  ServiceColorSwatch('lavender', 'Lavender', Color(0xFFE9E1FF), Color(0xFF7C5FD1)),
  ServiceColorSwatch('rose', 'Rose', Color(0xFFFCE1EE), Color(0xFFC94989)),
];

/// Deterministic fallback for a service that hasn't had a color explicitly
/// chosen — same hash-based assignment Checkout always used, kept as the
/// default so existing services (all currently unset) don't visually change
/// until an owner actually picks something for them.
ServiceColorSwatch autoServiceColorFor(String seedKey) {
  final seed = seedKey.codeUnits.fold(0, (s, c) => s + c);
  return kServiceColorPalette[seed % kServiceColorPalette.length];
}

/// The color a checkout card should actually render for [service] — its own
/// chosen swatch if it has one, otherwise the same auto-assigned color
/// Checkout has always used (by category, or by service id with no category).
ServiceColorSwatch resolveServiceColor(ServiceModel service) {
  final key = service.color;
  if (key != null) {
    for (final swatch in kServiceColorPalette) {
      if (swatch.key == key) return swatch;
    }
  }
  return autoServiceColorFor(service.category?.id ?? service.id);
}
