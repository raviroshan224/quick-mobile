import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';
import '../../domain/user_model.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController(text: 'owner@salon.com');
  final _passwordCtrl = TextEditingController(text: '1234');
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
      if (next.isAuthenticated) context.go(AppRoutes.dashboard);
    });

    final authState = ref.watch(authProvider);

    return Scaffold(
      backgroundColor: AppColors.sidebarBg,
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 700;
          return isWide
              ? _wideLayout(authState)
              : _narrowLayout(authState);
        },
      ),
    );
  }

  // ── Wide: side-by-side brand + form ──────────────────────────────────────────

  Widget _wideLayout(AuthState authState) {
    return Row(
      children: [
        Expanded(child: _BrandPanel()),
        SizedBox(
          width: 440,
          child: Container(
            color: AppColors.surface,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 56),
            child: _FormContent(
              formKey: _formKey,
              emailCtrl: _emailCtrl,
              passwordCtrl: _passwordCtrl,
              obscure: _obscure,
              onToggleObscure: () => setState(() => _obscure = !_obscure),
              authState: authState,
              onSubmit: _submit,
              onLoginAs: (role) =>
                  ref.read(authProvider.notifier).loginAs(role),
            ),
          ),
        ),
      ],
    );
  }

  // ── Narrow: form only, dark background ───────────────────────────────────────

  Widget _narrowLayout(AuthState authState) {
    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height),
        child: Container(
          color: AppColors.sidebarBg,
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 56),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Mini logo
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: AppRadius.mdBR),
                    child: const Icon(Icons.content_cut_rounded,
                        size: 20, color: Colors.white),
                  ),
                  const SizedBox(width: 10),
                  Text('Salon POS',
                      style: AppTextStyles.headlineLarge
                          .copyWith(color: Colors.white)),
                ],
              ),
              const SizedBox(height: 36),
              // Form card
              Container(
                decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: AppRadius.xlBR),
                padding: const EdgeInsets.all(28),
                child: _FormContent(
                  formKey: _formKey,
                  emailCtrl: _emailCtrl,
                  passwordCtrl: _passwordCtrl,
                  obscure: _obscure,
                  onToggleObscure: () =>
                      setState(() => _obscure = !_obscure),
                  authState: authState,
                  onSubmit: _submit,
                  onLoginAs: (role) =>
                      ref.read(authProvider.notifier).loginAs(role),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Brand panel (wide layout left side) ──────────────────────────────────────

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
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
                color: AppColors.primary, borderRadius: AppRadius.lgBR),
            child: const Icon(Icons.content_cut_rounded,
                size: 28, color: Colors.white),
          ),
          const SizedBox(height: 32),
          Text('Salon POS',
              style: AppTextStyles.displayLarge
                  .copyWith(color: Colors.white)),
          const SizedBox(height: 12),
          Text(
            'Fast, beautiful point-of-sale\nfor modern salons.',
            style: AppTextStyles.bodyLarge
                .copyWith(color: AppColors.sidebarText, height: 1.6),
          ),
          const SizedBox(height: 48),
          _FeatureBullet(
              icon: Icons.bolt_rounded,
              text: 'Checkout in under 10 seconds'),
          const SizedBox(height: 12),
          _FeatureBullet(
              icon: Icons.qr_code_2_rounded,
              text: 'Fonepay QR + Cash + Split'),
          const SizedBox(height: 12),
          _FeatureBullet(
              icon: Icons.people_alt_rounded,
              text: 'Customer CRM & staff commissions'),
          const SizedBox(height: 12),
          _FeatureBullet(
              icon: Icons.bar_chart_rounded,
              text: 'Real-time reports & analytics'),
        ],
      ),
    );
  }
}

// ── Shared form content ───────────────────────────────────────────────────────

class _FormContent extends StatelessWidget {
  const _FormContent({
    required this.formKey,
    required this.emailCtrl,
    required this.passwordCtrl,
    required this.obscure,
    required this.onToggleObscure,
    required this.authState,
    required this.onSubmit,
    required this.onLoginAs,
  });

  final GlobalKey<FormState> formKey;
  final TextEditingController emailCtrl;
  final TextEditingController passwordCtrl;
  final bool obscure;
  final VoidCallback onToggleObscure;
  final AuthState authState;
  final VoidCallback onSubmit;
  final ValueChanged<UserRole> onLoginAs;

  @override
  Widget build(BuildContext context) {
    return Form(
      key: formKey,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Sign in', style: AppTextStyles.displayMedium),
          const SizedBox(height: 6),
          Text('Welcome back to your salon dashboard',
              style: AppTextStyles.bodyMedium),
          const SizedBox(height: 32),

          Text('Email', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: emailCtrl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              hintText: 'owner@salon.com',
              prefixIcon:
                  Icon(Icons.mail_outline_rounded, size: 18),
            ),
            validator: (v) =>
                (v == null || v.trim().isEmpty) ? 'Email is required' : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 20),

          Text('Password', style: AppTextStyles.labelLarge),
          const SizedBox(height: 8),
          TextFormField(
            controller: passwordCtrl,
            obscureText: obscure,
            decoration: InputDecoration(
              hintText: '••••••••',
              prefixIcon:
                  const Icon(Icons.lock_outline_rounded, size: 18),
              suffixIcon: IconButton(
                icon: Icon(
                    obscure
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    size: 18),
                onPressed: onToggleObscure,
              ),
            ),
            validator: (v) =>
                (v == null || v.isEmpty) ? 'Password is required' : null,
            onFieldSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 8),

          if (authState.error != null)
            Container(
              margin: const EdgeInsets.only(top: 4, bottom: 4),
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                  color: AppColors.dangerLight,
                  borderRadius: AppRadius.smBR),
              child: Row(children: [
                const Icon(Icons.error_outline,
                    size: 16, color: AppColors.danger),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(authState.error!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13))),
              ]),
            ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: authState.isLoading ? null : onSubmit,
              child: authState.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text('Sign In'),
            ),
          ),

          const SizedBox(height: 24),
          const Row(children: [
            Expanded(child: Divider()),
            Padding(
                padding: EdgeInsets.symmetric(horizontal: 12),
                child: Text('or demo as',
                    style: AppTextStyles.bodySmall)),
            Expanded(child: Divider()),
          ]),
          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onLoginAs(UserRole.owner),
                  icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      size: 16),
                  label: const Text('Owner'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => onLoginAs(UserRole.staff),
                  icon: const Icon(Icons.person_outline_rounded,
                      size: 16),
                  label: const Text('Staff'),
                ),
              ),
            ],
          ),

          const SizedBox(height: 28),
          Center(
            child: Text(
              'owner@salon.com / 1234  ·  staff@salon.com / 1234',
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textHint),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Feature bullet (brand panel) ─────────────────────────────────────────────

class _FeatureBullet extends StatelessWidget {
  const _FeatureBullet({required this.icon, required this.text});
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
              borderRadius: AppRadius.smBR),
          child: Icon(icon, size: 16, color: AppColors.primary),
        ),
        const SizedBox(width: 12),
        Text(text,
            style: AppTextStyles.bodyMedium
                .copyWith(color: AppColors.sidebarText)),
      ],
    );
  }
}
