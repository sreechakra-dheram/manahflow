import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/models/invoice_model.dart';
import '../../core/providers/app_state.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badge.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  String _search = '';
  InvoiceStatus? _filterStatus;
  late Future<List<InvoiceModel>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().getInvoices();
  }

  void _reload() => setState(() {
    _future = context.read<AppState>().getInvoices();
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Expenses',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.document_scanner_rounded, size: 16),
                  label: const Text('Scan'),
                  onPressed: () => context.push('/scan'),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text('New Expense'),
                  onPressed: () => context.push('/invoices/new').then((_) => _reload()),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          // Search + filter
          Row(
            children: [
              Expanded(
                child: TextField(
                  onChanged: (v) => setState(() => _search = v),
                  decoration: const InputDecoration(
                    hintText: 'Search vendor or project…',
                    prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.borderColor),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<InvoiceStatus?>(
                    value: _filterStatus,
                    hint: const Text('All Status', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('All Status')),
                      ...InvoiceStatus.values.map(
                        (s) => DropdownMenuItem(
                          value: s,
                          child: Text(s.name[0].toUpperCase() + s.name.substring(1)),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _filterStatus = v),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _reload(),
              child: FutureBuilder<List<InvoiceModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 40, color: Colors.red),
                        const SizedBox(height: 12),
                        Text('Error: ${snapshot.error}', textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _reload, child: const Text('Retry')),
                      ],
                    ),
                  );
                }
                final invoices = snapshot.data ?? [];
                final filtered = invoices.where((inv) {
                  final matchSearch = _search.isEmpty ||
                      inv.vendorName.toLowerCase().contains(_search.toLowerCase()) ||
                      inv.projectName.toLowerCase().contains(_search.toLowerCase());
                  final matchStatus = _filterStatus == null || inv.status == _filterStatus;
                  return matchSearch && matchStatus;
                }).toList();

                if (filtered.isEmpty) {
                  return const Center(child: Text('No invoices found.'));
                }

                return ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final inv = filtered[i];
                    return _InvoiceCard(
                      invoice: inv,
                      onTap: () => context.push('/invoices/${inv.id}'),
                    );
                  },
                );
              },
            ),
            ), // RefreshIndicator
          ),
        ],
      ),
    );
  }
}

class _InvoiceCard extends StatelessWidget {
  final InvoiceModel invoice;
  final VoidCallback onTap;

  const _InvoiceCard({required this.invoice, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.accentBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.receipt_long_rounded, color: AppColors.accentBlue, size: 22),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    invoice.vendorName,
                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Project: ${invoice.projectName}',
                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.textSecondary),
                      const SizedBox(width: 4),
                      Text(invoice.date, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                StatusBadge(status: invoice.statusLabel),
                const SizedBox(height: 4),
                Text(
                  'Rs. ${(invoice.total / 100000).toStringAsFixed(1)}L',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                ),
              ],
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}
