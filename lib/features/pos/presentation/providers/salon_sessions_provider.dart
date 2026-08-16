import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../domain/salon_session.dart';
import '../../domain/pos_models.dart';
import '../../data/salon_sessions_storage.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../staff/presentation/providers/staff_provider.dart';
import 'cart_provider.dart';

const _uuid = Uuid();

final _salonSessionsStorageProvider =
    Provider<SalonSessionsStorage>((ref) => SalonSessionsStorage());

class SalonSessionsState {
  const SalonSessionsState({
    this.sessions = const [],
    this.selectedSessionId,
    this.nextNumber = 101,
  });

  final List<SalonSession> sessions;
  final String? selectedSessionId;
  // Cosmetic display counter for the next session created ("Session 101",
  // "Session 102", ...) — matches the example in the target workflow.
  final int nextNumber;

  SalonSession? get selected =>
      sessions.where((s) => s.id == selectedSessionId).firstOrNull;

  SalonSessionsState copyWith({
    List<SalonSession>? sessions,
    String? selectedSessionId,
    int? nextNumber,
  }) =>
      SalonSessionsState(
        sessions: sessions ?? this.sessions,
        selectedSessionId: selectedSessionId ?? this.selectedSessionId,
        nextNumber: nextNumber ?? this.nextNumber,
      );
}

/// Owns the list of concurrently-open salon sessions and which one is
/// currently selected in Checkout. Each session's actual cart lives
/// separately in `cartProvider(session.id)` (see cart_provider.dart) — this
/// notifier only tracks session-level metadata (who, status, timestamps)
/// and never touches cart contents directly, except to clear/dispose a
/// session's cart when that session is closed/completed/deleted, or to
/// seed it once when restoring from disk.
///
/// Invariant: there is always at least one session once this notifier has
/// been read at all — build() seeds one immediately. This is what makes
/// "restaurant-style checkout with a single active session" keep working
/// exactly as before for a salon that never bothers creating a second one.
///
/// Persistence: build() always starts with one fresh in-memory session —
/// loadPersisted() (called once from main.dart, before runApp, using the
/// same ProviderContainer the real app runs in) then replaces it with
/// whatever was saved, if anything, restoring each session's cart via
/// CartNotifier.restore(). Every mutation below re-persists afterward; see
/// main.dart for the complementary app-lifecycle and periodic saves that
/// catch changes to cart *contents*, which this notifier doesn't observe
/// directly (those happen through the separate CartNotifier instances).
class SalonSessionsNotifier extends Notifier<SalonSessionsState> {
  // ─── Role-based access (Issue 4) ────────────────────────────────────────
  // OWNER can do everything below — this also covers "Cashier/Reception"
  // duties from the spec, since the app's Role enum only has OWNER/STAFF;
  // there's no separate cashier role to gate against, so front-desk staff
  // are expected to be logged in as OWNER. STAFF is restricted two ways:
  // session-*management* actions (create, rename, reassign staff, close,
  // delete) are blocked outright regardless of whose session it is, and
  // every other action is further scoped to sessions they can actually
  // access — see _sessionAccessible, which mirrors the exact same rule
  // visibleSalonSessionsProvider uses below so what's shown and what's
  // allowed can never drift apart.
  bool _isStaffRestricted() {
    final user = ref.read(currentUserProvider);
    return user != null && !user.isOwner;
  }

  bool _sessionAccessible(SalonSession session) {
    if (!_isStaffRestricted()) return true;
    final staffId = ref.read(currentStaffMemberProvider)?.id;
    if (staffId == null) return false;
    return _staffCanAccess(session, ref.read(cartProvider(session.id)), staffId);
  }

  // Which company the currently-held sessions actually belong to — set from
  // whatever was persisted (possibly null, for data saved before this field
  // existed) and kept in sync every time sessions are (re)persisted. Compared
  // against the live authenticated user in _reconcileCompany below, since
  // this local on-device cache has no other way to know the device just
  // switched to a different company's account (a different owner logging
  // in, or the same owner starting over after a fresh signup).
  String? _lastKnownCompanyId;

