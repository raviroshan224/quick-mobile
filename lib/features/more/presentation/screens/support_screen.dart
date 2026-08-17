import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/app_theme.dart';

class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  String _query = '';
  final _ctrl = TextEditingController();

  static const _faqs = [
    _FAQ(
      category: 'Checkout',
      question: 'How do I add a service to a sale?',
      answer:
          'Tap the Services tab in Checkout to browse all services by category, or use the Library tab and tap Services. Tap any item to add it to the current sale.',
    ),
    _FAQ(
      category: 'Checkout',
      question: 'How do I apply a discount?',
      answer:
          'In Checkout, go to the Library tab and tap Discounts. Select any active discount to apply it to the current sale. You can manage discounts from More → Discounts.',
    ),
    _FAQ(
      category: 'Checkout',
      question: 'How do I take a payment with eSewa, Fonepay, or another QR method?',
      answer:
          'Tap "Charge" to open the payment sheet, then tap the payment mode you configured in More → Settings → Payment Modes. This shows its QR code for the customer to scan and pay — tap "Payment Received" once they\'ve paid.',
    ),
    _FAQ(
      category: 'Checkout',
      question: 'Can I add a customer to a sale?',
      answer:
          'Yes. When the payment sheet opens, tap "Add customer (optional)" to attach a customer to the sale. Customers can be searched by name or phone number.',
    ),
    _FAQ(
      category: 'Discounts',
      question: 'How do I create a new discount?',
      answer:
          'Go to More → Discounts and tap "New Discount". Enter a name, choose Percentage or Fixed amount, set the value, and choose what it applies to (all items, a category, or a specific service).',
    ),
    _FAQ(
      category: 'Discounts',
      question: 'Why is my discount not showing at checkout?',
      answer:
          'Only active discounts appear at checkout. Open the discount and make sure the Active toggle is turned on.',
    ),
    _FAQ(
      category: 'Inventory',
      question: 'How do I add a new product?',
      answer:
          'Go to More → Items. Products are currently managed via the setup. In a future update you will be able to add and edit products directly from the app.',
    ),
    _FAQ(
      category: 'Inventory',
      question: 'What does "Low Stock" mean?',
      answer:
          'A product is marked Low Stock when its quantity falls to or below the defined threshold (default: 5 units). You can enable low-stock alerts in Settings → Notifications.',
    ),
    _FAQ(
      category: 'Cash Drawer',
      question: 'How do I open the cash drawer for the day?',
      answer:
          'Go to More → Drawers and record your opening float. This sets the starting cash balance so your end-of-day reconciliation is accurate.',
    ),
    _FAQ(
      category: 'Cash Drawer',
      question: 'How do I record a cash in/out movement?',
      answer:
          'Open More → Drawers and tap the + button to record a cash in or cash out entry with an amount and reason (e.g. "Petty cash", "Vendor payment").',
    ),
    _FAQ(
      category: 'Settings',
      question: 'How do I change my salon name or address?',
      answer:
          'Go to More → Settings → Business section. Tap any field (Salon Name, Address, Phone) to edit and save.',
    ),
    _FAQ(
      category: 'Settings',
      question: 'How do I add a payment mode like eSewa or Fonepay?',
      answer:
          'Go to More → Settings → Payment Modes and tap "Add". Give it a name (e.g. "eSewa") and upload a photo of that account\'s QR code — it will then appear as a payment option at checkout.',
    ),
    _FAQ(
      category: 'Account',
      question: 'How do I switch between Owner and Staff mode?',
      answer:
          'Sign out and log in again with your role-specific credentials. The Owner role has access to reports, settings, and all management screens.',
    ),
  ];

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _query.isEmpty
        ? _faqs
        : _faqs
            .where((f) =>
                f.question.toLowerCase().contains(_query.toLowerCase()) ||
                f.answer.toLowerCase().contains(_query.toLowerCase()) ||
                f.category.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    final categories = <String>[];
    for (final f in filtered) {
      if (!categories.contains(f.category)) categories.add(f.category);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(children: [
          // ── Header ────────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Row(children: [
              GestureDetector(
                onTap: () => context.go(AppRoutes.moreSettings),
                child: const Icon(Icons.arrow_back_ios_new_rounded,
                    size: 18, color: Colors.black),
              ),
              const Spacer(),
              const Text('Support',
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
                // ── Hero ────────────────────────────────────────────────────
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.black,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('How can we help?',
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700)),
                      SizedBox(height: 4),
                      Text('Find answers or get in touch with us.',
                          style: TextStyle(
                              color: AppColors.textTertiary, fontSize: 13)),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // ── Search ───────────────────────────────────────────────────
                TextField(
                  controller: _ctrl,
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search help articles…',
                    hintStyle: const TextStyle(
                        color: AppColors.textTertiary, fontSize: 14),
                    prefixIcon: const Icon(Icons.search,
                        size: 18, color: AppColors.textTertiary),
                    suffixIcon: _query.isNotEmpty
                        ? GestureDetector(
                            onTap: () {
                              setState(() => _query = '');
                              _ctrl.clear();
                            },
                            child: const Icon(Icons.close,
                                size: 16, color: AppColors.textTertiary),
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                        borderSide: BorderSide.none,
                        borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
                const SizedBox(height: 20),

                // ── Contact cards ────────────────────────────────────────────
                if (_query.isEmpty) ...[
                  const _SectionLabel(text: 'Contact Us'),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: _ContactCard(
                        icon: Icons.chat_bubble_outline_rounded,
                        label: 'WhatsApp',
                        subtitle: '+977 9823418370',
                        color: const Color(0xFF25D366),
                        onTap: () => _launch(
                            context, 'https://wa.me/9779823418370'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ContactCard(
                        icon: Icons.email_outlined,
                        label: 'Email',
                        subtitle: 'info@quick.com.np',
                        color: AppColors.primary,
                        onTap: () => _launch(context,
                            'mailto:info@quick.com.np?subject=Quick%20Support'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _ContactCard(
                        icon: Icons.phone_outlined,
                        label: 'Call',
                        subtitle: '+977 9823418370',
                        color: AppColors.primary,
                        onTap: () => _launch(
                            context, 'tel:+9779823418370'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 24),
                ],

                // ── FAQs ─────────────────────────────────────────────────────
                if (filtered.isEmpty)
                  _EmptySearch(query: _query)
                else ...[
                  const _SectionLabel(text: 'Frequently Asked Questions'),
                  const SizedBox(height: 8),
                  for (final cat in categories) ...[
                    _CategoryHeader(label: cat),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        children: filtered
                            .where((f) => f.category == cat)
                            .map((f) => _FAQTile(faq: f))
                            .toList(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ],

                // ── Footer ───────────────────────────────────────────────────
                if (_query.isEmpty) ...[
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.divider),
                    ),
                    child: Column(children: [
                      const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.auto_awesome,
                              size: 16, color: AppColors.textTertiary),
                          SizedBox(width: 6),
                          Text('Quick · Version 1.0.0',
                              style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textTertiary)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _FooterLink(
                              label: 'Privacy Policy',
                              onTap: () =>
                                  context.go(AppRoutes.morePrivacyPolicy)),
                          const Text(' · ',
                              style: TextStyle(
                                  color: AppColors.border)),
                          _FooterLink(
                              label: 'Terms of Use',
                              onTap: () =>
                                  context.go(AppRoutes.moreTerms)),
                        ],
                      ),
                    ]),
                  ),
                ],
              ],
            ),
          ),
        ]),
      ),
    );
  }

  Future<void> _launch(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not open. Please try manually.'),
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.black,
          duration: Duration(seconds: 2),
        ));
      }
    }
  }
}

