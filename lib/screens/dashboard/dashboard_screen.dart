import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/models/user_model.dart';
import '../../core/providers/app_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badge.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _refreshKey = 0;

  Future<void> _reload() async {
    setState(() => _refreshKey++);
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AppState>().currentUser;
    final role = user?.role ?? UserRole.siteEngineer;

    return RefreshIndicator(
      onRefresh: _reload,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(user: user),
            const SizedBox(height: 24),

            _KpiGrid(role: role, refreshKey: _refreshKey),
            const SizedBox(height: 28),

            if (role == UserRole.finance || role == UserRole.projectManager) ...[
              const SectionHeader(title: 'Attention Required'),
              const SizedBox(height: 12),
              _AttentionRequiredList(),
              const SizedBox(height: 28),
            ],

            LayoutBuilder(builder: (context, c) {
              if (c.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 3, child: _SpendingTrend(refreshKey: _refreshKey)),
                    const SizedBox(width: 20),
                    Expanded(flex: 2, child: _TopProjects(refreshKey: _refreshKey)),
                  ],
                );
              }
              return Column(
                children: [
                  _SpendingTrend(refreshKey: _refreshKey),
                  const SizedBox(height: 20),
                  _TopProjects(refreshKey: _refreshKey),
                ],
              );
            }),

            const SizedBox(height: 28),
            const SectionHeader(title: 'Recent Activity'),
            const SizedBox(height: 12),
            _RecentActivityTable(refreshKey: _refreshKey),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final UserModel? user;
  const _Header({this.user});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dashboard',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Overview of ${user?.roleDisplayName ?? "User"} activity',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        _DateRangePicker(),
      ],
    );
  }
}

class _DateRangePicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Row(
        children: [
          const Icon(Icons.calendar_today_outlined, size: 14, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Text('Last 30 Days', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          const SizedBox(width: 4),
          const Icon(Icons.keyboard_arrow_down_rounded, size: 16, color: AppColors.textSecondary),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  final UserRole role;
  final int refreshKey;
  const _KpiGrid({required this.role, required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(refreshKey),
      future: context.read<AppState>().getDashboardStats(),
      builder: (context, snapshot) {
        final stats = snapshot.data;
        final totalPaid = (stats?['totalPaid'] as num?)?.toDouble() ?? 0.0;
        final pendingCount = stats?['pendingCount'] ?? 0;
        final approvedCount = stats?['approvedCount'] ?? 0;

        return LayoutBuilder(builder: (context, c) {
          final crossCount = c.maxWidth > 1000 ? 4 : (c.maxWidth > 600 ? 2 : 1);
          return GridView.count(
            crossAxisCount: crossCount,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 2.2,
            children: [
              _ZohoKpiCard(
                label: 'PENDING APPROVAL',
                value: '$pendingCount',
                color: const Color(0xFFF59E0B),
                icon: Icons.hourglass_empty_rounded,
              ),
              _ZohoKpiCard(
                label: 'APPROVED',
                value: '$approvedCount',
                color: const Color(0xFF10B981),
                icon: Icons.check_circle_outline_rounded,
              ),
              _ZohoKpiCard(
                label: 'TOTAL REIMBURSED',
                value: '₹${(totalPaid / 100000).toStringAsFixed(1)}L',
                color: const Color(0xFF6366F1),
                icon: Icons.account_balance_wallet_outlined,
              ),
              _ZohoKpiCard(
                label: 'OVERDUE INVOICES',
                value: '${(snapshot.data?['overdueCount'] ?? 0)}',
                color: const Color(0xFFEF4444),
                icon: Icons.receipt_long_outlined,
              ),
            ],
          );
        });
      },
    );
  }
}

class _ZohoKpiCard extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _ZohoKpiCard({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border(left: BorderSide(color: color, width: 4)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey.shade500, letterSpacing: 0.5)),
                const SizedBox(height: 6),
                Text(value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textPrimary)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(icon, color: color, size: 20),
          ),
        ],
      ),
    );
  }
}

class _AttentionRequiredList extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        children: [
          _AttentionTile(
            title: 'Invoices Pending Approval',
            sub: 'Review and action submitted invoices',
            icon: Icons.pending_actions_rounded,
            color: Colors.orange,
            onTap: () => context.go('/invoices'),
          ),
          const Divider(height: 1, indent: 60),
          _AttentionTile(
            title: 'Overdue Invoices',
            sub: 'Past due date — action required',
            icon: Icons.warning_amber_rounded,
            color: Colors.red,
            onTap: () => context.go('/invoices'),
          ),
        ],
      ),
    );
  }
}

class _AttentionTile extends StatelessWidget {
  final String title;
  final String sub;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _AttentionTile({required this.title, required this.sub, required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
        child: Icon(icon, color: color, size: 20),
      ),
      title: Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
      subtitle: Text(sub, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textSecondary),
    );
  }
}

