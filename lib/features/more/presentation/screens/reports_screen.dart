import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_constants.dart';

// ─── Formatting helpers ───────────────────────────────────────────────────────

String _npr(double v) {
  final whole = v.toInt();
  final str = whole.toString();
  final buf = StringBuffer();
  int count = 0;
  for (int i = str.length - 1; i >= 0; i--) {
    if (count > 0 && count % 3 == 0) buf.write(',');
    buf.write(str[i]);
    count++;
  }
  return 'NPR ${buf.toString().split('').reversed.join()}';
}

// ─── Mock data ────────────────────────────────────────────────────────────────

// ── Sales ────────────────────────────────────────────────────────────────────

class _SalesData {
  const _SalesData({
    required this.revenue,
    required this.transactions,
    required this.cashPct,
    required this.fonepayPct,
    required this.splitPct,
    required this.hourlyRevenue,
  });
  final double revenue;
  final int transactions;
  final double cashPct;
  final double fonepayPct;
  final double splitPct;
  // hour label → revenue
  final Map<String, double> hourlyRevenue;

  double get avgTicket => transactions == 0 ? 0 : revenue / transactions;
}

const _salesToday = _SalesData(
  revenue: 34800,
  transactions: 18,
  cashPct: 55,
  fonepayPct: 38,
  splitPct: 7,
  hourlyRevenue: {
    '10 AM': 3200,
    '11 AM': 5400,
    '12 PM': 6800,
    '1 PM': 4200,
    '2 PM': 5600,
    '3 PM': 4800,
    '4 PM': 3200,
    '5 PM': 1600,
  },
);

const _salesWeek = _SalesData(
  revenue: 184200,
  transactions: 97,
  cashPct: 48,
  fonepayPct: 44,
  splitPct: 8,
  hourlyRevenue: {
    'Mon': 24000,
    'Tue': 31000,
    'Wed': 28500,
    'Thu': 34800,
    'Fri': 38200,
    'Sat': 27700,
  },
);

const _salesMonth = _SalesData(
  revenue: 732000,
  transactions: 382,
  cashPct: 50,
  fonepayPct: 42,
  splitPct: 8,
  hourlyRevenue: {
    'Wk 1': 158000,
    'Wk 2': 182000,
    'Wk 3': 196000,
    'Wk 4': 196000,
  },
);

// ── Staff ─────────────────────────────────────────────────────────────────────

class _StaffRow {
  const _StaffRow({
    required this.name,
    required this.services,
    required this.revenue,
    required this.commissionRate,
  });
  final String name;
  final int services;
  final double revenue;
  final double commissionRate; // percentage, e.g. 12 = 12%
  double get commission => revenue * commissionRate / 100;
}

const _staffData = <_StaffRow>[
  _StaffRow(
    name: 'Priya Thapa',
    services: 48,
    revenue: 142000,
    commissionRate: 12,
  ),
  _StaffRow(
    name: 'Sita Gurung',
    services: 41,
    revenue: 118500,
    commissionRate: 10,
  ),
  _StaffRow(name: 'Anil Rai', services: 36, revenue: 98200, commissionRate: 10),
  _StaffRow(
    name: 'Maya Shrestha',
    services: 29,
    revenue: 74300,
    commissionRate: 8,
  ),
];

// ── Services ──────────────────────────────────────────────────────────────────

class _ServiceStat {
  const _ServiceStat({
    required this.name,
    required this.count,
    required this.revenue,
  });
  final String name;
  final int count;
  final double revenue;
}

const _topServices = <_ServiceStat>[
  _ServiceStat(name: 'Hair Cut', count: 84, revenue: 117600),
  _ServiceStat(name: 'Manicure', count: 71, revenue: 99400),
  _ServiceStat(name: 'Facial', count: 58, revenue: 145000),
  _ServiceStat(name: 'Hair Colour', count: 47, revenue: 141000),
  _ServiceStat(name: 'Waxing', count: 43, revenue: 51600),
  _ServiceStat(name: 'Eyebrow Threading', count: 38, revenue: 22800),
];

class _CategoryStat {
  const _CategoryStat({
    required this.name,
    required this.revenue,
    required this.color,
  });
  final String name;
  final double revenue;
  final Color color;
}

