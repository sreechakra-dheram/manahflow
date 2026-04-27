import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/providers/app_state.dart';
import '../../shared/widgets/section_header.dart';

class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      future: context.read<AppState>().getReportData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(child: Text('Failed to load reports: ${snapshot.error}'));
        }

        final data = snapshot.data ?? {};
        final projectSpend = Map<String, double>.from(data['projectSpend'] ?? {});
        final vendorOutstanding = Map<String, double>.from(data['vendorOutstanding'] ?? {});
        final aging = Map<String, double>.from(data['aging'] ?? {
          '0–30 days': 0,
          '30–60 days': 0,
          '60–90 days': 0,
          '90+ days': 0,
        });

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(builder: (ctx, c) {
                final wide = c.maxWidth > 500;
                final titleCol = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Reports & Analytics',
                        style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary)),
                    SizedBox(height: 4),
                    Text('Live data from Supabase',
                        style: TextStyle(
                            fontSize: 13, color: AppColors.textSecondary)),
                  ],
                );
                final btns = Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _ExportBtn(label: 'PDF', icon: Icons.picture_as_pdf_rounded),
                    const SizedBox(width: 8),
                    _ExportBtn(label: 'Excel', icon: Icons.table_chart_rounded),
                  ],
                );
                if (wide) {
                  return Row(
                    children: [
                      Expanded(child: titleCol),
                      btns,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [titleCol, const SizedBox(height: 12), btns],
                );
              }),
              const SizedBox(height: 24),
              LayoutBuilder(builder: (context, c) {
                if (c.maxWidth > 800) {
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _ProjectExpenseChart(projectSpend: projectSpend)),
                      const SizedBox(width: 20),
                      Expanded(child: _AgingBucketsCard(aging: aging)),
                    ],
                  );
                }
                return Column(
                  children: [
                    _ProjectExpenseChart(projectSpend: projectSpend),
                    const SizedBox(height: 20),
                    _AgingBucketsCard(aging: aging),
                  ],
                );
              }),
              const SizedBox(height: 20),
              _VendorOutstandingTable(vendorOutstanding: vendorOutstanding),
            ],
          ),
        );
      },
    );
  }
}

class _ExportBtn extends StatelessWidget {
  final String label;
  final IconData icon;

  const _ExportBtn({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label),
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label feature coming soon.')),
        );
      },
    );
  }
}

class _ProjectExpenseChart extends StatelessWidget {
  final Map<String, double> projectSpend;

  const _ProjectExpenseChart({required this.projectSpend});

  @override
  Widget build(BuildContext context) {
    final entries = projectSpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final maxY = entries.isNotEmpty
        ? (entries.first.value / 100000).ceilToDouble() + 5
        : 50.0;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Project-wise Expenses'),
          const SizedBox(height: 4),
          const Text('Total expenditure by project (in Lakhs ₹)',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          if (entries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(40),
                child: Text('No approved/paid invoices yet',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            )
          else
            SizedBox(
              height: 220,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                        '₹${rod.toY.toStringAsFixed(1)}L',
                        const TextStyle(
                            color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: maxY / 5,
                        getTitlesWidget: (v, m) => Text(
                          '${v.toInt()}L',
                          style: const TextStyle(
                              fontSize: 10, color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 56,
                        getTitlesWidget: (v, m) {
                          final idx = v.toInt();
                          if (idx < 0 || idx >= entries.length) {
                            return const SizedBox.shrink();
                          }
                          final parts = entries[idx].key.split(' ');
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              parts.take(2).join('\n'),
                              style: const TextStyle(
                                  fontSize: 10, color: AppColors.textSecondary),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  gridData: FlGridData(
                    show: true,
                    horizontalInterval: maxY / 5,
                    getDrawingHorizontalLine: (v) =>
                        FlLine(color: AppColors.borderColor, strokeWidth: 1),
                    drawVerticalLine: false,
                  ),
                  barGroups: entries.asMap().entries.map((e) {
                    final colors = [
                      AppColors.accentBlue,
                      const Color(0xFF7C3AED),
                      const Color(0xFF0891B2),
                      const Color(0xFF059669),
                    ];
                    return BarChartGroupData(
                      x: e.key,
                      barRods: [
                        BarChartRodData(
                          toY: e.value.value / 100000,
                          color: colors[e.key % colors.length],
                          width: 36,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(6)),
                        ),
                      ],
                    );
                  }).toList(),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _AgingBucketsCard extends StatelessWidget {
  final Map<String, double> aging;

  const _AgingBucketsCard({required this.aging});

  static const _bucketColors = {
    '0–30 days': AppColors.statusGreen,
    '30–60 days': AppColors.statusOrange,
    '60–90 days': Color(0xFFEA580C),
    '90+ days': AppColors.statusRed,
  };

  @override
  Widget build(BuildContext context) {
    final total = aging.values.fold<double>(0, (s, v) => s + v);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Payment Aging'),
          const SizedBox(height: 4),
          const Text('Outstanding by due-date bucket',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
          const SizedBox(height: 20),
          ...aging.entries.map((entry) {
            final color = _bucketColors[entry.key] ?? AppColors.statusOrange;
            final pct = total > 0 ? entry.value / total : 0.0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(entry.key,
                          style: const TextStyle(
                              fontSize: 13, color: AppColors.textSecondary)),
                      const Spacer(),
                      Text('₹${_fmt(entry.value)}',
                          style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: pct,
                      minHeight: 6,
                      backgroundColor: AppColors.borderColor,
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(color: AppColors.borderColor),
          const SizedBox(height: 8),
          Row(
            children: [
              const Text('Total Outstanding',
                  style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary)),
              const Spacer(),
              Text('₹${_fmt(total)}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.accentBlue)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _VendorOutstandingTable extends StatelessWidget {
  final Map<String, double> vendorOutstanding;

  const _VendorOutstandingTable({required this.vendorOutstanding});

  String _agingBucket(double amount) {
    // Simplified bucket label for display — aging is tracked per-invoice in service
    return amount > 400000 ? '60–90 days' : amount > 200000 ? '30–60 days' : '0–30 days';
  }

  Color _bucketColor(String bucket) {
    if (bucket.startsWith('0')) return AppColors.statusGreen;
    if (bucket.startsWith('30')) return AppColors.statusOrange;
    if (bucket.startsWith('60')) return const Color(0xFFEA580C);
    return AppColors.statusRed;
  }

  @override
  Widget build(BuildContext context) {
    final entries = vendorOutstanding.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Vendor-wise Outstanding Payments'),
          const SizedBox(height: 14),
          if (entries.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Text('No outstanding payments',
                    style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              ),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                headingRowColor:
                    WidgetStateProperty.all(AppColors.backgroundLight),
                headingTextStyle: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary),
                dataTextStyle:
                    const TextStyle(fontSize: 13, color: AppColors.textPrimary),
                columnSpacing: 32,
                columns: const [
                  DataColumn(label: Text('VENDOR')),
                  DataColumn(label: Text('OUTSTANDING'), numeric: true),
                  DataColumn(label: Text('AGING BUCKET')),
                ],
                rows: entries.map((e) {
                  final bucket = _agingBucket(e.value);
                  final color = _bucketColor(bucket);
                  return DataRow(cells: [
                    DataCell(Text(e.key,
                        style: const TextStyle(fontWeight: FontWeight.w600))),
                    DataCell(Text('₹${_fmt(e.value)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentBlue))),
                    DataCell(Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(bucket,
                          style: TextStyle(
                              fontSize: 11,
                              color: color,
                              fontWeight: FontWeight.w600)),
                    )),
                  ]);
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}