// ─── Data ─────────────────────────────────────────────────────────────────────

class _FAQ {
  const _FAQ(
      {required this.category,
      required this.question,
      required this.answer});
  final String category;
  final String question;
  final String answer;
}

// ─── Widgets ──────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
      style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.textSecondary,
          letterSpacing: 0.8));
}

class _CategoryHeader extends StatelessWidget {
  const _CategoryHeader({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
        child: Text(label,
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary)),
      );
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 18, color: color),
              ),
              const SizedBox(height: 10),
              Text(label,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Text(subtitle,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textTertiary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      );
}

class _FAQTile extends StatelessWidget {
  const _FAQTile({required this.faq});
  final _FAQ faq;

  @override
  Widget build(BuildContext context) => Theme(
        data: Theme.of(context).copyWith(
            dividerColor: Colors.transparent,
            splashColor: Colors.transparent,
            highlightColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding:
              const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          childrenPadding:
              const EdgeInsets.fromLTRB(16, 0, 16, 14),
          expandedAlignment: Alignment.centerLeft,
          iconColor: Colors.black,
          collapsedIconColor: AppColors.textTertiary,
          title: Text(faq.question,
              style: const TextStyle(
                  fontSize: 14, fontWeight: FontWeight.w500)),
          children: [
            Text(faq.answer,
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.6)),
          ],
        ),
      );
}

class _EmptySearch extends StatelessWidget {
  const _EmptySearch({required this.query});
  final String query;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(children: [
          const Icon(Icons.search_off_rounded,
              size: 40, color: AppColors.border),
          const SizedBox(height: 12),
          Text('No results for "$query"',
              style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary)),
          const SizedBox(height: 6),
          const Text('Try a different keyword or browse the topics above.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13, color: AppColors.textTertiary)),
        ]),
      );
}

class _FooterLink extends StatelessWidget {
  const _FooterLink({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: onTap,
        child: Text(label,
            style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                decoration: TextDecoration.underline,
                decorationColor: AppColors.textSecondary)),
      );
}
