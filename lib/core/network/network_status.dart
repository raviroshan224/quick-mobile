import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// True when the device has no network interface at all (airplane mode,
/// no WiFi/data). Doesn't guarantee internet reachability — a device can be
/// connected to WiFi with no upstream internet (captive portal, dead
/// hotspot) — that case is covered by [isOfflineProvider] instead, which
/// also reacts to actual request failures.
final connectivityStreamProvider = StreamProvider<List<ConnectivityResult>>((
  ref,
) {
  return Connectivity().onConnectivityChanged;
});

final hasNetworkInterfaceProvider = Provider<bool>((ref) {
  final results = ref.watch(connectivityStreamProvider).valueOrNull;
  if (results == null) return true; // unknown yet — assume online
  return results.any((r) => r != ConnectivityResult.none);
});

/// Reflects real reachability of the backend: flipped to true when a request
/// fails with a connection-level error, and back to false as soon as any
/// request succeeds. Combined with [hasNetworkInterfaceProvider] to drive the
/// offline banner.
class OfflineNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void markOffline() {
    if (!state) state = true;
  }

  void markOnline() {
    if (state) state = false;
  }
}

final isBackendUnreachableProvider = NotifierProvider<OfflineNotifier, bool>(
  OfflineNotifier.new,
);

final isOfflineProvider = Provider<bool>((ref) {
  final noInterface = !ref.watch(hasNetworkInterfaceProvider);
  final backendUnreachable = ref.watch(isBackendUnreachableProvider);
  return noInterface || backendUnreachable;
});
