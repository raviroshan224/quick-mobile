import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/quick_logo.dart';
import '../providers/auth_provider.dart';

/// Step 1 of password reset: enter the 6-digit code that was emailed after
/// [ForgotPasswordScreen]. Only once a well-formed code is entered here does
/// the router move the user on to [ResetPasswordScreen] to set a new
/// password — the two used to be a single combined form.
class VerifyResetCodeScreen extends ConsumerStatefulWidget {
  const VerifyResetCodeScreen({super.key});

  @override
  ConsumerState<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends ConsumerState<VerifyResetCodeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _otpCtrl = TextEditingController();

  @override
  void dispose() {
    _otpCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    // No standalone "verify reset code" endpoint exists on the backend — the
    // code is only actually checked when the new password is submitted on
    // the next screen. This just records it and advances the flow; a wrong
    // code will surface as an error there instead.
    ref.read(authProvider.notifier).confirmResetCode(_otpCtrl.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final email = authState.resetEmail ?? '';

    return Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            return isWide ? _wideLayout(authState, email) : _narrowLayout(authState, email);
          },
        ),
      ),
    );
  }

  Widget _wideLayout(AuthState authState, String email) {
    return Row(
      children: [
        Expanded(child: _BrandPanel()),
        SizedBox(
          width: 440,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
            child: _buildForm(authState, email),
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout(AuthState authState, String email) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _Logo(),
              const SizedBox(height: 32),
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: AppRadius.xlBR,
                ),
                padding: const EdgeInsets.all(28),
                child: _buildForm(authState, email),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AuthState authState, String email) {
    return Form(
      key: _formKey,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withAlpha(24),
              borderRadius: AppRadius.mdBR,
            ),
            child: const Icon(Icons.mark_email_read_outlined, color: AppColors.primary, size: 24),
          ),
          const SizedBox(height: 20),
          Text('Enter verification code', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          RichText(
            text: TextSpan(
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary),
              children: [
                const TextSpan(text: 'We sent a 6-digit code to '),
                TextSpan(
                  text: email,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          _FieldLabel('Reset Code'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _otpCtrl,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.done,
            maxLength: 6,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: '123456',
              prefixIcon: Icon(Icons.tag_rounded, size: 18),
              counterText: '',
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Code is required';
              if (!RegExp(r'^\d{6}$').hasMatch(v.trim())) return 'Enter the 6-digit code';
              return null;
            },
            onFieldSubmitted: (_) => _submit(),
          ),

          if (authState.error != null) ...[
            const SizedBox(height: 16),
            _ErrorBanner(authState.error!),
          ],

          const SizedBox(height: 28),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: authState.isLoading ? null : _submit,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Verify Code'),
            ),
          ),

          const SizedBox(height: 20),
          Center(
            child: GestureDetector(
              onTap: () {
                // Doesn't actually resend anything itself — it drops out of
                // AuthStatus.resetPending (so the router stops forcing the
                // user back into this flow) and sends them to the email
                // screen, where submitting again is what triggers a fresh
                // code.
                ref.read(authProvider.notifier).cancelPasswordReset();
                context.go(AppRoutes.forgotPassword);
              },
              child: Text(
                'Resend code',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () {
                ref.read(authProvider.notifier).cancelPasswordReset();
                context.go(AppRoutes.login);
              },
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.arrow_back_rounded, size: 14, color: AppColors.textSecondary),
                  const SizedBox(width: 4),
                  Text(
                    'Cancel and back to sign in',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
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

class _BrandPanel extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.sidebarBg,
      padding: const EdgeInsets.all(48),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const QuickLogo(size: 64, onDark: true),
          const SizedBox(height: 32),
          Text('Quick', style: AppTextStyles.displayLarge.copyWith(color: Colors.white)),
          const SizedBox(height: 12),
          Text(
            'Fast, beautiful point-of-sale\nfor modern businesses.',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.sidebarText, height: 1.6),
          ),
        ],
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const QuickLogo(size: 40, onDark: true),
        const SizedBox(width: 10),
        Text('Quick', style: AppTextStyles.headlineLarge.copyWith(color: Colors.white)),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  const _FieldLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(text, style: AppTextStyles.labelLarge);
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner(this.message);
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.dangerLight,
        borderRadius: AppRadius.smBR,
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}
