import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/models/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../more/presentation/screens/settings_screen.dart'
    show salonSettingsProvider;
import '../../data/bookings_repository.dart';
import '../../domain/booking_models.dart';
import '../../../../shared/widgets/pull_to_refresh.dart';
import '../../../services/domain/service_models.dart';
import '../../../services/presentation/providers/services_provider.dart';
import '../../../../core/utils/phone_validator.dart';
import '../widgets/staff_picker.dart';
import '../../../customers/domain/customer_models.dart';
import '../../../customers/presentation/providers/customers_provider.dart';

String _dateKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// ─── Bookings provider (per selected day) ─────────────────────────────────────

final _bookingsRepoProvider = Provider<BookingsRepository>(
  (ref) => BookingsRepository(ref.read(apiClientProvider)),
);

class BookingsState {
  const BookingsState({
    this.items = const [],
    this.isLoading = true,
    this.error,
  });

  final List<Booking> items;
  final bool isLoading;
  final String? error;

  BookingsState copyWith({
    List<Booking>? items,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) => BookingsState(
    items: items ?? this.items,
    isLoading: isLoading ?? this.isLoading,
    error: clearError ? null : (error ?? this.error),
  );
}

class BookingsNotifier extends StateNotifier<BookingsState> {
  BookingsNotifier(this._repo, this.dateKey) : super(const BookingsState()) {
    refresh();
  }

  final BookingsRepository _repo;
  final String dateKey;

  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final result = await _repo.getAll(date: dateKey, limit: 100);
      state = state.copyWith(items: result.items, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> create(BookingRequest req) async {
    await _repo.create(req);
    await refresh();
  }

  Future<void> updateBooking(String id, BookingRequest req) async {
    await _repo.update(id, req);
    await refresh();
  }

  Future<void> updateStatus(String id, BookingStatus status) async {
    await _repo.updateStatus(id, status);
    await refresh();
  }

  Future<void> delete(String id) async {
    await _repo.delete(id);
    await refresh();
  }
}

final bookingsProvider =
    StateNotifierProvider.family<BookingsNotifier, BookingsState, String>(
      (ref, dateKey) =>
          BookingsNotifier(ref.read(_bookingsRepoProvider), dateKey),
    );

// ─── Calendar Tab ─────────────────────────────────────────────────────────────

class CalendarTab extends HookConsumerWidget {
  const CalendarTab({super.key, this.staffId});

  /// When set, only bookings assigned to this staff member (staff record id,
  /// the same id the booking form stores as [Booking.staffId]) are listed.
  final String? staffId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = useState(DateTime.now());
    final dateKey = _dateKey(selectedDate.value);
    final bookingsState = ref.watch(bookingsProvider(dateKey));

    final todayBookings = [
      for (final b in bookingsState.items)
        if (staffId == null || b.staffId == staffId) b,
    ]..sort((a, b) {
        return a.time.compareTo(b.time);
      });

