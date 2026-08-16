import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());
  bool _resent = false;

  @override
  void dispose() {
    for (final c in _ctrls) { c.dispose(); }
    for (final n in _nodes) { n.dispose(); }
    super.dispose();
  }

  String get _otp => _ctrls.map((c) => c.text).join();

  Future<void> _submit() async {
    if (_otp.length < 6) return;
    await ref.read(authProvider.notifier).verifyOtp(_otp);
  }

  Future<void> _resend() async {
    await ref.read(authProvider.notifier).resendOtp();
    setState(() => _resent = true);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _resent = false);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      if (next.status == AuthStatus.emailVerified) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Email verified! You can now sign in.'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        context.go(AppRoutes.login);
      }
    });

    final auth = ref.watch(authProvider);
    final email = auth.pendingEmail ?? '';

    return Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 28),
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.xlBR,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded),
                      onPressed: () {
                        ref.read(authProvider.notifier).cancelPendingOtp();
                        context.go(AppRoutes.login);
                      },
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 12),
                    Text('Check your email', style: AppTextStyles.displayMedium),
                    const SizedBox(height: 8),
                    Text(
                      'We sent a 6-digit code to\n$email',
                      style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: List.generate(6, (i) => _OtpBox(
                        controller: _ctrls[i],
                        focusNode: _nodes[i],
                        onChanged: (v) {
                          if (v.length == 1 && i < 5) {
                            _nodes[i + 1].requestFocus();
                          } else if (v.isEmpty && i > 0) {
                            _nodes[i - 1].requestFocus();
                          }
                          setState(() {});
                          if (_otp.length == 6) _submit();
                        },
                      )),
                    ),
                    if (auth.error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppColors.dangerLight,
                          borderRadius: AppRadius.smBR,
                        ),
                        child: Row(children: [
                          const Icon(Icons.error_outline,
                              size: 16, color: AppColors.danger),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              auth.error!,
                              style: const TextStyle(
                                  color: AppColors.danger, fontSize: 13),
                            ),
                          ),
                        ]),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: (auth.isLoading || _otp.length < 6)
                            ? null
                            : _submit,
                        child: auth.isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2, color: Colors.white))
                            : const Text('Verify Code'),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Center(
                      child: TextButton(
                        onPressed: _resent ? null : _resend,
                        child: Text(
                          _resent ? 'Code sent!' : "Didn't get it? Resend",
                          style: AppTextStyles.bodySmall.copyWith(
                            color: _resent
                                ? AppColors.success
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _OtpBox extends StatelessWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
  });
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 52,
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        maxLength: 1,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          filled: true,
          fillColor: AppColors.surfaceVariant,
          border: OutlineInputBorder(
            borderRadius: AppRadius.mdBR,
            borderSide: const BorderSide(color: AppColors.divider),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: AppRadius.mdBR,
            borderSide: const BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: EdgeInsets.zero,
        ),
        onChanged: onChanged,
      ),
    );
  }
}
