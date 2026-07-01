import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/profile_model.dart';
import '../providers/auth_provider.dart';
import '../../data/auth_repository.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/storage/secure_storage_service.dart';

class ProfilePickerScreen extends ConsumerWidget {
  const ProfilePickerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final profiles = authState.profiles ?? [];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────────────────────────────────
            const SizedBox(height: 48),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.point_of_sale_rounded,
                      size: 20, color: Colors.black),
                ),
                const SizedBox(width: 10),
                const Text(
                  'Quick POS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.3,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            const Text(
              "Who's working today?",
              style: TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Select your profile to continue',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 36),

            // ── Profile Grid ─────────────────────────────────────────────────
            Expanded(
              child: profiles.isEmpty
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.white54),
                    )
                  : GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 14,
                        mainAxisSpacing: 14,
                        childAspectRatio: 0.88,
                      ),
                      itemCount: profiles.length,
                      itemBuilder: (context, i) => _ProfileCard(
                        profile: profiles[i],
                        onTap: () => _handleTap(context, ref, profiles[i]),
                      ),
                    ),
            ),

            // ── Sign out ─────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              child: GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Sign out'),
                      content: const Text(
                          'This will remove the owner session from this device. You will need to log in again.'),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Cancel')),
                        TextButton(
                          onPressed: () {
                            Navigator.pop(ctx);
                            ref.read(authProvider.notifier).logout();
                          },
                          child: const Text('Sign out',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                    ),
                  );
                },
                child: Text(
                  'Sign out of this device',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.35),
                    fontSize: 14,
                    decoration: TextDecoration.underline,
                    decorationColor: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleTap(BuildContext context, WidgetRef ref, ProfileModel profile) {
    if (!profile.hasPin && profile.isOwner) {
      // Owner hasn't set a PIN yet — offer to create one.
      _showCreatePinSheet(context, ref, profile);
    } else if (!profile.hasPin) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content:
              Text('No PIN configured. Ask the owner to set a PIN for you.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      _showPinSheet(context, ref, profile);
    }
  }

  void _showPinSheet(BuildContext context, WidgetRef ref, ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _PinSheet(profile: profile, ref: ref),
    );
  }

  void _showCreatePinSheet(
      BuildContext context, WidgetRef ref, ProfileModel profile) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _CreatePinSheet(profile: profile, ref: ref),
    );
  }
}

