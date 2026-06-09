import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:uuid/uuid.dart';

const _uuid = Uuid();

// ─── Booking Model ────────────────────────────────────────────────────────────

enum BookingStatus { scheduled, completed, cancelled }

class Booking {
  final String id;
  final String customerName;
  final String phone;
  final String service;
  final String? staff;
  final DateTime date;
  final TimeOfDay time;
  final String? notes;
  final BookingStatus status;

  const Booking({
    required this.id,
    required this.customerName,
    required this.phone,
    required this.service,
    this.staff,
    required this.date,
    required this.time,
    this.notes,
    this.status = BookingStatus.scheduled,
  });

  Booking copyWith({
    String? customerName,
    String? phone,
    String? service,
    String? staff,
    DateTime? date,
    TimeOfDay? time,
    String? notes,
    BookingStatus? status,
  }) {
    return Booking(
      id: id,
      customerName: customerName ?? this.customerName,
      phone: phone ?? this.phone,
      service: service ?? this.service,
      staff: staff ?? this.staff,
      date: date ?? this.date,
      time: time ?? this.time,
      notes: notes ?? this.notes,
      status: status ?? this.status,
    );
  }

  String get timeLabel {
    final h = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final m = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$h:$m $period';
  }

  String get statusLabel {
    switch (status) {
      case BookingStatus.scheduled:
        return 'Scheduled';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
    }
  }

  Color get statusColor {
    switch (status) {
      case BookingStatus.scheduled:
        return const Color(0xFF6366F1);
      case BookingStatus.completed:
        return const Color(0xFF10B981);
      case BookingStatus.cancelled:
        return const Color(0xFFEF4444);
    }
  }
}

// ─── Bookings Provider ────────────────────────────────────────────────────────

class BookingsNotifier extends StateNotifier<List<Booking>> {
  BookingsNotifier() : super(_mockBookings);

  void add(Booking b) => state = [...state, b];

  void update(Booking updated) {
    state = [
      for (final b in state)
        if (b.id == updated.id) updated else b,
    ];
  }

  void delete(String id) => state = state.where((b) => b.id != id).toList();

  void updateStatus(String id, BookingStatus status) {
    state = [
      for (final b in state)
        if (b.id == id) b.copyWith(status: status) else b,
    ];
  }
}

final bookingsProvider = StateNotifierProvider<BookingsNotifier, List<Booking>>(
  (_) => BookingsNotifier(),
);

// Mock data for today
final _mockBookings = [
  Booking(
    id: _uuid.v4(),
    customerName: 'Priya Sharma',
    phone: '9841123456',
    service: 'Haircut & Blow Dry',
    staff: 'Sita Gurung',
    date: DateTime.now(),
    time: const TimeOfDay(hour: 10, minute: 0),
    status: BookingStatus.completed,
  ),
  Booking(
    id: _uuid.v4(),
    customerName: 'Anita Rai',
    phone: '9812345678',
    service: 'Facial',
    staff: 'Priya Thapa',
    date: DateTime.now(),
    time: const TimeOfDay(hour: 11, minute: 30),
    status: BookingStatus.scheduled,
  ),
  Booking(
    id: _uuid.v4(),
    customerName: 'Maya KC',
    phone: '9801234567',
    service: 'Manicure & Pedicure',
    date: DateTime.now(),
    time: const TimeOfDay(hour: 14, minute: 0),
    notes: 'Prefers gel nails',
    status: BookingStatus.scheduled,
  ),
];

// ─── Calendar Tab ─────────────────────────────────────────────────────────────

class CalendarTab extends HookConsumerWidget {
  const CalendarTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = useState(DateTime.now());
    final bookings = ref.watch(bookingsProvider);

    // Filter bookings for selected date
    final todayBookings =
        bookings.where((b) {
          return b.date.year == selectedDate.value.year &&
              b.date.month == selectedDate.value.month &&
              b.date.day == selectedDate.value.day;
        }).toList()..sort((a, b) {
          final aMin = a.time.hour * 60 + a.time.minute;
          final bMin = b.time.hour * 60 + b.time.minute;
          return aMin.compareTo(bMin);
        });

