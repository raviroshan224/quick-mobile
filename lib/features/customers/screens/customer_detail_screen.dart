import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../models/customer_model.dart';
import '../providers/customers_provider.dart';
import 'customers_screen.dart' show CustomerAvatar;

class CustomerDetailScreen extends ConsumerStatefulWidget {
  final String customerId;
  const CustomerDetailScreen({super.key, required this.customerId});

  @override
  ConsumerState<CustomerDetailScreen> createState() =>
      _CustomerDetailScreenState();
}

class _CustomerDetailScreenState
    extends ConsumerState<CustomerDetailScreen> {
  bool _editingNotes = false;
  late TextEditingController _notesCtrl;

  @override
  void initState() {
    super.initState();
    _notesCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _notesCtrl.dispose();
    super.dispose();
  }

  void _saveNotes() {
    ref
        .read(customersProvider.notifier)
        .updateNotes(widget.customerId, _notesCtrl.text);
    setState(() => _editingNotes = false);
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final customer = ref
        .watch(customersProvider)
        .where((c) => c.id == widget.customerId)
        .firstOrNull;

    if (customer == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Customer not found')),
      );
    }

    final visits =
        mockVisitHistory[widget.customerId] ?? [];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(customer.name),
        actions: [
          TextButton(
            onPressed: () =>
                context.push('/customers/${widget.customerId}/edit'),
            child: const Text('Edit',
                style: TextStyle(
                    color: AppColors.accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 40),
        children: [
          // ── Profile header ──────────────────────────────────────────────
          _ProfileHeader(customer: customer),

          // ── Stats row ───────────────────────────────────────────────────
          _StatsRow(customer: customer),

          // ── Contact ─────────────────────────────────────────────────────
          const _SectionLabel(label: 'Contact'),
          _InfoCard(children: [
            _InfoRow(
              icon: Icons.phone_outlined,
              label: customer.phone,
              onTap: () {},
            ),
            if (customer.birthday != null) ...[
              const Divider(height: 1, indent: 44),
              _InfoRow(
                icon: Icons.cake_outlined,
                label: _formatBirthday(customer.birthday!),
              ),
            ],
          ]),

          // ── Notes ────────────────────────────────────────────────────────
          _SectionLabel(
            label: 'Notes',
            action: _editingNotes
                ? TextButton(
                    onPressed: _saveNotes,
                    child: const Text('Save',
                        style: TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w600)))
                : TextButton(
                    onPressed: () {
                      _notesCtrl.text = customer.notes ?? '';
                      setState(() => _editingNotes = true);
                    },
                    child: Text(
                        customer.notes == null ? 'Add' : 'Edit',
                        style: const TextStyle(
                            color: AppColors.accent,
                            fontWeight: FontWeight.w500))),
          ),
          _NotesCard(
            notes: customer.notes,
            isEditing: _editingNotes,
            controller: _notesCtrl,
            onStartEdit: () {
              _notesCtrl.text = customer.notes ?? '';
              setState(() => _editingNotes = true);
            },
          ),

          // ── Visit history ─────────────────────────────────────────────
          _SectionLabel(
            label: 'Visit History',
            count: visits.length,
          ),
          if (visits.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: AppColors.divider),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Center(
                  child: Text('No visits recorded yet',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary)),
                ),
              ),
            )
          else
            _VisitHistoryCard(visits: visits),
        ],
      ),
    );
  }

  String _formatBirthday(DateTime d) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    return '${months[d.month - 1]} ${d.day}';
  }
}

// ── Profile header ─────────────────────────────────────────────────────────

class _ProfileHeader extends StatelessWidget {
  final Customer customer;
  const _ProfileHeader({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      color: Colors.white,
      child: Column(
        children: [
          CustomerAvatar(name: customer.name, size: 72),
          const SizedBox(height: 12),
          Text(customer.name,
              style: const TextStyle(
                  fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(customer.phone,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Stats row ─────────────────────────────────────────────────────────────────

class _StatsRow extends StatelessWidget {
  final Customer customer;
  const _StatsRow({required this.customer});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Row(
        children: [
          _StatCard(
            value: customer.visitCount.toString(),
            label: 'Visits',
            icon: Icons.event_available_outlined,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: 'Rs ${_compact(customer.totalSpend)}',
            label: 'Total Spend',
            icon: Icons.payments_outlined,
          ),
          const SizedBox(width: 10),
          _StatCard(
            value: customer.lastVisitLabel,
            label: 'Last Visit',
            icon: Icons.schedule_outlined,
          ),
        ],
      ),
    );
  }

  String _compact(double v) {
    if (v >= 100000) return '${(v / 100000).toStringAsFixed(1)}L';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    return v.toStringAsFixed(0);
  }
}

class _StatCard extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;

  const _StatCard(
      {required this.value, required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(height: 6),
            Text(value,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(label,
                style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }
}

// ── Notes card ────────────────────────────────────────────────────────────────

class _NotesCard extends StatelessWidget {
  final String? notes;
  final bool isEditing;
  final TextEditingController controller;
  final VoidCallback onStartEdit;

  const _NotesCard({
    required this.notes,
    required this.isEditing,
    required this.controller,
    required this.onStartEdit,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: isEditing
            ? TextField(
                controller: controller,
                autofocus: true,
                maxLines: 5,
                minLines: 3,
                decoration: const InputDecoration(
                  hintText:
                      'Allergies, preferences, colour formulas…',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  fillColor: Colors.transparent,
                ),
                style: const TextStyle(fontSize: 14),
              )
            : notes != null && notes!.isNotEmpty
                ? GestureDetector(
                    onTap: onStartEdit,
                    child: Text(notes!,
                        style: const TextStyle(
                            fontSize: 14, height: 1.5)),
                  )
                : GestureDetector(
                    onTap: onStartEdit,
                    child: const Text(
                      'Tap to add notes — allergies, preferences, colour formulas…',
                      style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textTertiary),
                    ),
                  ),
      ),
    );
  }
}

// ── Visit history card ────────────────────────────────────────────────────────

class _VisitHistoryCard extends StatelessWidget {
  final List<VisitRecord> visits;
  const _VisitHistoryCard({required this.visits});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            for (int i = 0; i < visits.length; i++) ...[
              if (i > 0) const Divider(height: 1, indent: 16),
              _VisitTile(visit: visits[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _VisitTile extends StatelessWidget {
  final VisitRecord visit;
  const _VisitTile({required this.visit});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Center(
              child: Icon(Icons.receipt_long_outlined,
                  size: 18, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  visit.services.join(', '),
                  style: const TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 2),
                Text(visit.dateLabel,
                    style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary)),
              ],
            ),
          ),
          Text(
            'Rs ${visit.total.toStringAsFixed(0)}',
            style: const TextStyle(
                fontSize: 14, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String label;
  final int? count;
  final Widget? action;

  const _SectionLabel({required this.label, this.count, this.action});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
      child: Row(
        children: [
          Text(
            count != null ? '${label.toUpperCase()}  $count' : label.toUpperCase(),
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.8,
                color: AppColors.textSecondary),
          ),
          const Spacer(),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: AppColors.divider),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _InfoRow({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.textSecondary),
            const SizedBox(width: 12),
            Text(label,
                style: TextStyle(
                    fontSize: 15,
                    color: onTap != null
                        ? AppColors.accent
                        : AppColors.textPrimary)),
          ],
        ),
      ),
    );
  }
}
