import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../pos/domain/salon_session.dart';
import '../../../pos/domain/pos_models.dart';
import '../../../pos/presentation/providers/cart_provider.dart';
import '../../../pos/presentation/providers/salon_sessions_provider.dart';
import '../../../staff/presentation/providers/staff_provider.dart';
import '../../../auth/presentation/providers/auth_provider.dart';

String _fmtRs(double v) => 'Rs ${v.toStringAsFixed(0)}';

String _timeLabel(DateTime dt) {
  final h = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final period = dt.hour < 12 ? 'AM' : 'PM';
  final m = dt.minute.toString().padLeft(2, '0');
  return '$h:$m $period';
}

// ─── Always-visible quick-switch strip ─────────────────────────────────────────
//
// Sits above Checkout's Keypad/Calendar/Services/Items tabs — every one of
// those tabs already reads/writes whichever session is selected via
// activeCartProvider, so switching a chip here instantly changes what all
// four of them show, with no per-tab code needed to make that happen.

class SessionStrip extends ConsumerWidget {
  const SessionStrip({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // STAFF never sees the full multi-session strip — a stylist has no
    // business seeing (even read-only) another stylist's customers. Owner
    // covers "Cashier/Reception" duties too, since the app's Role enum has
    // no separate cashier role — see visibleSalonSessionsProvider. This is
    // a UI convenience only; the real boundary is enforced in
    // SalonSessionsNotifier and visibleSalonSessionsProvider regardless of
    // which widget is on screen.
    if (!ref.watch(isOwnerProvider)) return const _MySessionStrip();

    final sessionsState = ref.watch(salonSessionsProvider);
    final selectedId = ref.watch(selectedSessionIdProvider);

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              children: [
                for (final session in sessionsState.sessions)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: _SessionChip(
                      session: session,
                      selected: session.id == selectedId,
                      onTap: () => ref
                          .read(salonSessionsProvider.notifier)
                          .switchSession(session.id),
                      onLongPress: () =>
                          _showSessionActions(context, ref, session),
                    ),
                  ),
                _NewSessionChip(onTap: () => _createSession(context, ref)),
              ],
            ),
          ),
          if (sessionsState.sessions.length > 1)
            IconButton(
              icon: const Icon(Icons.view_agenda_outlined, size: 20),
              tooltip: 'All sessions',
              color: AppColors.textSecondary,
              onPressed: () => _showSessionList(context, ref),
            ),
        ],
      ),
    );
  }
}

// ─── Staff view: own session(s) only, no management ────────────────────────
//
// visibleSalonSessionsProvider already restricts this to sessions where the
// logged-in stylist is the primary staff or has an assigned item — this
// widget just renders whatever that list contains, with no create/rename/
// reassign/close/delete affordances anywhere in it (those notifier methods
// refuse for a STAFF caller regardless, but there's no reason to show a
// control that would silently do nothing). Usually a single card ("My
// Session"); occasionally more than one if a stylist is serving multiple
// customers concurrently, in which case switching between just their own
// is still allowed.
class _MySessionStrip extends ConsumerWidget {
  const _MySessionStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mySessions = ref.watch(visibleSalonSessionsProvider);
    final selectedId = ref.watch(selectedSessionIdProvider);

    if (mySessions.isEmpty) {
      return Container(
        height: 56,
        alignment: Alignment.center,
        decoration: const BoxDecoration(
          color: AppColors.surfaceVariant,
          border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
        ),
        child: const Text(
          'No session assigned to you yet',
          style: TextStyle(fontSize: 13, color: AppColors.textTertiary),
        ),
      );
    }

    return Container(
      height: 56,
      decoration: const BoxDecoration(
        color: AppColors.surfaceVariant,
        border: Border(bottom: BorderSide(color: AppColors.divider, width: 0.5)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        children: [
          for (final session in mySessions)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _SessionChip(
                session: session,
                selected: session.id == selectedId,
                onTap: () =>
                    ref.read(salonSessionsProvider.notifier).switchSession(session.id),
                // No management sheet for staff — nothing here to long-press into.
                onLongPress: null,
              ),
            ),
        ],
      ),
    );
  }
}