    return Column(
      children: [
        // ── Date strip ──────────────────────────────────────────────────
        _DateStrip(
          selectedDate: selectedDate.value,
          onDateChanged: (d) => selectedDate.value = d,
        ),
        const Divider(height: 1, color: Color(0xFFF3F4F6)),

        // ── Bookings list or empty state ────────────────────────────────
        Expanded(
          child: todayBookings.isEmpty
              ? _EmptyBookings(
                  onAdd: () =>
                      _showBookingForm(context, ref, selectedDate.value),
                )
              : ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 80),
                  itemCount: todayBookings.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) => _BookingCard(
                    booking: todayBookings[i],
                    onEdit: () => _showBookingForm(
                      context,
                      ref,
                      selectedDate.value,
                      existing: todayBookings[i],
                    ),
                    onDelete: () =>
                        _confirmDelete(context, ref, todayBookings[i]),
                    onStatusChange: (status) {
                      ref
                          .read(bookingsProvider.notifier)
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

  void _confirmDelete(BuildContext context, WidgetRef ref, Booking booking) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Delete Booking', style: TextStyle(fontSize: 16)),
        content: Text(
          'Delete booking for ${booking.customerName}?',
          style: const TextStyle(fontSize: 14, color: Color(0xFF6B7280)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text(
              'Cancel',
              style: TextStyle(color: Color(0xFF6B7280)),
            ),
          ),
          TextButton(
            onPressed: () {
              ref.read(bookingsProvider.notifier).delete(booking.id);
              Navigator.pop(ctx);
            },
            child: const Text(
              'Delete',
              style: TextStyle(
                color: Color(0xFFEF4444),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
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
                      color: const Color(0xFFF3F4F6),
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
                          ? Border.all(color: const Color(0xFFE5E7EB))
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
                                ? const Color(0xFF9CA3AF)
                                : const Color(0xFF6B7280),
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
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(
                Icons.calendar_today_outlined,
                size: 28,
                color: Color(0xFF9CA3AF),
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
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
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

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE5E7EB)),
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
                  color: const Color(0xFFF3F4F6),
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
                  color: booking.statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  booking.statusLabel,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: booking.statusColor,
                  ),
                ),
              ),
              const Spacer(),
              // Actions popup
              PopupMenuButton<String>(
                icon: const Icon(
                  Icons.more_vert,
                  size: 18,
                  color: Color(0xFF6B7280),
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
                      style: TextStyle(color: Color(0xFFEF4444)),
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
                color: Color(0xFF6B7280),
              ),
              const SizedBox(width: 6),
              Text(
                booking.service,
                style: const TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
              ),
            ],
          ),
          if (booking.staff != null) ...[
            const SizedBox(height: 3),
            Row(
              children: [
                const Icon(
                  Icons.person_outline,
                  size: 14,
                  color: Color(0xFF6B7280),
                ),
                const SizedBox(width: 6),
                Text(
                  booking.staff!,
                  style: const TextStyle(
                    fontSize: 13,
                    color: Color(0xFF6B7280),
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
    final phoneCtrl = useTextEditingController(text: existing?.phone ?? '');
    final serviceCtrl = useTextEditingController(text: existing?.service ?? '');
    final staffCtrl = useTextEditingController(text: existing?.staff ?? '');
    final notesCtrl = useTextEditingController(text: existing?.notes ?? '');
    final selectedTime = useState(
      existing?.time ?? const TimeOfDay(hour: 10, minute: 0),
    );
    final selectedDate = useState(existing?.date ?? date);

    final isEditing = existing != null;

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
              color: const Color(0xFFE5E7EB),
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
                  onTap: () {
                    if (!formKey.currentState!.validate()) return;
                    final booking = Booking(
                      id: existing?.id ?? _uuid.v4(),
                      customerName: nameCtrl.text.trim(),
                      phone: phoneCtrl.text.trim(),
                      service: serviceCtrl.text.trim(),
                      staff: staffCtrl.text.trim().isEmpty
                          ? null
                          : staffCtrl.text.trim(),
                      date: selectedDate.value,
                      time: selectedTime.value,
                      notes: notesCtrl.text.trim().isEmpty
                          ? null
                          : notesCtrl.text.trim(),
                      status: existing?.status ?? BookingStatus.scheduled,
                    );
                    if (isEditing) {
                      ref.read(bookingsProvider.notifier).update(booking);
                    } else {
                      ref.read(bookingsProvider.notifier).add(booking);
                    }
                    Navigator.pop(context);
                  },
                  child: Text(
                    isEditing ? 'Save' : 'Create',
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
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
                    decoration: const InputDecoration(
                      hintText: 'e.g. 9841123456',
                    ),
                    validator: (v) {
                      if (v == null || v.trim().isEmpty) return 'Required';
                      if (v.trim().length < 7) return 'Enter a valid number';
                      return null;
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
                  _FormLabel('Staff'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: staffCtrl,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      hintText: 'e.g. Sita Gurung',
                    ),
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
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      size: 16,
                                      color: Color(0xFF6B7280),
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
                                  color: const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFCBD5E1),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.access_time,
                                      size: 16,
                                      color: Color(0xFF6B7280),
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
        color: Color(0xFF6B7280),
      ),
    );
  }
}
