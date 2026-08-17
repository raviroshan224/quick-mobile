import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/widgets/quick_logo.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    await ref.read(authProvider.notifier).login(_emailCtrl.text, _passwordCtrl.text);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authProvider, (_, next) {
      if (next.status == AuthStatus.pendingOtp) context.go('/verify-otp');
    });

    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 700;
            return isWide ? _wideLayout(authState) : _narrowLayout(authState);
          },
        ),
      ),
    );
  }

  Widget _wideLayout(AuthState authState) {
    return Row(
      children: [
        Expanded(child: _BrandPanel()),
        SizedBox(
          width: 440,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
            child: _buildForm(authState),
          ),
        ),
      ],
    );
  }

  Widget _narrowLayout(AuthState authState) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: MediaQuery.of(context).size.height - MediaQuery.of(context).padding.top),
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
                child: _buildForm(authState),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildForm(AuthState authState) {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome back', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text('Sign in to your salon dashboard',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textSecondary)),
          const SizedBox(height: 32),

          _FieldLabel('Email'),
          const SizedBox(height: 8),
          TextFormField(
            controller: _emailCtrl,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(
              hintText: 'you@example.com',
              prefixIcon: Icon(Icons.mail_outline_rounded, size: 18),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return 'Email is required';
              if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w+$').hasMatch(v.trim())) return 'Enter a valid email';
              return null;
            },
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _FieldLabel('Password'),
              GestureDetector(
                onTap: () {
                  ref.read(authProvider.notifier).clearError();
                  context.go(AppRoutes.forgotPassword);
                },
                child: Text(
                  'Forgot password?',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            controller: _passwordCtrl,
            obscureText: _obscure,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon: const Icon(Icons.lock_outline_rounded, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  size: 18,
                ),
                onPressed: () => setState(() => _obscure = !_obscure),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Password is required' : null,
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
                  : const Text('Sign In'),
            ),
          ),

          const SizedBox(height: 24),
          Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text("Don't have an account?",
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary)),
                const SizedBox(width: 4),
                GestureDetector(
                  onTap: () {
                    ref.read(authProvider.notifier).clearError();
                    context.go(AppRoutes.signup);
                  },
                  child: Text(
                    'Create account',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Brand panel (wide layout) ─────────────────────────────────────────────────

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
            'Fast, beautiful point-of-sale\nfor modern salons.',
            style: AppTextStyles.bodyLarge.copyWith(color: AppColors.sidebarText, height: 1.6),
          ),
          const SizedBox(height: 48),
          _Bullet(icon: Icons.bolt_rounded, text: 'Checkout in under 10 seconds'),
          const SizedBox(height: 12),
          _Bullet(icon: Icons.qr_code_2_rounded, text: 'Cash · eSewa, Fonepay & more via QR'),
          const SizedBox(height: 12),
          _Bullet(icon: Icons.people_alt_rounded, text: 'Customer CRM & staff commissions'),
          const SizedBox(height: 12),
          _Bullet(icon: Icons.bar_chart_rounded, text: 'Real-time reports & analytics'),
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
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.labelLarge);
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
            child: Text(message,
                style: const TextStyle(color: AppColors.danger, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  const _Bullet({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withAlpha(40),
            borderRadius: AppRadius.smBR,
          ),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Text(text,
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.sidebarText)),
      ],
    );
  }
}