const _categoryStats = <_CategoryStat>[
  _CategoryStat(name: 'Hair', revenue: 258600, color: Color(0xFF6366F1)),
  _CategoryStat(name: 'Nails', revenue: 122400, color: Color(0xFFEC4899)),
  _CategoryStat(name: 'Skin', revenue: 198000, color: Color(0xFF14B8A6)),
  _CategoryStat(name: 'Makeup', revenue: 88200, color: Color(0xFFF59E0B)),
  _CategoryStat(name: 'Massage', revenue: 64800, color: Color(0xFF10B981)),
];

// ── Inventory ─────────────────────────────────────────────────────────────────

class _StockItem {
  const _StockItem({
    required this.name,
    required this.current,
    required this.threshold,
    required this.unit,
    required this.valuePerUnit,
  });
  final String name;
  final int current;
  final int threshold;
  final String unit;
  final double valuePerUnit;
}

class _StockMovement {
  const _StockMovement({
    required this.item,
    required this.type,
    required this.qty,
    required this.note,
    required this.daysAgo,
  });
  final String item;
  final String type; // 'in' | 'out'
  final int qty;
  final String note;
  final int daysAgo;
}

const _lowStockItems = <_StockItem>[
  _StockItem(
    name: 'Hair Dye — Black',
    current: 3,
    threshold: 10,
    unit: 'tubes',
    valuePerUnit: 450,
  ),
  _StockItem(
    name: 'Nail Polish Remover',
    current: 1,
    threshold: 5,
    unit: 'bottles',
    valuePerUnit: 320,
  ),
  _StockItem(
    name: 'Facial Cleanser',
    current: 2,
    threshold: 8,
    unit: 'units',
    valuePerUnit: 780,
  ),
];

const _allInventoryItems = <_StockItem>[
  _StockItem(
    name: 'Shampoo',
    current: 24,
    threshold: 10,
    unit: 'bottles',
    valuePerUnit: 280,
  ),
  _StockItem(
    name: 'Conditioner',
    current: 18,
    threshold: 8,
    unit: 'bottles',
    valuePerUnit: 320,
  ),
  _StockItem(
    name: 'Hair Dye — Black',
    current: 3,
    threshold: 10,
    unit: 'tubes',
    valuePerUnit: 450,
  ),
  _StockItem(
    name: 'Nail Polish Remover',
    current: 1,
    threshold: 5,
    unit: 'bottles',
    valuePerUnit: 320,
  ),
  _StockItem(
    name: 'Facial Cleanser',
    current: 2,
    threshold: 8,
    unit: 'units',
    valuePerUnit: 780,
  ),
  _StockItem(
    name: 'Wax Strips',
    current: 120,
    threshold: 30,
    unit: 'strips',
    valuePerUnit: 15,
  ),
];

const _stockMovements = <_StockMovement>[
  _StockMovement(
    item: 'Shampoo',
    type: 'in',
    qty: 12,
    note: 'Supplier delivery',
    daysAgo: 0,
  ),
  _StockMovement(
    item: 'Hair Dye — Black',
    type: 'out',
    qty: 2,
    note: 'Used in service',
    daysAgo: 1,
  ),
  _StockMovement(
    item: 'Facial Cleanser',
    type: 'out',
    qty: 1,
    note: 'Used in service',
    daysAgo: 1,
  ),
  _StockMovement(
    item: 'Wax Strips',
    type: 'out',
    qty: 20,
    note: 'Used in service',
    daysAgo: 2,
  ),
  _StockMovement(
    item: 'Conditioner',
    type: 'in',
    qty: 6,
    note: 'Supplier delivery',
    daysAgo: 3,
  ),
];

double get _totalStockValue => _allInventoryItems.fold(
  0,
  (sum, item) => sum + item.current * item.valuePerUnit,
);

// ─── Screen ───────────────────────────────────────────────────────────────────

class ReportsScreen extends HookConsumerWidget {
  const ReportsScreen({super.key});

