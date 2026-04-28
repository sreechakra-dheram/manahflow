import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/models/invoice_model.dart';
import '../../core/models/master_data_model.dart';
import '../../core/providers/app_state.dart';
import '../../shared/widgets/status_badge.dart';

class ExpenseReportDetailScreen extends StatefulWidget {
  final String reportId;
  const ExpenseReportDetailScreen({super.key, required this.reportId});

  @override
  State<ExpenseReportDetailScreen> createState() =>
      _ExpenseReportDetailScreenState();
}

class _ExpenseReportDetailScreenState
    extends State<ExpenseReportDetailScreen> {
  ExpenseReport? _report;
  List<InvoiceModel> _invoices = [];
  bool _loading = true;
  String? _error;
  final Set<String> _expanded = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final appState = context.read<AppState>();
      final results = await Future.wait([
        appState.getExpenseReportById(widget.reportId),
        appState.getInvoicesByReport(widget.reportId),
      ]);
      setState(() {
        _report = results[0] as ExpenseReport?;
        _invoices = results[1] as List<InvoiceModel>;
        _loading = false;
      });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Error: $_error'),
              ElevatedButton(onPressed: _load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final report = _report;
    if (report == null) {
      return const Scaffold(body: Center(child: Text('Report not found.')));
    }

    final total = _invoices.fold<double>(0, (s, inv) => s + inv.total);

    return Scaffold(
      appBar: AppBar(
        title: Text(report.name, overflow: TextOverflow.ellipsis),
        leading: BackButton(onPressed: () => context.pop()),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: report.status == 'open'
                  ? AppColors.statusGreenBg
                  : AppColors.borderColor,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              report.statusLabel,
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: report.status == 'open'
                      ? AppColors.statusGreen
                      : AppColors.textSecondary),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: CustomScrollView(
          slivers: [
            // Summary bar
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: Row(
                  children: [
                    _StatChip(
                      label: 'Expenses',
                      value: '${_invoices.length}',
                      icon: Icons.receipt_long_rounded,
                    ),
                    const SizedBox(width: 24),
                    _StatChip(
                      label: 'Total Amount',
                      value: '₹${_fmt(total)}',
                      icon: Icons.currency_rupee_rounded,
                      highlight: true,
                    ),
                    if (report.description != null &&
                        report.description!.isNotEmpty) ...[
                      const SizedBox(width: 24),
                      Expanded(
                        child: Text(
                          report.description!,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Expense list
            if (_invoices.isEmpty)
              const SliverFillRemaining(
                child: Center(
                  child: Text(
                    'No expenses linked to this report.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      final inv = _invoices[i];
                      final isExpanded = _expanded.contains(inv.id);
                      return _ExpenseAccordion(
                        invoice: inv,
                        isExpanded: isExpanded,
                        onToggle: () => setState(() {
                          if (isExpanded) {
                            _expanded.remove(inv.id);
                          } else {
                            _expanded.add(inv.id);
                          }
                        }),
                        onOpen: () => context.push('/invoices/${inv.id}'),
                      );
                    },
                    childCount: _invoices.length,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool highlight;

  const _StatChip({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon,
            size: 18,
            color: highlight ? AppColors.accentBlue : AppColors.textSecondary),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondary)),
            Text(value,
                style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: highlight
                        ? AppColors.accentBlue
                        : AppColors.textPrimary)),
          ],
        ),
      ],
    );
  }
}

class _ExpenseAccordion extends StatelessWidget {
  final InvoiceModel invoice;
  final bool isExpanded;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  const _ExpenseAccordion({
    required this.invoice,
    required this.isExpanded,
    required this.onToggle,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? AppColors.accentBlue.withOpacity(0.4) : AppColors.borderColor,
        ),
      ),
      child: Column(
        children: [
          // Header row — always visible
          InkWell(
            onTap: onToggle,
            borderRadius: isExpanded
                ? const BorderRadius.vertical(top: Radius.circular(12))
                : BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.accentBlue, size: 18),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          invoice.vendorName,
                          style: const TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          invoice.projectName,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: invoice.statusLabel, small: true),
                      const SizedBox(height: 4),
                      Text(
                        '₹${_fmt(invoice.total)}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    isExpanded
                        ? Icons.keyboard_arrow_up_rounded
                        : Icons.keyboard_arrow_down_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          // Expanded detail
          if (isExpanded) ...[
            const Divider(height: 1, color: AppColors.borderColor),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Column(
                children: [
                  _Row('Submitted By', invoice.submittedByName),
                  _Row('Expense Type', invoice.noteType ?? 'Material Purchase'),
                  _Row('Date', invoice.date),
                  _Row('Due Date', invoice.dueDate),
                  _Row('Site', invoice.data?['site_name'] ?? '—'),
                  _Row('Invoice No', invoice.invoiceNumber),
                  if (invoice.pmApprovedByName != null)
                    _Row('PM Approved By', invoice.pmApprovedByName!),
                  if (invoice.financeApprovedByName != null)
                    _Row('Finance Approved By', invoice.financeApprovedByName!),
                  const SizedBox(height: 4),
                  // Line items summary
                  if (invoice.lineItems.isNotEmpty) ...[
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text('Items',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary)),
                    ),
                    const SizedBox(height: 4),
                    ...invoice.lineItems.map((item) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Expanded(
                                  child: Text(item.description,
                                      style:
                                          const TextStyle(fontSize: 12))),
                              Text(
                                '₹${_fmt(item.amount)}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        )),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  icon: const Icon(Icons.open_in_new_rounded, size: 14),
                  label: const Text('View Full Detail'),
                  onPressed: onOpen,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _fmt(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},');
}

class _Row extends StatelessWidget {
  final String label;
  final String value;
  const _Row(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}
