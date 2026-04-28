import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/models/master_data_model.dart';
import '../../core/providers/app_state.dart';
import '../../shared/widgets/section_header.dart';

class ExpenseReportListScreen extends StatefulWidget {
  const ExpenseReportListScreen({super.key});

  @override
  State<ExpenseReportListScreen> createState() =>
      _ExpenseReportListScreenState();
}

class _ExpenseReportListScreenState extends State<ExpenseReportListScreen> {
  late Future<List<ExpenseReport>> _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    setState(() {
      _future = context.read<AppState>().getExpenseReports();
    });
  }

  Future<void> _createReport() async {
    final nameCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('New Expense Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              autofocus: true,
              decoration: const InputDecoration(labelText: 'Report Name *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: descCtrl,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Create')),
        ],
      ),
    );
    if (confirmed == true && nameCtrl.text.trim().isNotEmpty) {
      await context.read<AppState>().addExpenseReport(
            nameCtrl.text.trim(),
            description: descCtrl.text.trim(),
          );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Expense Reports',
            action: ElevatedButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('New Report'),
              onPressed: _createReport,
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<ExpenseReport>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final reports = snap.data ?? [];
                  if (reports.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.folder_open_rounded,
                              size: 48,
                              color: AppColors.textSecondary.withOpacity(0.4)),
                          const SizedBox(height: 12),
                          const Text('No expense reports yet.',
                              style:
                                  TextStyle(color: AppColors.textSecondary)),
                          const SizedBox(height: 12),
                          ElevatedButton(
                              onPressed: _createReport,
                              child: const Text('Create First Report')),
                        ],
                      ),
                    );
                  }
                  return LayoutBuilder(builder: (ctx, c) {
                    if (c.maxWidth > 700) {
                      return _GridView(reports: reports, onTap: _open);
                    }
                    return _ListView(reports: reports, onTap: _open);
                  });
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _open(ExpenseReport r) => context.push('/expense-reports/${r.id}');
}

class _GridView extends StatelessWidget {
  final List<ExpenseReport> reports;
  final void Function(ExpenseReport) onTap;
  const _GridView({required this.reports, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 320,
        mainAxisExtent: 140,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: reports.length,
      itemBuilder: (_, i) => _ReportCard(report: reports[i], onTap: onTap),
    );
  }
}

class _ListView extends StatelessWidget {
  final List<ExpenseReport> reports;
  final void Function(ExpenseReport) onTap;
  const _ListView({required this.reports, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      itemCount: reports.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, i) => _ReportCard(report: reports[i], onTap: onTap),
    );
  }
}

class _ReportCard extends StatelessWidget {
  final ExpenseReport report;
  final void Function(ExpenseReport) onTap;
  const _ReportCard({required this.report, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isOpen = report.status == 'open';
    return InkWell(
      onTap: () => onTap(report),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.accentBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder_rounded,
                      color: AppColors.accentBlue, size: 20),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    report.name,
                    style: const TextStyle(
                        fontSize: 14, fontWeight: FontWeight.w700),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: isOpen
                        ? AppColors.statusGreenBg
                        : AppColors.borderColor,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    report.statusLabel,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isOpen
                            ? AppColors.statusGreen
                            : AppColors.textSecondary),
                  ),
                ),
              ],
            ),
            if (report.description != null &&
                report.description!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                report.description!,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
            const Spacer(),
            Text(
              'By ${report.createdByName}',
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