  @override
  SalonSessionsState build() {
    // Fires whenever the authenticated user changes — including the very
    // first time it resolves after startup, since build() runs (and
    // loadPersisted() is called from main.dart) before auth is known.
    ref.listen(currentUserProvider, (_, next) => _reconcileCompany(next?.companyId));

    final first = _newSession(101);
    return SalonSessionsState(
      sessions: [first],
      selectedSessionId: first.id,
      nextNumber: 102,
    );
  }

  /// Discards these on-device sessions if they belong to a different company
  /// than whoever is now authenticated — otherwise one company's session
  /// labels, staff assignments, and in-progress carts would leak straight
  /// into another company's Checkout screen on the same device.
  void _reconcileCompany(String? authCompanyId) {
    if (authCompanyId == null) return;
    if (_lastKnownCompanyId != null && _lastKnownCompanyId != authCompanyId) {
      ref.read(_salonSessionsStorageProvider).clear();
      final fresh = _newSession(101);
      state = SalonSessionsState(
        sessions: [fresh],
        selectedSessionId: fresh.id,
        nextNumber: 102,
      );
    }
    _lastKnownCompanyId = authCompanyId;
  }

  SalonSession _newSession(int number, {StaffMember? primaryStaff}) {
    final now = DateTime.now();
    return SalonSession(
      id: _uuid.v4(),
      number: number,
      primaryStaff: primaryStaff,
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Loads persisted sessions/carts if any exist, replacing the default
  /// session build() seeded. Safe to call even if nothing was ever
  /// persisted (first-ever launch) — the default session is simply kept.
  Future<void> loadPersisted() async {
    final persisted = await ref.read(_salonSessionsStorageProvider).load();
    if (persisted == null || persisted.sessions.isEmpty) return;

    // Recorded even though we can't yet compare it (auth hasn't resolved
    // at this point in startup) — _reconcileCompany uses it the moment
    // currentUserProvider fires for the first time, via the ref.listen set
    // up in build().
    _lastKnownCompanyId = persisted.companyId;

    for (final session in persisted.sessions) {
      final cart = persisted.carts[session.id];
      if (cart != null) {
        ref.read(cartProvider(session.id).notifier).restore(cart);
      }
    }

    state = SalonSessionsState(
      sessions: persisted.sessions,
      selectedSessionId: persisted.selectedSessionId ?? persisted.sessions.first.id,
      nextNumber: persisted.nextNumber,
    );
  }

  /// Persists the current sessions and their live cart contents. Called
  /// automatically after every metadata mutation below; also called from
  /// main.dart on app backgrounding and on a periodic timer, since cart
  /// *content* changes (adding/removing a service) happen through the
  /// separate CartNotifier instances this notifier doesn't observe.
  Future<void> persistNow() async {
    final carts = {
      for (final s in state.sessions) s.id: ref.read(cartProvider(s.id)),
    };
    final companyId = ref.read(currentUserProvider)?.companyId ?? _lastKnownCompanyId;
    await ref.read(_salonSessionsStorageProvider).save(
          sessions: state.sessions,
          carts: carts,
          selectedSessionId: state.selectedSessionId,
          nextNumber: state.nextNumber,
          companyId: companyId,
        );
  }

  void _persist() {
    // Fire-and-forget from synchronous mutation methods — persistence must
    // never make a UI interaction wait on a disk write.
    persistNow();
  }

  /// Creates a new session and switches to it immediately. A management
  /// action — Owner/Cashier only; a STAFF-restricted caller gets null and
  /// nothing happens (existing call sites already ignore the return value,
  /// so this can't silently create a session under someone's feet).
  String? createSession({StaffMember? primaryStaff, String? label}) {
    if (_isStaffRestricted()) return null;
    final session = _newSession(state.nextNumber, primaryStaff: primaryStaff)
        .copyWith(label: label);
    state = state.copyWith(
      sessions: [...state.sessions, session],
      selectedSessionId: session.id,
      nextNumber: state.nextNumber + 1,
    );
    _persist();
    return session.id;
  }

  void switchSession(String id) {
    final target = state.sessions.where((s) => s.id == id).firstOrNull;
    if (target == null || !_sessionAccessible(target)) return;
    state = state.copyWith(selectedSessionId: id);
    _persist();
  }

  // Management action — Owner/Cashier only, even for a staff member's own
  // session.
  void renameSession(String id, String label) {
    if (_isStaffRestricted()) return;
    _update(id, (s) => s.copyWith(label: label, updatedAt: DateTime.now()));
  }

  // Management action — Owner/Cashier only; reassigning who a session
  // belongs to is a dispatch decision, not something a stylist does to
  // their own ticket.
  void setPrimaryStaff(String id, StaffMember? staff) {
    if (_isStaffRestricted()) return;
    _update(
      id,
      (s) => s.copyWith(
        primaryStaff: staff,
        clearPrimaryStaff: staff == null,
        updatedAt: DateTime.now(),
      ),
    );
  }

  void setStatus(String id, SalonSessionStatus status) {
    final target = state.sessions.where((s) => s.id == id).firstOrNull;
    if (target == null || !_sessionAccessible(target)) return;
    _update(id, (s) => s.copyWith(status: status, updatedAt: DateTime.now()));
  }

  /// Bumps updatedAt — called from cart-mutation call sites (see
  /// cart_provider.dart's activeCartNotifierProvider usage in the UI) so
  /// "last touched" reflects real activity, not just metadata edits.
  void touch(String id) {
    final target = state.sessions.where((s) => s.id == id).firstOrNull;
    if (target == null || !_sessionAccessible(target)) return;
    _update(id, (s) => s.copyWith(updatedAt: DateTime.now()));
  }

  void _update(String id, SalonSession Function(SalonSession) f) {
    state = state.copyWith(
      sessions: [
        for (final s in state.sessions)
          if (s.id == id) f(s) else s,
      ],
    );
    _persist();
  }

  /// Closes a session without completing a sale — the cashier abandoning or
  /// merging a walk-in. Clears its cart (nothing left owning that data) and
  /// removes it from the list. If it was the selected session, another one
  /// is selected in its place; if it was the only one, a fresh session is
  /// created so the invariant (always ≥1 session) holds.
  // Management action — Owner/Cashier only; abandoning a customer's ticket
  // isn't a stylist-level decision.
  void closeSession(String id) {
    if (_isStaffRestricted()) return;
    _removeSession(id);
  }

  /// Removes a session after its sale has been completed — the cart was
  /// already cleared by the checkout success path before this is called
  /// (see ReviewSaleSheet), so this only needs to drop the session entry
  /// itself. Kept as a separate, semantically distinct method from
  /// closeSession even though the implementation is currently shared, so a
  /// future audit/analytics hook has a single, unambiguous place to attach.
  /// Accessibility-gated rather than management-only — unlike closeSession,
  /// this must keep working for a staff member completing their own sale.
  void completeSession(String id) {
    final target = state.sessions.where((s) => s.id == id).firstOrNull;
    if (target == null || !_sessionAccessible(target)) return;
    _removeSession(id);
  }

  /// Removes a session only if its cart is empty — refuses otherwise so a
  /// cashier can't accidentally discard a customer's in-progress selection
  /// by tapping delete on the wrong card. Management action — Owner/Cashier
  /// only.
  bool deleteEmptySession(String id, {required bool isEmpty}) {
    if (_isStaffRestricted()) return false;
    if (!isEmpty) return false;
    _removeSession(id);
    return true;
  }

  void _removeSession(String id) {
    if (!state.sessions.any((s) => s.id == id)) return;
    ref.read(cartProvider(id).notifier).clear();

    final remaining = state.sessions.where((s) => s.id != id).toList();
    if (remaining.isEmpty) {
      final fresh = _newSession(state.nextNumber);
      state = state.copyWith(
        sessions: [fresh],
        selectedSessionId: fresh.id,
        nextNumber: state.nextNumber + 1,
      );
      _persist();
      return;
    }

    final wasSelected = state.selectedSessionId == id;
    state = state.copyWith(
      sessions: remaining,
      selectedSessionId: wasSelected ? remaining.first.id : state.selectedSessionId,
    );
    _persist();
  }
}

final salonSessionsProvider =
    NotifierProvider<SalonSessionsNotifier, SalonSessionsState>(
  SalonSessionsNotifier.new,
);

// ─── Role-based visibility (Issue 4) ────────────────────────────────────────
//
// A session is "theirs" to a STAFF user if they're its primary staff or
// have at least one item assigned to them on it — matches
// SalonSessionsNotifier._sessionAccessible exactly, so what a staff member
// can see and what they're allowed to act on can never disagree.

bool _staffCanAccess(SalonSession session, CartState cart, String staffId) {
  if (session.primaryStaff?.id == staffId) return true;
  return cart.items.any((i) => i.assignedStaff?.id == staffId);
}

/// The logged-in user's own Staff record, when they're a STAFF-role user.
/// Sessions/items key staff assignment by Staff.id, not User.id (see
/// StaffModel), so this lookup is required before any accessibility check
/// can run — null while the staff list is still loading, or for an OWNER
/// (who has no assignment-based restriction to begin with).
final currentStaffMemberProvider = Provider<StaffMember?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return null;
  final staffList = ref.watch(activeStaffListProvider).valueOrNull ?? const [];
  for (final s in staffList) {
    if (s.userId == user.id) return s;
  }
  return null;
});

