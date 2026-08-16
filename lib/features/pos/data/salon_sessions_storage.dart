import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/salon_session.dart';
import '../domain/pos_models.dart';

const _kStorageKey = 'salon_sessions_v1';

class PersistedSalonState {
  const PersistedSalonState({
    required this.sessions,
    required this.carts,
    required this.selectedSessionId,
    required this.nextNumber,
    this.companyId,
  });
  final List<SalonSession> sessions;
  final Map<String, CartState> carts; // keyed by SalonSession.id
  final String? selectedSessionId;
  final int nextNumber;
  // Which company these sessions belong to — null for anything persisted
  // before this field existed. See SalonSessionsNotifier's reconciliation:
  // this device may log into a different company later (a different owner,
  // or the same owner's account after a fresh signup), and these are
  // otherwise-unscoped local sessions that must not leak across that
  // boundary.
  final String? companyId;
}

/// On-device persistence for open salon sessions and their carts — this is
/// the "survive an app close" mechanism for a single, shared reception
/// tablet: there's only ever one device to persist to, so a local
/// shared_preferences blob is sufficient without needing any backend
/// round-trip or sync logic. See SalonSessionsNotifier for when this is
/// read (once, at startup) and written (on session-metadata changes, app
/// backgrounding, and a periodic timer — see main.dart).
class SalonSessionsStorage {
  Future<void> save({
    required List<SalonSession> sessions,
    required Map<String, CartState> carts,
    required String? selectedSessionId,
    required int nextNumber,
    String? companyId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final json = {
      'sessions': sessions.map((s) => s.toJson()).toList(),
      'carts': carts.map((id, cart) => MapEntry(id, cart.toJson())),
      'selectedSessionId': selectedSessionId,
      'nextNumber': nextNumber,
      'companyId': companyId,
    };
    await prefs.setString(_kStorageKey, jsonEncode(json));
  }

  /// Wipes persisted sessions outright — used when the authenticated
  /// company no longer matches what's stored, so stale data is never even
  /// briefly visible rather than merely not reloaded.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kStorageKey);
  }

  /// Returns null if there's nothing persisted, or if what's stored can't
  /// be parsed (a future app version changed the shape, storage corruption,
  /// etc.) — either way, the caller falls back to a fresh default session
  /// exactly like a first-ever launch, rather than this ever being able to
  /// block startup or crash the app.
  Future<PersistedSalonState?> load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_kStorageKey);
      if (raw == null) return null;
      final json = jsonDecode(raw) as Map<String, dynamic>;

      final sessions = (json['sessions'] as List<dynamic>? ?? [])
          .map((e) => SalonSession.fromJson(e as Map<String, dynamic>))
          .toList();
      if (sessions.isEmpty) return null;

      final cartsJson = json['carts'] as Map<String, dynamic>? ?? {};
      final carts = cartsJson.map(
        (id, cartJson) =>
            MapEntry(id, CartState.fromJson(cartJson as Map<String, dynamic>)),
      );

      final maxNumber = sessions.map((s) => s.number).reduce((a, b) => a > b ? a : b);
      return PersistedSalonState(
        sessions: sessions,
        carts: carts,
        selectedSessionId: json['selectedSessionId'] as String?,
        nextNumber: json['nextNumber'] as int? ?? maxNumber + 1,
        companyId: json['companyId'] as String?,
      );
    } catch (_) {
      return null;
    }
  }
}