class _SpendingTrend extends StatelessWidget {
  final int refreshKey;
  const _SpendingTrend({required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(refreshKey),
      future: context.read<AppState>().getMonthlySpend(),
      builder: (context, snapshot) {
        final months = (snapshot.data?['months'] as List?)?.cast<String>() ??
            ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
        final rawValues = (snapshot.data?['values'] as List?)?.cast<double>() ??
            List.filled(6, 0.0);

        // Convert to thousands for display
        final values = rawValues.map((v) => v / 1000).toList();
        final maxY = values.isEmpty ? 10.0 : (values.reduce((a, b) => a > b ? a : b) * 1.3).ceilToDouble();
        final effectiveMax = maxY < 1 ? 10.0 : maxY;

        final spots = List.generate(
          values.length,
          (i) => FlSpot(i.toDouble(), values[i]),
        );

        // Total spend for subtitle
        final totalK = rawValues.fold(0.0, (s, v) => s + v);
        final totalLabel = totalK >= 100000
            ? '₹${(totalK / 100000).toStringAsFixed(1)}L total'
            : '₹${(totalK / 1000).toStringAsFixed(1)}K total';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text('Spend Summary',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  ),
                  if (snapshot.hasData)
                    Text(totalLabel,
                        style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.accentBlue)),
                ],
              ),
              const SizedBox(height: 4),
              const Text('Last 6 months invoice spend',
                  style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 20),
              SizedBox(
                height: 220,
                child: snapshot.connectionState == ConnectionState.waiting
                    ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                    : LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            getDrawingHorizontalLine: (v) =>
                                FlLine(color: Colors.grey.withOpacity(0.1), strokeWidth: 1),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                getTitlesWidget: (v, m) {
                                  final i = v.toInt();
                                  if (i < 0 || i >= months.length) return const SizedBox.shrink();
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(months[i],
                                        style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 36,
                                getTitlesWidget: (v, m) => Text(
                                  v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}M' : '${v.toInt()}K',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                                ),
                              ),
                            ),
                          ),
                          minY: 0,
                          maxY: effectiveMax,
                          borderData: FlBorderData(show: false),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              getTooltipItems: (spots) => spots
                                  .map((s) => LineTooltipItem(
                                        '₹${(s.y * 1000 >= 100000 ? '${(s.y / 100).toStringAsFixed(1)}L' : '${s.y.toStringAsFixed(1)}K')}',
                                        const TextStyle(
                                            color: Colors.white, fontWeight: FontWeight.w600),
                                      ))
                                  .toList(),
                            ),
                          ),
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              color: AppColors.primaryBlue,
                              barWidth: 3,
                              isStrokeCapRound: true,
                              dotData: FlDotData(
                                show: true,
                                getDotPainter: (spot, _, __, ___) => FlDotCirclePainter(
                                  radius: 3,
                                  color: AppColors.primaryBlue,
                                  strokeWidth: 2,
                                  strokeColor: Colors.white,
                                ),
                              ),
                              belowBarData: BarAreaData(
                                show: true,
                                color: AppColors.primaryBlue.withOpacity(0.07),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopProjects extends StatelessWidget {
  final int refreshKey;
  const _TopProjects({required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(refreshKey),
      future: context.read<AppState>().getDashboardStats(),
      builder: (context, snapshot) {
        final projectSpend = snapshot.data?['projectSpend'] as Map<String, double>? ?? {};
        final sortedProjects = projectSpend.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));
        
        final maxSpend = sortedProjects.isNotEmpty ? sortedProjects.first.value : 1.0;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Top Projects by Spend', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 20),
              if (sortedProjects.isEmpty)
                const Center(child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Text('No project data available', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                ))
              else
                ...sortedProjects.take(4).map((e) => _ProjectSpendItem(
                  name: e.key,
                  amount: '₹${(e.value / 1000).toStringAsFixed(1)}k',
                  progress: e.value / maxSpend,
                  color: AppColors.accentBlue,
                )),
            ],
          ),
        );
      },
    );
  }
}

class _ProjectSpendItem extends StatelessWidget {
  final String name;
  final String amount;
  final double progress;
  final Color color;

  const _ProjectSpendItem({required this.name, required this.amount, required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(value: progress, backgroundColor: color.withOpacity(0.1), color: color, minHeight: 6, borderRadius: BorderRadius.circular(10)),
        ],
      ),
    );
  }
}

class _RecentActivityTable extends StatelessWidget {
  final int refreshKey;
  const _RecentActivityTable({required this.refreshKey});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>>(
      key: ValueKey(refreshKey),
      future: context.read<AppState>().getDashboardStats(),
      builder: (context, snapshot) {
        final activities = snapshot.data?['recentActivity'] as List? ?? [];

        return Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(Colors.grey.shade50),
              horizontalMargin: 20,
              columns: const [
                DataColumn(label: Text('DATE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('TRANSACTION', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('STATUS', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
                DataColumn(label: Text('AMOUNT', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700))),
              ],
              rows: activities.map((a) {
                final isInvoice = a['type'] == 'invoice';
                final dateStr = a['created_at'].toString().split('T').first;
                final title = a['vendor_name'] ?? a['project_name'] ?? 'Invoice';
                final status = a['status'] ?? 'submitted';
                final amount = '₹${a['subtotal'] ?? 0}';
                
                Color statusColor = Colors.blue;
                if (status == 'paid' || status == 'approved') statusColor = Colors.green;
                if (status == 'rejected') statusColor = Colors.red;
                if (status == 'submitted') statusColor = Colors.orange;

                return _dataRow(dateStr, title, status, amount, statusColor);
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  DataRow _dataRow(String date, String title, String status, String amount, Color color) {
    return DataRow(cells: [
      DataCell(Text(date, style: const TextStyle(fontSize: 13))),
      DataCell(Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
      DataCell(StatusBadge(status: status, small: true)),
      DataCell(Text(amount, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]);
  }
}