// ─── Profile Card ─────────────────────────────────────────────────────────────

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.profile, required this.onTap});
  final ProfileModel profile;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: profile.isOwner
                ? const Color(0xFFD4AF37).withValues(alpha: 0.4)
                : Colors.white.withValues(alpha: 0.08),
            width: profile.isOwner ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Avatar
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: profile.isOwner
                    ? const Color(0xFF2A2000)
                    : const Color(0xFF1E2A3A),
                border: Border.all(
                  color: profile.isOwner
                      ? const Color(0xFFD4AF37).withValues(alpha: 0.5)
                      : Colors.white.withValues(alpha: 0.12),
                  width: 2,
                ),
                image: profile.photoUrl != null
                    ? DecorationImage(
                        image: NetworkImage(profile.photoUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: profile.photoUrl == null
                  ? Center(
                      child: Text(
                        profile.initials,
                        style: TextStyle(
                          color: profile.isOwner
                              ? const Color(0xFFD4AF37)
                              : Colors.white70,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  : null,
            ),
            const SizedBox(height: 12),
            // Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                profile.firstName,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 4),
            // Role badge
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: profile.isOwner
                    ? const Color(0xFFD4AF37).withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.07),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                profile.isOwner ? 'Owner' : 'Staff',
                style: TextStyle(
                  color: profile.isOwner
                      ? const Color(0xFFD4AF37)
                      : Colors.white54,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (!profile.hasPin) ...[
              const SizedBox(height: 6),
              Text(
                'No PIN',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.3),
                  fontSize: 10,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── PIN Entry Sheet ──────────────────────────────────────────────────────────

class _PinSheet extends HookConsumerWidget {
  const _PinSheet({required this.profile, required this.ref});
  final ProfileModel profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final pin = useState('');
    final error = useState<String?>(null);
    final loading = useState(false);
    final shakeKey = useState(0);

    Future<void> submit(String currentPin) async {
      if (currentPin.length < 4) return;
      loading.value = true;
      error.value = null;

      // Attempt login
      await widgetRef.read(authProvider.notifier).pinLogin(profile.id, currentPin);

      if (!context.mounted) return;
      final authState = widgetRef.read(authProvider);

      if (authState.status == AuthStatus.authenticated) {
        Navigator.of(context).pop();
      } else {
        // Wrong PIN
        loading.value = false;
        pin.value = '';
        error.value = 'Incorrect PIN. Try again.';
        shakeKey.value++;
        HapticFeedback.heavyImpact();
      }
    }

    void onDigit(String digit) {
      if (pin.value.length >= 4 || loading.value) return;
      final next = pin.value + digit;
      pin.value = next;
      error.value = null;
      if (next.length == 4) submit(next);
    }

    void onBackspace() {
      if (pin.value.isEmpty || loading.value) return;
      pin.value = pin.value.substring(0, pin.value.length - 1);
      error.value = null;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: profile.isOwner
                  ? const Color(0xFF2A2000)
                  : const Color(0xFF1E2A3A),
              image: profile.photoUrl != null
                  ? DecorationImage(
                      image: NetworkImage(profile.photoUrl!),
                      fit: BoxFit.cover)
                  : null,
            ),
            child: profile.photoUrl == null
                ? Center(
                    child: Text(
                      profile.initials,
                      style: TextStyle(
                        color: profile.isOwner
                            ? const Color(0xFFD4AF37)
                            : Colors.white70,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          Text(
            profile.firstName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Enter your PIN',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 28),

          // PIN dots with shake animation
          _PinDots(
            filled: pin.value.length,
            hasError: error.value != null,
            shakeKey: shakeKey.value,
          ),

          if (error.value != null) ...[
            const SizedBox(height: 10),
            Text(
              error.value!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
            ),
          ],
          const SizedBox(height: 28),

          // Numpad
          _Numpad(
            onDigit: onDigit,
            onBackspace: onBackspace,
            loading: loading.value,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Create PIN Sheet (owner first-time setup) ───────────────────────────────

class _CreatePinSheet extends HookConsumerWidget {
  const _CreatePinSheet({required this.profile, required this.ref});
  final ProfileModel profile;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context, WidgetRef widgetRef) {
    final step = useState(0); // 0 = enter, 1 = confirm
    final firstPin = useState('');
    final pin = useState('');
    final error = useState<String?>(null);
    final loading = useState(false);

    Future<void> savePin(String confirmedPin) async {
      loading.value = true;
      try {
        final repo = AuthRepository(
          widgetRef.read(apiClientProvider),
          widgetRef.read(secureStorageProvider),
        );
        await repo.setOwnerPin(confirmedPin);

        // Refresh profiles so the card shows "has PIN" now
        await widgetRef.read(authProvider.notifier).refreshProfiles();

        if (!context.mounted) return;
        Navigator.of(context).pop();

        // Now show the regular PIN sheet
        await Future.delayed(const Duration(milliseconds: 300));
        if (!context.mounted) return;
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => _PinSheet(profile: profile, ref: widgetRef),
        );
      } catch (e) {
        loading.value = false;
        error.value = e.toString();
      }
    }

    void onDigit(String digit) {
      if (pin.value.length >= 4 || loading.value) return;
      final next = pin.value + digit;
      pin.value = next;
      error.value = null;

      if (next.length == 4) {
        if (step.value == 0) {
          firstPin.value = next;
          pin.value = '';
          step.value = 1;
        } else {
          if (next == firstPin.value) {
            savePin(next);
          } else {
            pin.value = '';
            firstPin.value = '';
            step.value = 0;
            error.value = "PINs don't match. Try again.";
            HapticFeedback.heavyImpact();
          }
        }
      }
    }

    void onBackspace() {
      if (pin.value.isEmpty || loading.value) return;
      pin.value = pin.value.substring(0, pin.value.length - 1);
      error.value = null;
    }

    return Container(
      decoration: const BoxDecoration(
        color: Color(0xFF111111),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        top: 16,
        left: 24,
        right: 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          const Icon(Icons.lock_outline_rounded, color: Color(0xFFD4AF37), size: 36),
          const SizedBox(height: 12),
          Text(
            step.value == 0 ? 'Create your PIN' : 'Confirm your PIN',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            step.value == 0
                ? 'Choose a 4-digit PIN to sign in quickly'
                : 'Enter the same PIN again',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.45),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          _PinDots(
            filled: pin.value.length,
            hasError: error.value != null,
            shakeKey: 0,
          ),
          if (error.value != null) ...[
            const SizedBox(height: 10),
            Text(
              error.value!,
              style: const TextStyle(color: AppColors.danger, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 28),
          _Numpad(
            onDigit: onDigit,
            onBackspace: onBackspace,
            loading: loading.value,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── PIN Dots ─────────────────────────────────────────────────────────────────

class _PinDots extends StatelessWidget {
  const _PinDots({
    required this.filled,
    required this.hasError,
    required this.shakeKey,
  });
  final int filled;
  final bool hasError;
  final int shakeKey;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      key: ValueKey(shakeKey),
      tween: shakeKey == 0
          ? Tween(begin: 0.0, end: 0.0)
          : Tween(begin: -8.0, end: 0.0),
      duration: const Duration(milliseconds: 300),
      curve: Curves.elasticOut,
      builder: (_, value, child) => Transform.translate(
        offset: Offset(value * (shakeKey % 2 == 0 ? 1 : -1), 0),
        child: child,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          4,
          (i) => Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? (hasError ? AppColors.danger : Colors.white)
                  : Colors.transparent,
              border: Border.all(
                color: i < filled
                    ? (hasError ? AppColors.danger : Colors.white)
                    : Colors.white.withValues(alpha: 0.25),
                width: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Numpad ───────────────────────────────────────────────────────────────────

class _Numpad extends StatelessWidget {
  const _Numpad({
    required this.onDigit,
    required this.onBackspace,
    required this.loading,
  });
  final void Function(String) onDigit;
  final VoidCallback onBackspace;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    const digits = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];

    return Column(
      children: [
        for (final row in digits)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: row
                  .map((d) => _NumKey(
                        label: d,
                        onTap: () => onDigit(d),
                        enabled: !loading,
                      ))
                  .toList(),
            ),
          ),
        // Bottom row: empty | 0 | backspace
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(width: 80),
            _NumKey(label: '0', onTap: () => onDigit('0'), enabled: !loading),
            SizedBox(
              width: 80,
              height: 64,
              child: loading
                  ? const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white54,
                          strokeWidth: 2,
                        ),
                      ),
                    )
                  : TextButton(
                      onPressed: onBackspace,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.white,
                        shape: const CircleBorder(),
                      ),
                      child: const Icon(Icons.backspace_outlined,
                          size: 20, color: Colors.white70),
                    ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NumKey extends StatelessWidget {
  const _NumKey({
    required this.label,
    required this.onTap,
    required this.enabled,
  });
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 80,
      height: 64,
      child: TextButton(
        onPressed: enabled ? onTap : null,
        style: TextButton.styleFrom(
          foregroundColor: Colors.white,
          shape: const CircleBorder(),
          backgroundColor: Colors.white.withValues(alpha: 0.06),
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 22,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
