import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go(AppRoutes.moreSupport),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.black),
              ),
              const Spacer(),
              const Text('Terms of Use',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600)),
              const Spacer(),
              const SizedBox(width: 18),
            ]),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: const [
                _PolicyMeta(date: 'Effective: 1 January 2025'),
                SizedBox(height: 20),
                _Section(
                  title: '1. Acceptance of Terms',
                  body:
                      'By downloading, installing, or using Quick ("the App"), you ("Business Owner", "User") agree to be bound by these Terms of Use. If you do not agree to these terms, do not use the App.\n\n'
                      'These terms apply to all users of Quick, including business owners and their staff members.',
                ),
                _Section(
                  title: '2. Description of Service',
                  body:
                      'Quick is a point-of-sale application for salons and beauty businesses. It provides the following features:\n\n'
                      '• Sales checkout with service and product selection\n'
                      '• Cash and QR-based payment modes you configure (eSewa, Fonepay, etc.)\n'
                      '• Customer management and visit history\n'
                      '• Staff management and commission tracking\n'
                      '• Cash drawer management\n'
                      '• Inventory and stock tracking\n'
                      '• Sales reports and analytics\n'
                      '• Discount and refund management\n'
                      '• OTP-based secure authentication',
                ),
                _Section(
                  title: '3. Account Registration & Security',
                  body:
                      '3.1  The first account registered for a salon is granted the Owner role. Subsequent staff accounts are created by the Owner.\n\n'
                      '3.2  You are responsible for maintaining the confidentiality of your login credentials. Do not share your password or authentication tokens with unauthorised individuals.\n\n'
                      '3.3  You are responsible for all activity that occurs under your account. Notify us immediately at info@quick.com.np if you suspect unauthorised access.\n\n'
                      '3.4  We reserve the right to suspend or terminate accounts that violate these terms.',
                ),
                _Section(
                  title: '4. Acceptable Use',
                  body:
                      'You agree to use Quick only for lawful business purposes. You must not:\n\n'
                      '• Use the App for any fraudulent, deceptive, or illegal activity\n'
                      '• Process transactions for goods or services that are illegal under Nepalese law\n'
                      '• Attempt to reverse-engineer, decompile, or modify the App\n'
                      '• Interfere with or disrupt the App\'s servers or networks\n'
                      '• Use the App to collect or store customer data beyond what is needed for salon operations\n'
                      '• Share customer data with third parties without the customer\'s consent',
                ),
                _Section(
                  title: '5. Payment Processing',
                  body:
                      '5.1  Cash transactions are recorded by the App but are the sole responsibility of your business. Quick is not liable for discrepancies in cash handling.\n\n'
                      '5.2  Payment modes you configure (eSewa, Fonepay, or any other QR-based method) display a QR code you provide for the customer to pay directly to your own account — Quick is not a payment processor, is not involved in the transfer, and does not handle, verify, or store any payment credentials. Confirming a sale marked as paid via one of these modes is solely your business\'s responsibility.\n\n'
                      '5.3  All transaction amounts are in Nepalese Rupees (Rs) unless otherwise specified in your settings.',
                ),
                _Section(
                  title: '6. Customer Data Responsibility',
                  body:
                      'You are the data controller for any customer personal information entered into Quick. You are responsible for:\n\n'
                      '• Obtaining any necessary consent from customers before collecting their information\n'
                      '• Complying with applicable data protection laws in Nepal\n'
                      '• Keeping customer data accurate and up to date\n'
                      '• Responding to customer requests to access or delete their data',
                ),
                _Section(
                  title: '7. Intellectual Property',
                  body:
                      'Quick and all content, features, and functionality (including but not limited to the interface, design, logos, and software) are owned by Quick and are protected by applicable intellectual property laws.\n\n'
                      'You are granted a limited, non-exclusive, non-transferable licence to use the App for your internal salon business operations. This licence does not include the right to resell, sublicense, or distribute the App.',
                ),
                _Section(
                  title: '8. Disclaimers',
                  body:
                      'Quick is provided "as is" without warranties of any kind. We do not warrant that:\n\n'
                      '• The App will be uninterrupted or error-free\n'
                      '• Reports and analytics will be free of inaccuracies\n'
                      '• The App will meet every specific business requirement\n\n'
                      'You use the App at your own risk. Always maintain independent financial records for your business.',
                ),
                _Section(
                  title: '9. Limitation of Liability',
                  body:
                      'To the maximum extent permitted by law, Quick shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the App, including but not limited to loss of revenue, loss of data, or business interruption.\n\n'
                      'Our total liability to you for any claim arising out of or relating to these terms shall not exceed the amount you paid for the App in the twelve months preceding the claim.',
                ),
                _Section(
                  title: '10. Changes to Terms',
                  body:
                      'We may update these Terms of Use from time to time. Significant changes will be communicated via an in-app notification or email. Continued use of Quick after the effective date of revised terms constitutes your acceptance of the changes.',
                ),
                _Section(
                  title: '11. Governing Law',
                  body:
                      'These Terms of Use are governed by and construed in accordance with the laws of Nepal. Any disputes arising from these terms shall be subject to the exclusive jurisdiction of the courts of Nepal.',
                ),
                _Section(
                  title: '12. Contact',
                  body:
                      'For questions about these Terms of Use:\n\n'
                      'Quick\n'
                      'Email: info@quick.com.np\n'
                      'Phone: +977 9823418370\n'
                      'WhatsApp: +977 9823418370',
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

class _PolicyMeta extends StatelessWidget {
  const _PolicyMeta({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(date,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500)),
      );
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Text(body,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.65)),
            const SizedBox(height: 12),
            const Divider(color: AppColors.divider),
          ],
        ),
      );
}