/// Every session the current user may see. OWNER sees all of them — this
/// also covers "Cashier/Reception" duties from the spec, since the app's
/// Role enum has no separate cashier role; front-desk staff are expected to
/// be logged in as OWNER. A STAFF user sees only sessions where they're the
/// primary staff or have an assigned item — never another stylist's
/// customers, not even read-only. This is the single source of truth for
/// "can see" (the Session Strip UI reads it directly); "can act on" is the
/// same rule, re-checked inside SalonSessionsNotifier so a deep link or any
/// other bypass of the UI can't reach a session this list would exclude.
final visibleSalonSessionsProvider = Provider<List<SalonSession>>((ref) {
  final all = ref.watch(salonSessionsProvider).sessions;
  final user = ref.watch(currentUserProvider);
  if (user == null || user.isOwner) return all;
  final staffId = ref.watch(currentStaffMemberProvider)?.id;
  if (staffId == null) return const [];
  return all
      .where((s) => _staffCanAccess(s, ref.watch(cartProvider(s.id)), staffId))
      .toList();
});

/// The id of whichever session Checkout is currently showing — always one
/// this user is allowed to see. If the raw selection (e.g. restored from
/// disk, or last set by a cashier) isn't visible to them — a staff member
/// logging in after someone else's session was selected — this falls back
/// to the first session they can see, and if they have none at all (not
/// yet assigned to anything), to '' — never to `state.sessions.first`,
/// which could silently hand them another staff member's session and cart.
/// '' is not a real session id (those are uuid v4), so it just resolves to
/// a fresh, empty, throwaway cart via cartProvider('').
final selectedSessionIdProvider = Provider<String>((ref) {
  final state = ref.watch(salonSessionsProvider);
  final visible = ref.watch(visibleSalonSessionsProvider);
  final raw = state.selectedSessionId;
  if (raw != null && visible.any((s) => s.id == raw)) return raw;
  if (visible.isNotEmpty) return visible.first.id;
  return '';
});

final _emptySalonSession = SalonSession(
  id: '',
  number: 0,
  status: SalonSessionStatus.waiting,
  createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  updatedAt: DateTime.fromMillisecondsSinceEpoch(0),
);

final selectedSalonSessionProvider = Provider<SalonSession>((ref) {
  final visible = ref.watch(visibleSalonSessionsProvider);
  final id = ref.watch(selectedSessionIdProvider);
  return visible.where((s) => s.id == id).firstOrNull ?? _emptySalonSession;
});
