import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Resolves hostnames via DNS-over-HTTPS when the device's normal (OS-level)
/// DNS resolver fails — e.g. captive WiFi portals, misconfigured private DNS,
/// or carrier resolvers that don't know about third-party domains.
///
/// The DoH servers below are queried by IP literal so the fallback path
/// itself never depends on DNS working.
class DnsFallbackResolver {
  final Map<String, _CachedIp> _cache = {};

  static const _cacheTtl = Duration(minutes: 5);
  static const _dohServers = ['8.8.8.8', '8.8.4.4', '1.1.1.1', '1.0.0.1'];

  // Once HttpClient.connectionFactory is set, dart:io no longer enforces its
  // own connectionTimeout around the connection attempt — the factory owns
  // that entirely. Without an explicit bound here, a socket/TLS handshake
  // that never completes (e.g. a non-routable address on a dual-stack
  // network) hangs forever with no error, no retry, and no user feedback.
  static const _connectTimeout = Duration(seconds: 10);

  Future<ConnectionTask<Socket>> connect(
    Uri uri,
    String? proxyHost,
    int? proxyPort,
  ) async {
    final host = uri.host;
    final port = uri.port;
    final isSecure = uri.isScheme('https');

    // When HttpClient delegates to a custom connectionFactory, it no longer
    // performs the TLS upgrade itself — the factory must hand back an
    // already-secured socket for https URIs, or requests go out as
    // plaintext on the TLS port.
    Future<Socket> secureIfNeeded(Socket socket) {
      if (!isSecure) return Future.value(socket);
      return SecureSocket.secure(socket, host: host);
    }

    Future<Socket> connectTo(InternetAddress address) {
      return Socket.connect(address, port)
          .then(secureIfNeeded)
          .timeout(_connectTimeout);
    }

    try {
      // The OS resolver call itself has no built-in timeout here — on some
      // Android setups a stalled AAAA (IPv6) query can hang getaddrinfo
      // indefinitely rather than erroring, so this needs its own bound or
      // the DoH fallback below never gets a chance to run.
      final addresses =
          await InternetAddress.lookup(host).timeout(_connectTimeout);
      // IPv4 first: on dual-stack emulator/VPN networks the resolver can
      // return an IPv6 address that isn't actually routable, and this app
      // only ever talks to one IPv4-hosted API — prefer what's known to work
      // rather than gambling on whichever family the OS lists first.
      final sorted = [...addresses]..sort((a, b) =>
          (a.type == InternetAddressType.IPv4 ? 0 : 1) -
          (b.type == InternetAddressType.IPv4 ? 0 : 1));
      if (sorted.isNotEmpty) {
        return ConnectionTask.fromSocket(connectTo(sorted.first), () {});
      }
    } catch (_) {
      // OS resolver failed or timed out — fall back to DNS-over-HTTPS below.
    }

    final ip = await _resolveViaDoH(host);
    if (ip != null) {
      return ConnectionTask.fromSocket(
        connectTo(InternetAddress(ip)),
        () {},
      );
    }

    // No fallback available either — let the lookup throw (its standard
    // SocketException, or the TimeoutException below) so existing error
    // handling takes over.
    final addresses =
        await InternetAddress.lookup(host).timeout(_connectTimeout);
    return ConnectionTask.fromSocket(connectTo(addresses.first), () {});
  }

  Future<String?> _resolveViaDoH(String host) async {
    final cached = _cache[host];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.ip;
    }

    for (final server in _dohServers) {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 5);
      try {
        final uri = Uri.parse('https://$server/resolve?name=$host&type=A');
        final request = await client.getUrl(uri);
        request.headers.set('accept', 'application/dns-json');
        final response = await request.close();
        if (response.statusCode != 200) continue;

        final body = await response.transform(utf8.decoder).join();
        final json = jsonDecode(body) as Map<String, dynamic>;
        final answers = (json['Answer'] as List<dynamic>?)
            ?.cast<Map<String, dynamic>>();
        final record = answers?.firstWhere(
          (a) => a['type'] == 1,
          orElse: () => const {},
        );
        final ip = record?['data'] as String?;
        if (ip != null) {
          _cache[host] = _CachedIp(ip, DateTime.now().add(_cacheTtl));
          return ip;
        }
      } catch (_) {
        continue;
      } finally {
        client.close(force: true);
      }
    }
    return null;
  }
}

class _CachedIp {
  _CachedIp(this.ip, this.expiresAt);
  final String ip;
  final DateTime expiresAt;
}