class _SessionChip extends ConsumerWidget {
  const _SessionChip({
    required this.session,
    required this.selected,
    required this.onTap,
    this.onLongPress,
  });
  final SalonSession session;
  final bool selected;
  final VoidCallback onTap;
  // Null for the staff-restricted strip (_MySessionStrip) — there's no
  // management sheet a stylist is allowed to open.
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider(session.id));
    final statusColor = session.status == SalonSessionStatus.inProgress
        ? AppColors.success
        : AppColors.warning;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : AppColors.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(color: statusColor, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              session.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : AppColors.textPrimary,
              ),
            ),
            if (session.primaryStaff != null) ...[
              const SizedBox(width: 5),
              Text(
                '· ${session.primaryStaff!.firstName}',
                style: TextStyle(
                  fontSize: 12,
                  color: selected
                      ? Colors.white.withValues(alpha: 0.75)
                      : AppColors.textTertiary,
                ),
              ),
            ],
            if (cart.itemCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.2)
                      : AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '${cart.itemCount}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: selected ? Colors.white : AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NewSessionChip extends StatelessWidget {
  const _NewSessionChip({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.divider),
        ),
        child: const Icon(Icons.add, size: 18, color: AppColors.textSecondary),
      ),
    );
  }
}

// ─── Create session (with an optional staff prompt) ───────────────────────────

Future<void> _createSession(BuildContext context, WidgetRef ref) async {
  final staff = await pickStaffMember(context, ref, title: 'Assign staff to new session');
  if (!context.mounted) return;
  ref.read(salonSessionsProvider.notifier).createSession(primaryStaff: staff);
}

/// Shared by session creation/reassignment (here) and per-service staff
/// override (ReviewSaleSheet's cart list) — one picker UI, reused rather
/// than duplicated. Returns null if the sheet is dismissed/skipped (staff
/// assignment is never strictly required up front — e.g. a customer sits
/// down before it's decided who'll serve them).
Future<StaffMember?> pickStaffMember(
  BuildContext context,
  WidgetRef ref, {
  required String title,
}) {
  return showModalBottomSheet<StaffMember?>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _StaffPickerSheet(title: title),
  );
}

class _StaffPickerSheet extends ConsumerWidget {
  const _StaffPickerSheet({required this.title});
  final String title;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(activeStaffListProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.7),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  Text(title,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.pop(context, null),
                    child: const Text('Skip'),
                  ),
                ],
              ),
            ),
            Flexible(
              child: staffAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load staff: $e'),
                ),
                data: (staffList) => staffList.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text('No staff added yet',
                            style: TextStyle(color: AppColors.textTertiary)),
                      )
                    : ListView.builder(
                        shrinkWrap: true,
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: staffList.length,
                        itemBuilder: (_, i) {
                          final s = staffList[i];
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: AppColors.primaryLight,
                              child: Text(
                                s.firstName.isNotEmpty ? s.firstName[0] : '?',
                                style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w700),
                              ),
                            ),
                            title: Text('${s.firstName} ${s.lastName}'),
                            onTap: () => Navigator.pop(context, s),
                          );
                        },
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Long-press quick actions ──────────────────────────────────────────────────

void _showSessionActions(
  BuildContext context,
  WidgetRef ref,
  SalonSession session,
) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (_) => _SessionActionsSheet(session: session),
  );
}

