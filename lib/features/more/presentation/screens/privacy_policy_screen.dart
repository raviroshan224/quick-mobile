import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
              const Text('Privacy Policy',
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
                  title: '1. Introduction',
                  body:
                      'Quick ("we", "our") is a point-of-sale application designed for salons and beauty businesses. This Privacy Policy explains what information we collect when you use Quick, how we use it, and the rights you have regarding your data.\n\n'
                      'By using Quick you agree to the practices described in this policy. If you do not agree, please discontinue use of the app.',
                ),
                _Section(
                  title: '2. Information We Collect',
                  body:
                      '2.1  Business & Account Data\n'
                      '• Salon name, address, phone number, and email address provided during setup\n'
                      '• Owner and staff login credentials (email address; passwords are never stored in plain text)\n'
                      '• Staff profiles including name, phone, specialties, and commission rate\n\n'
                      '2.2  Customer Data\n'
                      '• Customer name, phone number, and email address (entered manually by your staff)\n'
                      '• Appointment and visit history linked to each customer\n'
                      '• Transaction totals and service details associated with a customer\n\n'
                      '2.3  Transaction Data\n'
                      '• Services or products added to each sale\n'
                      '• Payment method (Cash / an owner-configured payment mode)\n'
                      '• Discount and tip amounts\n'
                      '• Transaction timestamps and status\n\n'
                      '2.4  Operational Data\n'
                      '• Cash drawer open/close sessions and movement records\n'
                      '• Inventory quantities and stock-movement history\n'
                      '• Notification logs (delivery status of automated alerts)\n'
                      '• Image library uploads associated with your account',
                ),
                _Section(
                  title: '3. How We Use Your Information',
                  body:
                      '• Operate Quick: process sales, generate receipts, and maintain transaction history\n'
                      '• Customer management: display visit history, apply loyalty tracking, and allow customer lookup at checkout\n'
                      '• Staff management: calculate commission, display performance reports, and manage access credentials\n'
                      '• Notifications: send low-stock alerts and appointment reminders via email using the contact details you provide\n'
                      '• Reports: generate daily, weekly, and monthly sales analytics visible only to authorised Owner accounts\n'
                      '• Authentication: verify identity via one-time password (OTP) sent to your registered email',
                ),
                _Section(
                  title: '4. Data Sharing & Third Parties',
                  body:
                      'We do not sell your data. We share information only as follows:\n\n'
                      '• Payment modes (eSewa, Fonepay, or any other you configure): Quick does not transmit any transaction data to these services — the QR code you upload is shown directly to the customer, who pays through their own app independently of Quick.\n'
                      '• Email delivery: automated OTP and notification emails are sent through a transactional email service. Only the recipient email address and message content are transmitted.\n'
                      '• Legal requirements: we may disclose information if required by applicable Nepalese law or a valid government order.',
                ),
                _Section(
                  title: '5. Data Security',
                  body:
                      '• All data is transmitted over HTTPS/TLS encrypted connections\n'
                      '• Passwords are hashed using industry-standard algorithms and are never stored in plain text\n'
                      '• Authentication tokens are stored in device-level secure storage\n'
                      '• Access to management screens (reports, settings, staff) is restricted to the Owner role',
                ),
                _Section(
                  title: '6. Data Retention',
                  body:
                      'Transaction records, customer data, and staff records are retained for as long as your account is active or as required for financial record-keeping. If you delete a customer or staff member, their record is removed from active views; historical transaction data may be retained in anonymised form for reporting accuracy.\n\n'
                      'To request full deletion of your account and associated data, contact us at info@quick.com.np.',
                ),
                _Section(
                  title: '7. Your Rights',
                  body:
                      'You have the right to:\n'
                      '• Access: request a copy of the personal data we hold about your business or customers\n'
                      '• Correction: update inaccurate information directly in the app or by contacting us\n'
                      '• Deletion: request deletion of your account and associated data\n'
                      '• Portability: request an export of your transaction and customer records in a standard format\n\n'
                      'To exercise any of these rights, email us at info@quick.com.np or call +977 9823418370.',
                ),
                _Section(
                  title: '8. Children\'s Privacy',
                  body:
                      'Quick is a business tool intended for use by adults. We do not knowingly collect personal information from individuals under 18 years of age.',
                ),
                _Section(
                  title: '9. Changes to This Policy',
                  body:
                      'We may update this Privacy Policy from time to time. Significant changes will be communicated via an in-app notification or email. Continued use of Quick after changes take effect constitutes acceptance of the revised policy.',
                ),
                _Section(
                  title: '10. Contact',
                  body:
                      'For privacy-related questions or requests:\n\n'
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
