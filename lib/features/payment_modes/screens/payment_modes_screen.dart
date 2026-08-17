import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../models/payment_mode_model.dart';
import '../providers/payment_modes_provider.dart';
import '../../../shared/widgets/pull_to_refresh.dart';

class PaymentModesScreen extends ConsumerWidget {
  const PaymentModesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final modesAsync = ref.watch(allPaymentModesProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded,
              size: 18, color: Colors.black),
          onPressed: () => context.go(AppRoutes.moreSettings),
        ),
        title: const Text('Payment Modes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600, color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.add, color: Colors.black),
            onPressed: () => context.push(AppRoutes.morePaymentModesNew),
          ),
        ],
      ),
      body: PullToRefresh(
        onRefresh: () => ref.refresh(allPaymentModesProvider.future),
        child: modesAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (modes) {
            final active = modes.where((m) => m.isActive).toList();
            final inactive = modes.where((m) => !m.isActive).toList();
            return modes.isEmpty
                ? _EmptyState(onAdd: () => context.push(AppRoutes.morePaymentModesNew))
                : ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      const Padding(
                        padding: EdgeInsets.fromLTRB(16, 20, 16, 8),
                        child: Text(
                          'Each mode shows the QR you upload at checkout — Quick never '
                          'processes the payment itself. The cashier confirms once the '
                          'customer has paid, the same way Cash works.',
                          style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                        ),
                      ),
                      if (active.isNotEmpty) ...[
                        _SectionHeader(label: 'Active', count: active.length),
                        ...active.map(
                          (m) => _ModeRow(
                            mode: m,
                            onTap: () => context.push(AppRoutes.morePaymentModeEdit(m.id)),
                          ),
                        ),
                      ],
                      if (inactive.isNotEmpty) ...[
                        _SectionHeader(label: 'Inactive', count: inactive.length),
                        ...inactive.map(
                          (m) => _ModeRow(
                            mode: m,
                            onTap: () => context.push(AppRoutes.morePaymentModeEdit(m.id)),
                          ),
                        ),
                      ],
                    ],
                  );
          },
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String label;
  final int count;
  const _SectionHeader({required this.label, required this.count});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
      child: Text(
        '${label.toUpperCase()}  $count',
        style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: AppColors.textSecondary),
      ),
    );
  }
}

class _ModeRow extends StatelessWidget {
  final PaymentMode mode;
  final VoidCallback onTap;
  const _ModeRow({required this.mode, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  mode.qrImageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Icon(
                    Icons.qr_code_rounded,
                    size: 20,
                    color: mode.isActive ? AppColors.textPrimary : AppColors.textTertiary,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                mode.name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: mode.isActive ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              ),
            ),
            if (!mode.isActive)
              const Padding(
                padding: EdgeInsets.only(right: 4),
                child: Text('Hidden',
                    style: TextStyle(fontSize: 12, color: AppColors.textTertiary)),
              ),
            const Icon(Icons.chevron_right, size: 18, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

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
                  color: AppColors.surface, borderRadius: BorderRadius.circular(16)),
              child: const Icon(Icons.qr_code_2_rounded, size: 32, color: AppColors.textTertiary),
            ),
            const SizedBox(height: 16),
            const Text('No payment modes yet',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            const Text(
              'Add eSewa, Fonepay, or any other QR-based\npayment method your customers can pay with.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onAdd,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add Payment Mode',
                  style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
