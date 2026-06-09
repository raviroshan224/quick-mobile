import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../features/auth/presentation/providers/auth_provider.dart';

// ─── Settings state ───────────────────────────────────────────────────────────

class SalonSettings {
  final String salonName;
  final String address;
  final String phone;
  final String fonepayId;
  final String receiptFooter;
  final bool autoPrintReceipt;
  final bool requireCustomer;
  final bool lowStockAlerts;
  final bool dailySummary;
  final String currency;

  const SalonSettings({
    this.salonName = 'My Salon',
    this.address = 'Kathmandu, Nepal',
    this.phone = '+977-9800000000',
    this.fonepayId = '',
    this.receiptFooter = 'Thank you for visiting!',
    this.autoPrintReceipt = false,
    this.requireCustomer = false,
    this.lowStockAlerts = true,
    this.dailySummary = false,
    this.currency = 'NPR',
  });

  SalonSettings copyWith({
    String? salonName,
    String? address,
    String? phone,
    String? fonepayId,
    String? receiptFooter,
    bool? autoPrintReceipt,
    bool? requireCustomer,
    bool? lowStockAlerts,
    bool? dailySummary,
    String? currency,
  }) => SalonSettings(
    salonName: salonName ?? this.salonName,
    address: address ?? this.address,
    phone: phone ?? this.phone,
    fonepayId: fonepayId ?? this.fonepayId,
    receiptFooter: receiptFooter ?? this.receiptFooter,
    autoPrintReceipt: autoPrintReceipt ?? this.autoPrintReceipt,
    requireCustomer: requireCustomer ?? this.requireCustomer,
    lowStockAlerts: lowStockAlerts ?? this.lowStockAlerts,
    dailySummary: dailySummary ?? this.dailySummary,
    currency: currency ?? this.currency,
  );
}

class _SettingsNotifier extends StateNotifier<SalonSettings> {
  _SettingsNotifier() : super(const SalonSettings());
  void update(SalonSettings s) => state = s;
}

