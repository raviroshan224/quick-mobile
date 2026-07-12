import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/models/app_exception.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/network_status.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';
import '../../../more/presentation/screens/settings_screen.dart' show salonSettingsProvider;
import '../../data/bookings_repository.dart';
import '../../domain/booking_models.dart';

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
  }) =>
      BookingsState(
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
  (ref, dateKey) => BookingsNotifier(ref.read(_bookingsRepoProvider), dateKey),
);

// ─── Calendar Tab ─────────────────────────────────────────────────────────────

class CalendarTab extends HookConsumerWidget {
  const CalendarTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = useState(DateTime.now());
    final dateKey = _dateKey(selectedDate.value);
    final bookingsState = ref.watch(bookingsProvider(dateKey));

    final todayBookings = [...bookingsState.items]..sort((a, b) {
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
                          onAdd: () =>
                              _showBookingForm(context, ref, selectedDate.value),
                        )
                      : ListView.separated(
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
                            onDelete: () =>
                                _confirmDelete(context, ref, dateKey, todayBookings[i]),
                            onStatusChange: (status) {
                              ref
                                  .read(bookingsProvider(dateKey).notifier)
                                  .updateStatus(todayBookings[i].id, status);
                            },
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
            const Icon(Icons.wifi_off_rounded, size: 40, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            const Text('Failed to load bookings',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.textTertiary)),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: onRetry,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
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
  const _EmptyBookings({required this.onAdd});
  final VoidCallback onAdd;

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
            const Text(
              'No bookings scheduled for this date.\nTap below to create one.',
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
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
          if (booking.customerEmail != null && booking.customerEmail!.isNotEmpty) ...[
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
    final phoneCtrl =
        useTextEditingController(text: existing?.customerPhone ?? '');
    final emailCtrl =
        useTextEditingController(text: existing?.customerEmail ?? '');
    final serviceCtrl =
        useTextEditingController(text: existing?.serviceName ?? '');
    final staffCtrl = useTextEditingController(text: existing?.staffName ?? '');
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
    final contactFieldsHidden = isEditing &&
        !ref.watch(isOwnerProvider) &&
        !ref.watch(salonSettingsProvider).staffCanViewCustomerDetails;

    Future<void> submit() async {
      if (!formKey.currentState!.validate()) return;
      isSubmitting.value = true;
      errorText.value = null;
      final req = BookingRequest(
        customerName: nameCtrl.text.trim(),
        customerPhone: phoneCtrl.text.trim(),
        customerEmail:
            emailCtrl.text.trim().isEmpty ? null : emailCtrl.text.trim(),
        serviceName: serviceCtrl.text.trim(),
        staffName:
            staffCtrl.text.trim().isEmpty ? null : staffCtrl.text.trim(),
        duration: int.tryParse(durationCtrl.text.trim()) ?? 30,
        date: selectedDate.value,
        time: _formatTime(selectedTime.value),
        notes: notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
      );
      try {
        final notifier = ref.read(bookingsProvider(dateKey).notifier);
        if (isEditing) {
          await notifier.updateBooking(existing!.id, req);
        } else {
          await notifier.create(req);
        }
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        isSubmitting.value = false;
        errorText.value = e is AppException ? e.message : 'Failed to save booking';
      }
    }

    return Container(
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
                  onTap: () => Navigator.pop(context),
                  child: const Icon(Icons.close, size: 22),
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                shrinkWrap: true,
                children: [
                  if (isOffline) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceVariant,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.wifi_off_rounded,
                              size: 16, color: AppColors.textSecondary),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "You're offline — reconnect to save this booking.",
                              style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ] else if (errorText.value != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.dangerLight,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        errorText.value!,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.danger),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                  _FormLabel('Customer Name *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: nameCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Priya Sharma',
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
                    decoration: InputDecoration(
                      hintText: contactFieldsHidden
                          ? 'Hidden — ask the owner'
                          : 'e.g. 9841123456',
                    ),
                    validator: (v) {
                      if (contactFieldsHidden) return null;
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 7) return 'Enter a valid number';
                      return null;
                    },
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
                      final ok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                          .hasMatch(v.trim());
                      return ok ? null : 'Enter a valid email';
                    },
                  ),
                  const SizedBox(height: 16),
                  _FormLabel('Service *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: serviceCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Haircut & Blow Dry',
                    ),
                    validator: (v) =>
                        (v == null || v.trim().isEmpty) ? 'Required' : null,
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
                            TextFormField(
                              controller: staffCtrl,
                              textCapitalization: TextCapitalization.words,
                              decoration: const InputDecoration(
                                hintText: 'e.g. Sita Gurung',
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
                                  border: Border.all(
                                    color: AppColors.border,
                                  ),
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
                                  border: Border.all(
                                    color: AppColors.border,
                                  ),
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