    return Column(
      children: [
        // ── Date strip ──────────────────────────────────────────────────
        _DateStrip(
          selectedDate: selectedDate.value,
          onDateChanged: (d) => selectedDate.value = d,
        ),
        const Divider(height: 1, color: AppColors.surfaceVariant),

        // ── Bookings list or empty state ────────────────────────────────
        Expanded(
          child: PullToRefresh(
            onRefresh: () =>
                ref.read(bookingsProvider(dateKey).notifier).refresh(),
            child: bookingsState.isLoading
                ? const Center(child: CircularProgressIndicator())
                : bookingsState.error != null
                ? _ErrorState(
                    message: bookingsState.error!,
                    onRetry: () =>
                        ref.read(bookingsProvider(dateKey).notifier).refresh(),
                  )
                : todayBookings.isEmpty
                ? _EmptyBookings(
                    assignedOnly: staffId != null,
                    onAdd: () =>
                        _showBookingForm(context, ref, selectedDate.value),
                  )
                : ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                    itemCount: todayBookings.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _BookingCard(
                      booking: todayBookings[i],
                      onEdit: () => _showBookingForm(
                        context,
                        ref,
                        selectedDate.value,
                        existing: todayBookings[i],
                      ),
                      onDelete: () => _confirmDelete(
                        context,
                        ref,
                        dateKey,
                        todayBookings[i],
                      ),
                      onStatusChange: (status) {
                        ref
                            .read(bookingsProvider(dateKey).notifier)
                            .updateStatus(todayBookings[i].id, status);
                      },
                    ),
                  ),
          ),
        ),

        // ── Create booking button ───────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () =>
                  _showBookingForm(context, ref, selectedDate.value),
              icon: const Icon(Icons.add, size: 18),
              label: const Text(
                'Create Booking',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showBookingForm(
    BuildContext context,
    WidgetRef ref,
    DateTime date, {
    Booking? existing,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BookingFormSheet(date: date, existing: existing),
    );
  }

  void _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    String dateKey,
    Booking booking,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Booking', style: TextStyle(fontSize: 16)),
        content: Text(
          'Delete booking for ${booking.customerName}?',
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(bookingsProvider(dateKey).notifier).delete(booking.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Error state ──────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 40,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 12),
            const Text(
              'Failed to load bookings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Date strip (horizontal day selector) ─────────────────────────────────────

class _DateStrip extends StatelessWidget {
  const _DateStrip({required this.selectedDate, required this.onDateChanged});
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
  static const _months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Generate 7 days starting from today
    final dates = List.generate(7, (i) => today.add(Duration(days: i)));

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Text(
                  '${_months[selectedDate.month - 1]} ${selectedDate.year}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => onDateChanged(today),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: const Text(
                      'Today',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 60,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: dates.length,
              itemBuilder: (_, i) {
                final d = dates[i];
                final isSelected =
                    d.year == selectedDate.year &&
                    d.month == selectedDate.month &&
                    d.day == selectedDate.day;
                final isToday = d == today;
                return GestureDetector(
                  onTap: () => onDateChanged(d),
                  child: Container(
                    width: 46,
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: isToday && !isSelected
                          ? Border.all(color: AppColors.divider)
                          : null,
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _days[d.weekday - 1],
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            color: isSelected
                                ? AppColors.textTertiary
                                : AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${d.day}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Empty bookings state ─────────────────────────────────────────────────────

class _EmptyBookings extends StatelessWidget {
  const _EmptyBookings({required this.onAdd, this.assignedOnly = false});
  final VoidCallback onAdd;
  final bool assignedOnly;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 28,
                color: AppColors.textTertiary,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'No bookings',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              assignedOnly
                  ? 'No bookings assigned to you for this date.'
                  : 'No bookings scheduled for this date.\nTap below to create one.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Booking card ─────────────────────────────────────────────────────────────

class _BookingCard extends StatelessWidget {
  const _BookingCard({
    required this.booking,
    required this.onEdit,
    required this.onDelete,
    required this.onStatusChange,
  });
  final Booking booking;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<BookingStatus> onStatusChange;

  Color get _statusColor => switch (booking.status) {
    BookingStatus.scheduled => AppColors.primary,
    BookingStatus.completed => const Color(0xFF10B981),
    BookingStatus.cancelled => AppColors.danger,
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Time badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  booking.timeLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Status badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  booking.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _statusColor,
                  ),
                ),
              ),
              const Spacer(),
              // Actions popup
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Edit')),
                  if (booking.status == BookingStatus.scheduled) ...[
                    const PopupMenuItem(
                      value: 'complete',
                      child: Text('Mark Completed'),
                    ),
                    const PopupMenuItem(
                      value: 'cancel',
                      child: Text('Cancel Booking'),
                    ),
                  ],
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Delete',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
                onSelected: (val) {
                  switch (val) {
                    case 'edit':
                      onEdit();
                      break;
                    case 'complete':
                      onStatusChange(BookingStatus.completed);
                      break;
                    case 'cancel':
                      onStatusChange(BookingStatus.cancelled);
                      break;
                    case 'delete':
                      onDelete();
                      break;
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Customer name
          Text(
            booking.customerName,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          // Service
          Row(
            children: [
              const Icon(
                Icons.spa_outlined,
                size: 14,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                booking.serviceName,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          if (booking.staffName != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  booking.staffName!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (booking.customerEmail != null &&
              booking.customerEmail!.isNotEmpty) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.mail_outline_rounded,
                  size: 14,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
                Text(
                  booking.customerEmail!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ],
          if (booking.notes != null && booking.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBEB),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.sticky_note_2_outlined,
                    size: 12,
                    color: Color(0xFFF59E0B),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      booking.notes!,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF92400E),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Booking form bottom sheet ────────────────────────────────────────────────

class BookingFormSheet extends HookConsumerWidget {
  const BookingFormSheet({super.key, required this.date, this.existing});
  final DateTime date;
  final Booking? existing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final formKey = useMemoized(() => GlobalKey<FormState>());
    final nameCtrl = useTextEditingController(
      text: existing?.customerName ?? '',
    );
    final phoneCtrl = useTextEditingController(
      text: existing?.customerPhone ?? '',
    );
    final emailCtrl = useTextEditingController(
      text: existing?.customerEmail ?? '',
    );
    final serviceCtrl = useTextEditingController(
      text: existing?.serviceName ?? '',
    );
    final staffCtrl = useTextEditingController(text: existing?.staffName ?? '');
    final staffId = useState<String?>(existing?.staffId);
    final durationCtrl = useTextEditingController(
      text: (existing?.duration ?? 30).toString(),
    );
    final notesCtrl = useTextEditingController(text: existing?.notes ?? '');
    final selectedTime = useState(_parseTime(existing?.time));
    final selectedDate = useState(existing?.date ?? date);
    final isSubmitting = useState(false);
    final errorText = useState<String?>(null);
    final isOffline = ref.watch(isOfflineProvider);

    final isEditing = existing != null;
    final dateKey = _dateKey(selectedDate.value);
    final canSubmit = !isSubmitting.value && !isOffline;
    final contactFieldsHidden =
        isEditing &&
        !ref.watch(isOwnerProvider) &&
        !ref.watch(salonSettingsProvider).staffCanViewCustomerDetails;

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      isSubmitting.value = true;
      errorText.value = null;
      final req = BookingRequest(
        customerName: nameCtrl.text.trim(),
        customerPhone: phoneCtrl.text.trim(),
        customerEmail: emailCtrl.text.trim().isEmpty
            ? null
            : emailCtrl.text.trim(),
        serviceName: serviceCtrl.text.trim(),
        staffId: staffId.value,
        staffName: staffCtrl.text.trim().isEmpty ? null : staffCtrl.text.trim(),
        duration: int.tryParse(durationCtrl.text.trim()) ?? 30,
        date: selectedDate.value,
        time: _formatTime(selectedTime.value),
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      try {
        final notifier = ref.read(bookingsProvider(dateKey).notifier);
        if (isEditing) {
          await notifier.updateBooking(existing!.id, req);
          // If the edit moved the booking to a different day, that
          // notifier.refresh() above only updated the *new* day's list —
          // the day the booking used to be on (likely still the day the
          // calendar is showing) still has it, stale, until this refreshes
          // too.
          final originalKey = _dateKey(existing!.date);
          if (originalKey != dateKey) {
            await ref.read(bookingsProvider(originalKey).notifier).refresh();
          }
        } else {
          await notifier.create(req);
        }
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          isSubmitting.value = false;
          errorText.value = e is AppException
              ? e.message
              : 'Failed to save booking';
        }
      }
    }

    return PopScope(
      // Block the back gesture/scrim-tap/swipe-to-dismiss specifically
      // while a save is in flight — dismissing mid-submit must not tear
      // down hooks (isSubmitting/errorText) that the pending create/update
      // call above will still try to write to when it resolves.
      canPop: !isSubmitting.value,
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 36,
              height: 4,
              margin: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: AppColors.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                children: [
                  GestureDetector(
                    // Blocked while a save is in flight — closing here would
                    // pop this sheet (and its hooks) out from under the
                    // pending create/update call still running above.
                    onTap: isSubmitting.value
                        ? null
                        : () => Navigator.pop(context),
                    child: Icon(
                      Icons.close,
                      size: 22,
                      color: isSubmitting.value ? AppColors.textTertiary : null,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    isEditing ? 'Edit Booking' : 'New Booking',
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: canSubmit ? submit : null,
                    child: isSubmitting.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            isEditing ? 'Save' : 'Create',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 15,
                              color: isOffline
                                  ? AppColors.textTertiary
                                  : AppColors.textPrimary,
                            ),
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            // Form
            Flexible(
              child: Form(
                key: formKey,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                  shrinkWrap: true,
                  children: [
                    if (isOffline) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceVariant,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "You're offline — reconnect to save this booking.",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                    ] else if (errorText.value != null) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorText.value!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.danger,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    _FormLabel('Customer Name *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: nameCtrl,
                      textCapitalization: TextCapitalization.words,
                      decoration: InputDecoration(
                        hintText: 'e.g. Priya Sharma',
                        suffixIcon: contactFieldsHidden
                            ? null
                            : IconButton(
                                tooltip: 'Search existing customers',
                                icon: const Icon(
                                  Icons.search,
                                  size: 20,
                                  color: AppColors.textSecondary,
                                ),
                                onPressed: () async {
                                  final picked = await _pickCustomer(context);
                                  if (picked == null || !context.mounted) {
                                    return;
                                  }
                                  nameCtrl.text = picked.fullName;
                                  phoneCtrl.text = picked.phone ?? '';
                                  emailCtrl.text = picked.email ?? '';
                                },
                              ),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 16),
                    _FormLabel('Phone Number *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: phoneCtrl,
                      keyboardType: TextInputType.phone,
                      enabled: !contactFieldsHidden,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                        LengthLimitingTextInputFormatter(10),
                      ],
                      decoration: InputDecoration(
                        hintText: contactFieldsHidden
                            ? 'Hidden — ask the owner'
                            : 'e.g. 9800000000',
                      ),
                      validator: (v) => contactFieldsHidden
                          ? null
                          : phoneNumberError(v, required: true),
                    ),
                    const SizedBox(height: 16),
                    _FormLabel('Email (optional — for booking confirmation)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: emailCtrl,
                      keyboardType: TextInputType.emailAddress,
                      enabled: !contactFieldsHidden,
                      decoration: InputDecoration(
                        hintText: contactFieldsHidden
                            ? 'Hidden — ask the owner'
                            : 'e.g. priya@example.com',
                      ),
                      validator: (v) {
                        if (contactFieldsHidden) return null;
                        if (v == null || v.trim().isEmpty) return null;
                        final ok = RegExp(
                          r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                        ).hasMatch(v.trim());
                        return ok ? null : 'Enter a valid email';
                      },
                    ),
                    const SizedBox(height: 16),
                    _FormLabel('Service *'),
                    const SizedBox(height: 6),
                    FormField<String>(
                      initialValue: serviceCtrl.text,
                      validator: (_) =>
                          serviceCtrl.text.trim().isEmpty ? 'Required' : null,
                      builder: (field) => Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          GestureDetector(
                            onTap: () async {
                              final picked = await _pickService(context);
                              if (picked == null || !context.mounted) return;
                              serviceCtrl.text = picked.name;
                              if (picked.duration > 0) {
                                durationCtrl.text = picked.duration.toString();
                              }
                              field.didChange(picked.name);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceVariant,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: field.hasError
                                      ? AppColors.danger
                                      : AppColors.border,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      serviceCtrl.text.isEmpty
                                          ? 'Select a service'
                                          : serviceCtrl.text,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: serviceCtrl.text.isEmpty
                                            ? AppColors.textTertiary
                                            : AppColors.textPrimary,
                                      ),
                                    ),
                                  ),
                                  const Icon(
                                    Icons.unfold_more_rounded,
                                    size: 18,
                                    color: AppColors.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          if (field.hasError) ...[
                            const SizedBox(height: 6),
                            Text(
                              field.errorText!,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FormLabel('Staff'),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await pickStaffMember(
                                    context,
                                    ref,
                                    title: 'Select Staff',
                                  );
                                  if (!context.mounted) return;
                                  staffCtrl.text = picked?.fullName ?? '';
                                  staffId.value = picked?.id;
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 14,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          staffCtrl.text.isEmpty
                                              ? 'Select staff'
                                              : staffCtrl.text,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: staffCtrl.text.isEmpty
                                                ? AppColors.textTertiary
                                                : AppColors.textPrimary,
                                          ),
                                        ),
                                      ),
                                      const Icon(
                                        Icons.unfold_more_rounded,
                                        size: 18,
                                        color: AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FormLabel('Duration (min) *'),
                              const SizedBox(height: 6),
                              TextFormField(
                                controller: durationCtrl,
                                keyboardType: TextInputType.number,
                                decoration: const InputDecoration(
                                  hintText: '30',
                                ),
                                validator: (v) {
                                  final n = int.tryParse((v ?? '').trim());
                                  if (n == null || n < 5) return 'Min 5';
                                  return null;
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Date & Time row
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FormLabel('Date'),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: selectedDate.value,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(
                                      const Duration(days: 90),
                                    ),
                                  );
                                  if (picked != null) {
                                    selectedDate.value = picked;
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.calendar_today,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${selectedDate.value.day}/${selectedDate.value.month}/${selectedDate.value.year}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _FormLabel('Time'),
                              const SizedBox(height: 6),
                              GestureDetector(
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: context,
                                    initialTime: selectedTime.value,
                                  );
                                  if (picked != null) {
                                    selectedTime.value = picked;
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 12,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceVariant,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: AppColors.border),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.access_time,
                                        size: 16,
                                        color: AppColors.textSecondary,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        selectedTime.value.format(context),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _FormLabel('Notes (optional)'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: notesCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        hintText: 'Any special notes…',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Customer picker (searchable) ──────────────────────────────────────────────

Future<CustomerModel?> _pickCustomer(BuildContext context) {
  return showModalBottomSheet<CustomerModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _CustomerPickerSheet(),
  );
}

class _CustomerPickerSheet extends HookConsumerWidget {
  const _CustomerPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final customersAsync = ref.watch(customersProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Select Customer',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: true,
              onChanged: (v) => query.value = v,
              decoration: InputDecoration(
                hintText: 'Search by name or phone…',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          Expanded(
            child: customersAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => const Center(
                child: Text(
                  'Failed to load customers',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ),
              data: (customers) {
                final q = query.value.trim().toLowerCase();
                final filtered = q.isEmpty
                    ? customers
                    : customers
                          .where(
                            (c) =>
                                c.fullName.toLowerCase().contains(q) ||
                                (c.phone ?? '').contains(q),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No customers found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 20,
                    color: AppColors.surfaceVariant,
                  ),
                  itemBuilder: (_, i) {
                    final c = filtered[i];
                    final details = [
                      if (c.phone != null && c.phone!.isNotEmpty) c.phone!,
                      if (c.email != null && c.email!.isNotEmpty) c.email!,
                    ].join(' · ');
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.surfaceVariant,
                        child: Text(
                          c.initials,
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      title: Text(
                        c.fullName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: details.isEmpty
                          ? null
                          : Text(
                              details,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                      onTap: () => Navigator.pop(context, c),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Service picker (searchable) ───────────────────────────────────────────────

Future<ServiceModel?> _pickService(BuildContext context) {
  return showModalBottomSheet<ServiceModel>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const _ServicePickerSheet(),
  );
}

class _ServicePickerSheet extends HookConsumerWidget {
  const _ServicePickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = useState('');
    final servicesAsync = ref.watch(activeServicesProvider);

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                const Text(
                  'Select Service',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              autofocus: true,
              onChanged: (v) => query.value = v,
              decoration: InputDecoration(
                hintText: 'Search services…',
                prefixIcon: const Icon(
                  Icons.search,
                  size: 18,
                  color: AppColors.textTertiary,
                ),
                filled: true,
                fillColor: AppColors.surfaceVariant,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Divider(height: 1, color: AppColors.surfaceVariant),
          Expanded(
            child: servicesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Text(
                  'Failed to load services',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
              ),
              data: (services) {
                final filtered = query.value.isEmpty
                    ? services
                    : services
                          .where(
                            (s) => s.name.toLowerCase().contains(
                              query.value.trim().toLowerCase(),
                            ),
                          )
                          .toList();
                if (filtered.isEmpty) {
                  return const Center(
                    child: Text(
                      'No services found',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: filtered.length,
                  separatorBuilder: (_, _) => const Divider(
                    height: 1,
                    indent: 20,
                    color: AppColors.surfaceVariant,
                  ),
                  itemBuilder: (_, i) {
                    final s = filtered[i];
                    final details = [
                      if (s.duration > 0) s.durationLabel,
                      if (s.price > 0) s.priceLabel,
                    ].join(' · ');
                    return ListTile(
                      title: Text(
                        s.name,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      subtitle: details.isEmpty
                          ? null
                          : Text(
                              details,
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary,
                              ),
                            ),
                      onTap: () => Navigator.pop(context, s),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

TimeOfDay _parseTime(String? time) {
  if (time == null) return const TimeOfDay(hour: 10, minute: 0);
  final parts = time.split(':');
  return TimeOfDay(
    hour: int.tryParse(parts[0]) ?? 10,
    minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
  );
}

String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

class _FormLabel extends StatelessWidget {
  const _FormLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }
}