final salonSettingsProvider =
    StateNotifierProvider<_SettingsNotifier, SalonSettings>(
  (_) => _SettingsNotifier(),
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    final settings = ref.watch(salonSettingsProvider);
    final notifier = ref.read(salonSettingsProvider.notifier);

    void edit(String title, String current, void Function(String) onSave,
        {TextInputType keyboard = TextInputType.text}) {
      final ctrl = TextEditingController(text: current);
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          title: Text(title,
              style: const TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w600)),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: keyboard,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF9FAFB),
              border: OutlineInputBorder(
                borderSide: BorderSide.none,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel',
                  style: TextStyle(color: Color(0xFF6B7280))),
            ),
            TextButton(
              onPressed: () {
                onSave(ctrl.text.trim());
                Navigator.pop(ctx);
              },
              child: const Text('Save',
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: Colors.black)),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go(AppRoutes.more),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.black),
              ),
              const Spacer(),
              const Text('Settings',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              const SizedBox(width: 18),
            ]),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
              children: [
                // ── Profile card ───────────────────────────────────────────
                _ProfileCard(user: user),
                const SizedBox(height: 20),

                // ── Business ───────────────────────────────────────────────
                _Section(title: 'Business', tiles: [
                  _EditTile(
                    icon: Icons.store_outlined,
                    label: 'Salon Name',
                    value: settings.salonName,
                    onTap: () => edit('Salon Name', settings.salonName,
                        (v) => notifier.update(settings.copyWith(salonName: v))),
                  ),
                  _EditTile(
                    icon: Icons.location_on_outlined,
                    label: 'Address',
                    value: settings.address,
                    onTap: () => edit('Address', settings.address,
                        (v) => notifier.update(settings.copyWith(address: v))),
                  ),
                  _EditTile(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: settings.phone,
                    onTap: () => edit('Phone', settings.phone,
                        (v) => notifier.update(settings.copyWith(phone: v)),
                        keyboard: TextInputType.phone),
                  ),
                  _EditTile(
                    icon: Icons.language_outlined,
                    label: 'Currency',
                    value: settings.currency,
                    onTap: () => edit('Currency', settings.currency,
                        (v) => notifier.update(settings.copyWith(currency: v))),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Payment ────────────────────────────────────────────────
                _Section(title: 'Payment', tiles: [
                  _EditTile(
                    icon: Icons.qr_code_rounded,
                    label: 'Fonepay Merchant ID',
                    value: settings.fonepayId.isEmpty
                        ? 'Not configured'
                        : settings.fonepayId,
                    valueColor: settings.fonepayId.isEmpty
                        ? const Color(0xFFDC2626)
                        : null,
                    onTap: () => edit(
                      'Fonepay Merchant ID',
                      settings.fonepayId,
                      (v) => notifier.update(settings.copyWith(fonepayId: v)),
                      keyboard: TextInputType.number,
                    ),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Receipt ────────────────────────────────────────────────
                _Section(title: 'Receipt', tiles: [
                  _ToggleTile(
                    icon: Icons.print_outlined,
                    label: 'Auto-print Receipt',
                    subtitle: 'Print receipt after every completed sale',
                    value: settings.autoPrintReceipt,
                    onChanged: (v) => notifier
                        .update(settings.copyWith(autoPrintReceipt: v)),
                  ),
                  _EditTile(
                    icon: Icons.notes_rounded,
                    label: 'Receipt Footer',
                    value: settings.receiptFooter,
                    onTap: () => edit('Receipt Footer', settings.receiptFooter,
                        (v) =>
                            notifier.update(settings.copyWith(receiptFooter: v))),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Checkout ───────────────────────────────────────────────
                _Section(title: 'Checkout', tiles: [
                  _ToggleTile(
                    icon: Icons.person_search_outlined,
                    label: 'Require Customer',
                    subtitle: 'Prompt to add customer before every sale',
                    value: settings.requireCustomer,
                    onChanged: (v) => notifier
                        .update(settings.copyWith(requireCustomer: v)),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Notifications ──────────────────────────────────────────
                _Section(title: 'Notifications', tiles: [
                  _ToggleTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Low Stock Alerts',
                    subtitle: 'Alert when item stock falls below threshold',
                    value: settings.lowStockAlerts,
                    onChanged: (v) =>
                        notifier.update(settings.copyWith(lowStockAlerts: v)),
                  ),
                  _ToggleTile(
                    icon: Icons.bar_chart_rounded,
                    label: 'Daily Summary',
                    subtitle: "Get today's sales summary at end of day",
                    value: settings.dailySummary,
                    onChanged: (v) =>
                        notifier.update(settings.copyWith(dailySummary: v)),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── Support ────────────────────────────────────────────────
                _Section(title: 'Help', tiles: [
                  _NavTile(
                    icon: Icons.help_outline_rounded,
                    label: 'Support & FAQ',
                    onTap: () => context.go(AppRoutes.moreSupport),
                  ),
                ]),
                const SizedBox(height: 16),

                // ── App info ───────────────────────────────────────────────
                _Section(title: 'App', tiles: [
                  _InfoTile(
                      icon: Icons.info_outline_rounded,
                      label: 'Version',
                      value: '1.0.0 (build 1)'),
                  _InfoTile(
                      icon: Icons.business_outlined,
                      label: 'Built for',
                      value: 'Nepal Salon POS'),
                ]),
                const SizedBox(height: 20),

                // ── Sign out ───────────────────────────────────────────────
                _DangerTile(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  onTap: () => _confirmSignOut(context, ref),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  void _confirmSignOut(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        title: const Text('Sign out?',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
        content: const Text('You will be returned to the login screen.',
            style: TextStyle(fontSize: 14, color: Color(0xFF6B7280))),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF6B7280))),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(authProvider.notifier).logout();
            },
            child: const Text('Sign Out',
                style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

// ─── Profile card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user});
  final dynamic user;

  @override
  Widget build(BuildContext context) {
    if (user == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: Colors.black,
          child: Text(user.initials,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(user.fullName,
                style: const TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(user.email,
                style: const TextStyle(
                    fontSize: 13, color: Color(0xFF6B7280))),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: user.isOwner
                ? const Color(0xFFF3E8FF)
                : const Color(0xFFE0F2FE),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            user.isOwner ? 'Owner' : 'Staff',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: user.isOwner
                  ? const Color(0xFF7C3AED)
                  : const Color(0xFF0369A1),
            ),
          ),
        ),
      ]),
    );
  }
}

// ─── Section wrapper ──────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.tiles});
  final String title;
  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(title.toUpperCase(),
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B7280),
                    letterSpacing: 0.8)),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              children: tiles.asMap().entries.map((e) => Column(children: [
                    e.value,
                    if (e.key < tiles.length - 1)
                      const Divider(
                          height: 1,
                          indent: 50,
                          color: Color(0xFFF3F4F6)),
                  ])).toList(),
            ),
          ),
        ],
      );
}

// ─── Tile variants ────────────────────────────────────────────────────────────

class _EditTile extends StatelessWidget {
  const _EditTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
    this.valueColor,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: const Color(0xFF6B7280)),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 15))),
            Text(value,
                style: TextStyle(
                    fontSize: 14,
                    color: valueColor ?? const Color(0xFF9CA3AF))),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right,
                size: 16, color: Color(0xFFD1D5DB)),
          ]),
        ),
      );
}

class _ToggleTile extends StatelessWidget {
  const _ToggleTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(children: [
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 15)),
              const SizedBox(height: 1),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: Color(0xFF9CA3AF))),
            ]),
          ),
          Switch.adaptive(
            value: value,
            onChanged: onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: Colors.black,
          ),
        ]),
      );
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(children: [
          Icon(icon, size: 20, color: const Color(0xFF6B7280)),
          const SizedBox(width: 14),
          Expanded(
              child: Text(label,
                  style: const TextStyle(fontSize: 15))),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, color: Color(0xFF9CA3AF))),
        ]),
      );
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(children: [
            Icon(icon, size: 20, color: const Color(0xFF6B7280)),
            const SizedBox(width: 14),
            Expanded(
                child: Text(label,
                    style: const TextStyle(fontSize: 15))),
            const Icon(Icons.chevron_right,
                size: 16, color: Color(0xFFD1D5DB)),
          ]),
        ),
      );
}

class _DangerTile extends StatelessWidget {
  const _DangerTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Row(children: [
            Icon(icon, size: 20, color: const Color(0xFFDC2626)),
            const SizedBox(width: 14),
            Text(label,
                style: const TextStyle(
                    fontSize: 15,
                    color: Color(0xFFDC2626),
                    fontWeight: FontWeight.w500)),
          ]),
        ),
      );
}