  static const _tabs = ['Sales', 'Staff', 'Services', 'Inventory'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tabIndex = useState(0);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      body: SafeArea(
        child: Column(
          children: [
            // ── Header ────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => context.go(AppRoutes.more),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.black,
                    ),
                  ),
                  const Spacer(),
                  const Text(
                    'Reports',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => _showDownloadSheet(context, tabIndex.value),
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF3F4F6),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.download_rounded,
                        size: 18,
                        color: Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Tab bar ───────────────────────────────────────────────────
            SizedBox(
              height: 38,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _tabs.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (_, i) => _TopTab(
                  label: _tabs[i],
                  selected: tabIndex.value == i,
                  onTap: () => tabIndex.value = i,
                ),
              ),
            ),

            const SizedBox(height: 12),

            // ── Body ──────────────────────────────────────────────────────
            Expanded(
              child: switch (tabIndex.value) {
                0 => const _SalesTab(),
                1 => const _StaffTab(),
                2 => const _ServicesTab(),
                _ => const _InventoryTab(),
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Download sheet ───────────────────────────────────────────────────────────

void _showDownloadSheet(BuildContext context, int tabIndex) {
  final reportNames = ['Sales', 'Staff Performance', 'Services', 'Inventory'];
  final reportName = reportNames[tabIndex];

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (ctx) => SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFE5E7EB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
            child: Row(
              children: [
                const Icon(Icons.download_rounded, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Download $reportName Report',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(ctx),
                  child: const Icon(
                    Icons.close,
                    size: 20,
                    color: Color(0xFF6B7280),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 16),
          _DownloadOption(
            icon: Icons.picture_as_pdf_outlined,
            label: 'Download as PDF',
            subtitle: 'Best for printing and sharing',
            color: const Color(0xFFEF4444),
            onTap: () {
              Navigator.pop(ctx);
              _showDownloadSuccess(context, reportName, 'PDF');
            },
          ),
          _DownloadOption(
            icon: Icons.table_chart_outlined,
            label: 'Download as Excel',
            subtitle: 'Best for data analysis',
            color: const Color(0xFF10B981),
            onTap: () {
              Navigator.pop(ctx);
              _showDownloadSuccess(context, reportName, 'Excel');
            },
          ),
          const SizedBox(height: 16),
        ],
      ),
    ),
  );
}

void _showDownloadSuccess(
  BuildContext context,
  String reportName,
  String format,
) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Row(
        children: [
          const Icon(
            Icons.check_circle_rounded,
            color: Color(0xFF10B981),
            size: 18,
          ),
          const SizedBox(width: 10),
          Text(
            '$reportName report ($format) downloaded',
            style: const TextStyle(color: Colors.white),
          ),
        ],
      ),
      backgroundColor: Colors.black,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      duration: const Duration(seconds: 2),
    ),
  );
}

class _DownloadOption extends StatelessWidget {
  const _DownloadOption({
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 20, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, size: 18, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}

// ─── Top tab chip ─────────────────────────────────────────────────────────────

class _TopTab extends StatelessWidget {
  const _TopTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

// ─── Section label ────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: Color(0xFF6B7280),
          letterSpacing: 0.8,
        ),
      ),
    );
  }
}

// ─── Bar widget ───────────────────────────────────────────────────────────────