class _SessionActionsSheet extends ConsumerWidget {
  const _SessionActionsSheet({required this.session});
  final SalonSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(session.displayName,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600)),
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Rename session'),
              onTap: () {
                Navigator.pop(context);
                _renameSession(context, ref, session);
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(session.primaryStaff == null
                  ? 'Assign staff'
                  : 'Reassign staff (${session.primaryStaff!.firstName})'),
              onTap: () async {
                Navigator.pop(context);
                final staff = await pickStaffMember(context, ref,
                    title: 'Assign staff to ${session.displayName}');
                ref
                    .read(salonSessionsProvider.notifier)
                    .setPrimaryStaff(session.id, staff);
              },
            ),
            ListTile(
              leading: Icon(
                session.status == SalonSessionStatus.inProgress
                    ? Icons.pause_circle_outline
                    : Icons.play_circle_outline,
              ),
              title: Text(session.status == SalonSessionStatus.inProgress
                  ? 'Mark as Waiting'
                  : 'Mark as In Progress'),
              onTap: () {
                Navigator.pop(context);
                ref.read(salonSessionsProvider.notifier).setStatus(
                      session.id,
                      session.status == SalonSessionStatus.inProgress
                          ? SalonSessionStatus.waiting
                          : SalonSessionStatus.inProgress,
                    );
              },
            ),
            Consumer(builder: (context, ref, _) {
              final cart = ref.watch(cartProvider(session.id));
              final isEmpty = cart.items.isEmpty;
              return ListTile(
                leading: Icon(Icons.close_rounded,
                    color: isEmpty ? AppColors.danger : AppColors.textTertiary),
                title: Text(
                  isEmpty ? 'Delete empty session' : 'Close session',
                  style: TextStyle(
                      color: isEmpty ? AppColors.danger : AppColors.textPrimary),
                ),
                subtitle: isEmpty
                    ? null
                    : Text(
                        '${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} will be discarded — this cannot be undone.',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textTertiary),
                      ),
                onTap: () async {
                  if (isEmpty) {
                    Navigator.pop(context);
                    ref
                        .read(salonSessionsProvider.notifier)
                        .deleteEmptySession(session.id, isEmpty: true);
                    return;
                  }
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Close this session?'),
                      content: Text(
                          '${session.displayName} has ${cart.itemCount} item${cart.itemCount == 1 ? '' : 's'} in progress. Closing it discards them — this cannot be undone.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Close Session',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  );
                  if (confirmed != true || !context.mounted) return;
                  Navigator.pop(context);
                  ref.read(salonSessionsProvider.notifier).closeSession(session.id);
                },
              );
            }),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _renameSession(BuildContext context, WidgetRef ref, SalonSession session) {
    final ctrl = TextEditingController(text: session.label ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Rename Session'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          decoration: InputDecoration(
            hintText: session.displayName,
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(
              borderSide: BorderSide.none,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              ref
                  .read(salonSessionsProvider.notifier)
                  .renameSession(session.id, ctrl.text.trim());
              Navigator.pop(ctx);
            },
            child: const Text('Save',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

// ─── Full session list (detail cards) ──────────────────────────────────────────

void _showSessionList(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _SessionListSheet(),
  );
}

class _SessionListSheet extends ConsumerWidget {
  const _SessionListSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Defense-in-depth: this sheet is only ever opened from the owner-only
    // branch of SessionStrip today, but it reads the role-filtered list
    // directly rather than trusting that — so even a future entry point
    // (deep link, new button) can't leak every stylist's sessions to a
    // STAFF caller through here.
    final sessions = ref.watch(visibleSalonSessionsProvider);
    final selectedId = ref.watch(selectedSessionIdProvider);

    return Container(
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.85),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  const Text('Open Sessions',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
                  const Spacer(),
                  Text('${sessions.length}',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textTertiary)),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                itemCount: sessions.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final session = sessions[i];
                  return _SessionDetailCard(
                    session: session,
                    selected: session.id == selectedId,
                    onTap: () {
                      ref
                          .read(salonSessionsProvider.notifier)
                          .switchSession(session.id);
                      Navigator.pop(context);
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionDetailCard extends ConsumerWidget {
  const _SessionDetailCard({
    required this.session,
    required this.selected,
    required this.onTap,
  });
  final SalonSession session;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartProvider(session.id));
    final statusColor = session.status == SalonSessionStatus.inProgress
        ? AppColors.success
        : AppColors.warning;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primaryLight : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.divider,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(session.displayName,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    session.status.label,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text(_timeLabel(session.createdAt),
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textTertiary)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.person_outline,
                    size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  cart.customerLabel ?? 'Walk-in',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(width: 12),
                Icon(Icons.badge_outlined, size: 14, color: AppColors.textTertiary),
                const SizedBox(width: 4),
                Text(
                  session.primaryStaff != null
                      ? '${session.primaryStaff!.firstName} ${session.primaryStaff!.lastName}'
                      : 'Unassigned',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  '${cart.itemCount} service${cart.itemCount == 1 ? '' : 's'}',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textTertiary),
                ),
                const Spacer(),
                Text(
                  _fmtRs(cart.total),
                  style: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