class _Bar extends StatelessWidget {
  const _Bar({required this.fraction, required this.color, this.height = 8});
  final double fraction; // 0.0 – 1.0
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, constraints) {
        return Stack(
          children: [
            Container(
              height: height,
              width: constraints.maxWidth,
              decoration: BoxDecoration(
                color: const Color(0xFFE5E7EB),
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
            Container(
              height: height,
              width: constraints.maxWidth * fraction.clamp(0.0, 1.0),
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(height / 2),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SALES TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _SalesTab extends HookWidget {
  const _SalesTab();

  @override
  Widget build(BuildContext context) {
    final periodIndex = useState(0); // 0=Today  1=Week  2=Month

    final data = switch (periodIndex.value) {
      0 => _salesToday,
      1 => _salesWeek,
      _ => _salesMonth,
    };

    final barLabel = switch (periodIndex.value) {
      0 => 'Top Hours',
      1 => 'Daily Revenue',
      _ => 'Weekly Revenue',
    };

    final maxBarValue = data.hourlyRevenue.values.fold(
      0.0,
      (m, v) => v > m ? v : m,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // ── Period chips ──────────────────────────────────────────────────
        Row(
          children: [
            for (final (i, label) in [
              (0, 'Today'),
              (1, 'This Week'),
              (2, 'This Month'),
            ]) ...[
              if (i > 0) const SizedBox(width: 8),
              _PeriodChip(
                label: label,
                selected: periodIndex.value == i,
                onTap: () => periodIndex.value = i,
              ),
            ],
          ],
        ),

        const SizedBox(height: 16),

        // ── Summary card (black) ──────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Total Revenue',
                style: TextStyle(fontSize: 13, color: Color(0xFF9CA3AF)),
              ),
              const SizedBox(height: 6),
              Text(
                _npr(data.revenue),
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Transactions',
                      value: '${data.transactions}',
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 32,
                    color: const Color(0xFF374151),
                  ),
                  Expanded(
                    child: _SummaryMetric(
                      label: 'Avg Ticket',
                      value: _npr(data.avgTicket),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Revenue breakdown ─────────────────────────────────────────────
        const _SectionLabel('Revenue Breakdown'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              _BreakdownRow(
                label: 'Cash',
                pct: data.cashPct,
                color: const Color(0xFF16A34A),
              ),
              const SizedBox(height: 14),
              _BreakdownRow(
                label: 'Fonepay',
                pct: data.fonepayPct,
                color: const Color(0xFF4F46E5),
              ),
              const SizedBox(height: 14),
              _BreakdownRow(
                label: 'Split',
                pct: data.splitPct,
                color: const Color(0xFFF59E0B),
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Bar chart ─────────────────────────────────────────────────────
        _SectionLabel(barLabel),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (final entry in data.hourlyRevenue.entries) ...[
                _HourBar(
                  label: entry.key,
                  value: entry.value,
                  maxValue: maxBarValue,
                ),
                if (entry.key != data.hourlyRevenue.keys.last)
                  const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? Colors.black : const Color(0xFFE5E7EB),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 12, color: Color(0xFF9CA3AF)),
        ),
      ],
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.label,
    required this.pct,
    required this.color,
  });
  final String label;
  final double pct;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 64,
          child: Text(
            label,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: _Bar(fraction: pct / 100, color: color),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 40,
          child: Text(
            '${pct.toInt()}%',
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}

class _HourBar extends StatelessWidget {
  const _HourBar({
    required this.label,
    required this.value,
    required this.maxValue,
  });
  final String label;
  final double value;
  final double maxValue;

  @override
  Widget build(BuildContext context) {
    final fraction = maxValue == 0 ? 0.0 : value / maxValue;
    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
          ),
        ),
        Expanded(
          child: _Bar(fraction: fraction, color: Colors.black, height: 10),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 72,
          child: Text(
            _npr(value),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// STAFF TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _StaffTab extends StatelessWidget {
  const _StaffTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        const _SectionLabel('Staff Performance — This Month'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              // Table header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Row(
                  children: const [
                    SizedBox(width: 24, child: Text('#', style: _headerStyle)),
                    SizedBox(width: 12),
                    Expanded(child: Text('Name', style: _headerStyle)),
                    SizedBox(
                      width: 40,
                      child: Text(
                        'Svcs',
                        textAlign: TextAlign.center,
                        style: _headerStyle,
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 80,
                      child: Text(
                        'Revenue',
                        textAlign: TextAlign.right,
                        style: _headerStyle,
                      ),
                    ),
                    SizedBox(width: 8),
                    SizedBox(
                      width: 72,
                      child: Text(
                        'Commission',
                        textAlign: TextAlign.right,
                        style: _headerStyle,
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE5E7EB)),
              for (final (i, staff) in _staffData.indexed)
                _StaffTableRow(rank: i + 1, data: staff),
            ],
          ),
        ),

        const SizedBox(height: 20),
        const _SectionLabel('Commission Rates'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (final (i, staff) in _staffData.indexed) ...[
                if (i > 0) const SizedBox(height: 12),
                _CommissionBar(staff: staff),
              ],
            ],
          ),
        ),
      ],
    );
  }

  static const _headerStyle = TextStyle(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    color: Color(0xFF6B7280),
    letterSpacing: 0.5,
  );
}

class _StaffTableRow extends StatelessWidget {
  const _StaffTableRow({required this.rank, required this.data});
  final int rank;
  final _StaffRow data;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text(
              '$rank',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: Color(0xFF9CA3AF),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                CircleAvatar(
                  radius: 15,
                  backgroundColor: const Color(0xFFF3F4F6),
                  child: Text(
                    data.name[0],
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    data.name,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 40,
            child: Text(
              '${data.services}',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 80,
            child: Text(
              _npr(data.revenue),
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 72,
            child: Text(
              _npr(data.commission),
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Color(0xFF16A34A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommissionBar extends StatelessWidget {
  const _CommissionBar({required this.staff});
  final _StaffRow staff;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 100,
          child: Text(
            staff.name.split(' ').first,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: _Bar(
            fraction: staff.commissionRate / 20,
            color: const Color(0xFF16A34A),
            height: 8,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${staff.commissionRate.toInt()}%',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: Color(0xFF16A34A),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// SERVICES TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _ServicesTab extends StatelessWidget {
  const _ServicesTab();

  @override
  Widget build(BuildContext context) {
    final maxCount = _topServices
        .map((s) => s.count)
        .fold(0, (m, v) => v > m ? v : m);
    final totalCategoryRevenue = _categoryStats.fold(
      0.0,
      (sum, c) => sum + c.revenue,
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // ── Most popular ──────────────────────────────────────────────────
        const _SectionLabel('Most Popular'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (final (i, svc) in _topServices.indexed)
                _ServiceRow(
                  rank: i + 1,
                  svc: svc,
                  maxCount: maxCount,
                  showDivider: i < _topServices.length - 1,
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Category breakdown ────────────────────────────────────────────
        const _SectionLabel('Category Breakdown'),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (final (i, cat) in _categoryStats.indexed) ...[
                if (i > 0) const SizedBox(height: 14),
                _CategoryRow(cat: cat, totalRevenue: totalCategoryRevenue),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _ServiceRow extends StatelessWidget {
  const _ServiceRow({
    required this.rank,
    required this.svc,
    required this.maxCount,
    required this.showDivider,
  });
  final int rank;
  final _ServiceStat svc;
  final int maxCount;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                  color: rank == 1 ? Colors.black : const Color(0xFFF3F4F6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Center(
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: rank == 1 ? Colors.white : const Color(0xFF6B7280),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      svc.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _Bar(
                      fraction: maxCount == 0 ? 0 : svc.count / maxCount,
                      color: const Color(0xFF6366F1),
                      height: 6,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${svc.count} bookings',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _npr(svc.revenue),
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFF3F4F6),
          ),
      ],
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({required this.cat, required this.totalRevenue});
  final _CategoryStat cat;
  final double totalRevenue;

  @override
  Widget build(BuildContext context) {
    final pct = totalRevenue == 0 ? 0.0 : cat.revenue / totalRevenue;
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 60,
          child: Text(
            cat.name,
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(
          child: _Bar(fraction: pct, color: cat.color, height: 8),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 84,
          child: Text(
            _npr(cat.revenue),
            textAlign: TextAlign.right,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF374151),
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// INVENTORY TAB
// ═══════════════════════════════════════════════════════════════════════════════

class _InventoryTab extends StatelessWidget {
  const _InventoryTab();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        // ── Low stock ─────────────────────────────────────────────────────
        const _SectionLabel('Low Stock Alert'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (final (i, item) in _lowStockItems.indexed)
                _LowStockRow(
                  item: item,
                  showDivider: i < _lowStockItems.length - 1,
                ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Stock value ───────────────────────────────────────────────────
        const _SectionLabel('Stock Value'),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.inventory_2_outlined,
                color: Color(0xFF9CA3AF),
                size: 28,
              ),
              const SizedBox(width: 16),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _npr(_totalStockValue),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_allInventoryItems.length} items tracked',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Recent movements ──────────────────────────────────────────────
        const _SectionLabel('Recent Movements'),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            children: [
              for (final (i, mv) in _stockMovements.indexed)
                _MovementRow(
                  movement: mv,
                  showDivider: i < _stockMovements.length - 1,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LowStockRow extends StatelessWidget {
  const _LowStockRow({required this.item, required this.showDivider});
  final _StockItem item;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final pct = item.current / item.threshold;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF2F2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.warning_amber_rounded,
                  size: 18,
                  color: Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _Bar(
                      fraction: pct,
                      color: const Color(0xFFDC2626),
                      height: 5,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: '${item.current}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                        TextSpan(
                          text: '/${item.threshold}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    item.unit,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFF3F4F6),
          ),
      ],
    );
  }
}

class _MovementRow extends StatelessWidget {
  const _MovementRow({required this.movement, required this.showDivider});
  final _StockMovement movement;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final isIn = movement.type == 'in';
    final timeLabel = movement.daysAgo == 0
        ? 'Today'
        : movement.daysAgo == 1
        ? 'Yesterday'
        : '${movement.daysAgo}d ago';

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: isIn
                      ? const Color(0xFFDCFCE7)
                      : const Color(0xFFFEE2E2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isIn
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                  size: 16,
                  color: isIn
                      ? const Color(0xFF16A34A)
                      : const Color(0xFFDC2626),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      movement.item,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      movement.note,
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF9CA3AF),
                      ),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${isIn ? '+' : '-'}${movement.qty}',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: isIn
                          ? const Color(0xFF16A34A)
                          : const Color(0xFFDC2626),
                    ),
                  ),
                  Text(
                    timeLabel,
                    style: const TextStyle(
                      fontSize: 11,
                      color: Color(0xFF9CA3AF),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (showDivider)
          const Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Color(0xFFF3F4F6),
          ),
      ],
    );
  }
}
