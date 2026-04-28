import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/app_colors.dart';
import '../../core/models/invoice_model.dart' show InvoiceModel, InvoiceStatus, InvoiceLineItem, ApprovalStage, ApprovalStageStatus;
import '../../core/models/user_model.dart';
import '../../core/providers/app_state.dart';
import '../../core/services/expense_pdf_service.dart';
import '../../shared/widgets/approval_timeline.dart';
import '../../shared/widgets/comments_section.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/signature_pad.dart';
import '../../shared/widgets/status_badge.dart';

class InvoiceDetailScreen extends StatefulWidget {
  final String invoiceId;

  const InvoiceDetailScreen({super.key, required this.invoiceId});

  @override
  State<InvoiceDetailScreen> createState() => _InvoiceDetailScreenState();
}

class _InvoiceDetailScreenState extends State<InvoiceDetailScreen> {
  late Future<InvoiceModel?> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = context.read<AppState>().getInvoiceById(widget.invoiceId);
  }

  void _reload() => setState(() => _load());

  bool _hasBankDetails(InvoiceModel inv) =>
      (inv.bankAccountHolder?.isNotEmpty ?? false) ||
      (inv.bankAccountNumber?.isNotEmpty ?? false) ||
      (inv.bankName?.isNotEmpty ?? false) ||
      (inv.bankIfsc?.isNotEmpty ?? false);

  Future<void> _downloadExpense(BuildContext context, InvoiceModel inv) async {
    try {
      await ExpensePdfService.downloadExpense(inv);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download failed: $e'),
              backgroundColor: AppColors.statusRed),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = context.watch<AppState>().currentUser;

    return FutureBuilder<InvoiceModel?>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final inv = snapshot.data;
        if (inv == null) {
          return const Center(child: Text('Invoice not found.'));
        }

        // Determine if current user can take action on this invoice
        final role = currentUser?.role;
        final canAct =
            (role == UserRole.projectManager &&
                inv.status == InvoiceStatus.submitted) ||
            (role == UserRole.finance &&
                (inv.status == InvoiceStatus.pmApproved ||
                    inv.status == InvoiceStatus.approved ||
                    inv.status == InvoiceStatus.paymentInitiated));

        return SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: LayoutBuilder(builder: (context, c) {
            final wide = c.maxWidth > 800;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Download button row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Download Expense'),
                      onPressed: () => _downloadExpense(context, inv),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _HeaderCard(inv: inv),
                const SizedBox(height: 20),
                if (wide)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 3,
                        child: Column(children: [
                          _LineItemsCard(inv: inv),
                          const SizedBox(height: 20),
                          _TaxCard(inv: inv),
                          const SizedBox(height: 20),
                          if (_hasBankDetails(inv)) ...[
                            _BankDetailsCard(inv: inv),
                            const SizedBox(height: 20),
                          ],
                          CommentsSection(recordId: inv.id, recordType: 'invoice'),
                        ]),
                      ),
                      const SizedBox(width: 20),
                      Expanded(flex: 2, child: _RightColumn(inv: inv)),
                    ],
                  )
                else
                  Column(
                    children: [
                      _LineItemsCard(inv: inv),
                      const SizedBox(height: 20),
                      _TaxCard(inv: inv),
                      const SizedBox(height: 20),
                      if (_hasBankDetails(inv)) ...[
                        _BankDetailsCard(inv: inv),
                        const SizedBox(height: 20),
                      ],
                      _AttachmentsCard(inv: inv),
                      const SizedBox(height: 20),
                      _TimelineCard(inv: inv),
                      const SizedBox(height: 20),
                      CommentsSection(recordId: inv.id, recordType: 'invoice'),
                      if (canAct) ...[
                        const SizedBox(height: 20),
                        _ApprovalActions(inv: inv, onActioned: _reload),
                      ],
                    ],
                  ),
                if (wide && canAct) ...[
                  const SizedBox(height: 20),
                  _ApprovalActions(inv: inv, onActioned: _reload),
                ],
                const SizedBox(height: 40),
              ],
            );
          }),
        );
      },
    );
  }
}

class _RightColumn extends StatelessWidget {
  final InvoiceModel inv;

  const _RightColumn({required this.inv});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _AttachmentsCard(inv: inv),
        _TimelineCard(inv: inv),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final InvoiceModel inv;

  const _HeaderCard({required this.inv});

  @override
  Widget build(BuildContext context) {
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
          Row(
            children: [
              Expanded(
                child: Text(inv.invoiceNumber,
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary)),
              ),
              StatusBadge(status: inv.statusLabel),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderColor),
          const SizedBox(height: 12),
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              if (inv.noteType != null)
                _InfoPair(label: 'Note Type', value: inv.noteType!),
              if (inv.beneficiaryName != null)
                _InfoPair(label: 'Raised For', value: inv.beneficiaryName!),
              _InfoPair(label: 'Vendor', value: inv.vendorName),
              _InfoPair(label: 'Invoice Date', value: inv.date),
              _InfoPair(label: 'Due Date', value: inv.dueDate),
              _InfoPair(label: 'Project', value: inv.projectName),
              _InfoPair(
                  label: 'Total Amount',
                  value: '₹${_fmt(inv.total)}',
                  highlight: true),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: AppColors.borderColor),
          const SizedBox(height: 12),
          // People trail
          Wrap(
            spacing: 24,
            runSpacing: 10,
            children: [
              _InfoPair(
                label: 'Submitted By',
                value: inv.submittedByName,
                sub: inv.submittedByEmail,
                signatureUrl: inv.submitterSignatureUrl,
              ),
              if (inv.pmApprovedByName != null)
                _InfoPair(
                  label: 'PM Approved By',
                  value: inv.pmApprovedByName!,
                  iconColor: const Color(0xFF7C3AED),
                  signatureUrl: inv.pmSignatureUrl,
                ),
              if (inv.financeApprovedByName != null)
                _InfoPair(
                  label: 'Finance Approved By',
                  value: inv.financeApprovedByName!,
                  iconColor: AppColors.statusGreen,
                  signatureUrl: inv.financeSignatureUrl,
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _SignatureImage extends StatelessWidget {
  final String dataUri;
  const _SignatureImage({required this.dataUri});

  @override
  Widget build(BuildContext context) {
    try {
      const prefix = 'data:image/png;base64,';
      if (dataUri.startsWith(prefix)) {
        final bytes = base64Decode(dataUri.substring(prefix.length));
        return Image.memory(bytes, height: 48, width: 120, fit: BoxFit.contain);
      }
    } catch (_) {}
    return const SizedBox.shrink();
  }
}

class _InfoPair extends StatelessWidget {
  final String label;
  final String value;
  final String? sub;
  final bool highlight;
  final Color? iconColor;
  final String? signatureUrl;

  const _InfoPair({
    required this.label,
    required this.value,
    this.sub,
    this.highlight = false,
    this.iconColor,
    this.signatureUrl,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(),
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.6)),
        const SizedBox(height: 4),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (iconColor != null) ...[
              Icon(Icons.verified_rounded, size: 14, color: iconColor),
              const SizedBox(width: 4),
            ],
            Text(value,
                style: TextStyle(
                    fontSize: highlight ? 16 : 14,
                    fontWeight: FontWeight.w700,
                    color: highlight
                        ? AppColors.accentBlue
                        : iconColor ?? AppColors.textPrimary)),
          ],
        ),
        if (sub != null)
          Text(sub!,
              style: const TextStyle(
                  fontSize: 11, color: AppColors.textSecondary)),
        if (signatureUrl != null) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: _SignatureImage(dataUri: signatureUrl!),
          ),
        ],
      ],
    );
  }
}

class _LineItemsCard extends StatelessWidget {
  final InvoiceModel inv;

  const _LineItemsCard({required this.inv});

  @override
  Widget build(BuildContext context) {
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
          const SectionHeader(title: 'Line Items'),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor:
                  WidgetStateProperty.all(AppColors.backgroundLight),
              headingTextStyle: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textSecondary),
              dataTextStyle: const TextStyle(
                  fontSize: 13, color: AppColors.textPrimary),
              columnSpacing: 20,
              columns: const [
                DataColumn(label: Text('DESCRIPTION')),
                DataColumn(label: Text('UNIT')),
                DataColumn(label: Text('QTY'), numeric: true),
                DataColumn(label: Text('RATE (₹)'), numeric: true),
                DataColumn(label: Text('AMOUNT (₹)'), numeric: true),
              ],
              rows: inv.lineItems
                  .map((item) => DataRow(cells: [
                        DataCell(ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 200),
                          child: Text(item.description,
                              style: const TextStyle(fontSize: 13)),
                        )),
                        DataCell(Text(item.unit.isNotEmpty ? item.unit : '—',
                            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary))),
                        DataCell(Text('${item.qty}')),
                        DataCell(Text(_fmt(item.rate))),
                        DataCell(Text(_fmt(item.amount),
                            style: const TextStyle(
                                fontWeight: FontWeight.w600))),
                      ]))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _TaxCard extends StatelessWidget {
  final InvoiceModel inv;

  const _TaxCard({required this.inv});

  @override
  Widget build(BuildContext context) {
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
          const SectionHeader(title: 'Tax Breakdown'),
          const SizedBox(height: 14),
          _TaxRow(label: 'Subtotal', value: '₹${_fmt(inv.subtotal)}'),
          const Divider(color: AppColors.borderColor, height: 20),
          _TaxRow(
              label: 'GST @ ${inv.gstPercent.toInt()}%',
              value: '₹${_fmt(inv.gstAmount)}'),
          const Divider(color: AppColors.borderColor, height: 20),
          _TaxRow(
              label: 'Total Amount',
              value: '₹${_fmt(inv.total)}',
              bold: true,
              color: AppColors.accentBlue),
        ],
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _AttachmentsCard extends StatelessWidget {
  final InvoiceModel inv;
  const _AttachmentsCard({required this.inv});

  @override
  Widget build(BuildContext context) {
    final attachments = ((inv.data?['attachments']) as List?)?.cast<String>() ?? [];
    if (attachments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionHeader(title: 'Attachments'),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: attachments.map((url) => GestureDetector(
              onTap: () => _showFullImage(context, url),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  url,
                  width: 90,
                  height: 90,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    width: 90, height: 90,
                    color: AppColors.backgroundLight,
                    child: const Icon(Icons.broken_image_outlined, color: AppColors.textSecondary),
                  ),
                ),
              ),
            )).toList(),
          ),
        ],
      ),
    ),  // Container
    );  // Padding
  }

  void _showFullImage(BuildContext context, String url) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: Stack(
          children: [
            InteractiveViewer(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(url, fit: BoxFit.contain),
              ),
            ),
            Positioned(
              top: 8, right: 8,
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BankDetailsCard extends StatelessWidget {
  final InvoiceModel inv;
  const _BankDetailsCard({required this.inv});

  @override
  Widget build(BuildContext context) {
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
          const SectionHeader(title: 'Bank Details'),
          const SizedBox(height: 14),
          _bankRow('Account Holder', inv.bankAccountHolder),
          _bankRow('Account Number', inv.bankAccountNumber),
          _bankRow('Bank & Branch', inv.bankName),
          _bankRow('IFSC', inv.bankIfsc),
        ],
      ),
    );
  }

  Widget _bankRow(String label, String? value) {
    if (value == null || value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(label,
                style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }
}

class _TaxRow extends StatelessWidget {
  final String label;
  final String value;
  final bool bold;
  final Color? color;

  const _TaxRow(
      {required this.label,
      required this.value,
      this.bold = false,
      this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(label,
            style: TextStyle(
                fontSize: bold ? 15 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w400,
                color: AppColors.textSecondary)),
        const Spacer(),
        Text(value,
            style: TextStyle(
                fontSize: bold ? 16 : 13,
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                color: color ?? AppColors.textPrimary)),
      ],
    );
  }
}


class _TimelineCard extends StatelessWidget {
  final InvoiceModel inv;

  const _TimelineCard({required this.inv});

  List<ApprovalStage> _buildStages() {
    final s = inv.status;
    final isRejected = s == InvoiceStatus.rejected;
    // Was rejected before PM approved?
    final rejectedAtPm = isRejected && inv.pmApprovedByName == null;
    // Was rejected after PM but before Finance?
    final rejectedAtFinance = isRejected && inv.pmApprovedByName != null && inv.financeApprovedByName == null;

    return [
      ApprovalStage(
        stageName: 'Submission',
        personName: inv.submittedByName,
        role: 'Submitted By',
        status: ApprovalStageStatus.approved,
        timestamp: inv.date,
      ),
      ApprovalStage(
        stageName: 'PM Approval',
        personName: inv.pmApprovedByName ?? 'Project Manager',
        role: 'Project Manager',
        status: rejectedAtPm
            ? ApprovalStageStatus.rejected
            : (s == InvoiceStatus.submitted
                ? ApprovalStageStatus.pending
                : ApprovalStageStatus.approved),
        timestamp: inv.pmApprovedByName != null && !rejectedAtPm ? 'Approved' : null,
      ),
      ApprovalStage(
        stageName: 'Finance Approval',
        personName: inv.financeApprovedByName ?? 'Finance Admin',
        role: 'Finance',
        status: rejectedAtFinance
            ? ApprovalStageStatus.rejected
            : (s == InvoiceStatus.approved || s == InvoiceStatus.paid
                ? ApprovalStageStatus.approved
                : ApprovalStageStatus.pending),
        timestamp: inv.financeApprovedByName != null && !rejectedAtFinance ? 'Approved' : null,
      ),
      if (s == InvoiceStatus.paymentInitiated || s == InvoiceStatus.paid)
        ApprovalStage(
          stageName: 'Payment Initiated',
          personName: inv.financeApprovedByName ?? 'Finance',
          role: 'Finance',
          status: ApprovalStageStatus.approved,
          timestamp: 'Initiated',
        ),
      if (s == InvoiceStatus.paid)
        ApprovalStage(
          stageName: 'Payment Released',
          personName: inv.financeApprovedByName ?? 'Finance',
          role: 'Finance',
          status: ApprovalStageStatus.approved,
          timestamp: 'Paid',
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
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
          const SectionHeader(title: 'Approval Timeline'),
          const SizedBox(height: 16),
          ApprovalTimeline(stages: _buildStages()),
        ],
      ),
    );
  }
}

class _ApprovalActions extends StatelessWidget {
  final InvoiceModel inv;
  final VoidCallback onActioned;

  const _ApprovalActions({required this.inv, required this.onActioned});

  @override
  Widget build(BuildContext context) {
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
          Text(
            context.read<AppState>().currentRole == UserRole.projectManager
                ? 'PM Review Action'
                : 'Finance Action',
            style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary)),
          const SizedBox(height: 14),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text(context.read<AppState>().currentRole == UserRole.projectManager
                    ? 'Approve & Send to Finance'
                    : 'Final Approve'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.statusGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () async {
                  final sigBytes = await captureSignature(context,
                      title: 'Sign to Approve');
                  if (sigBytes == null || !context.mounted) return;
                  final appState = context.read<AppState>();
                  final role = appState.currentRole;
                  String? sigUrl;
                  try {
                    sigUrl = await appState.uploadSignatureBytes(
                        sigBytes, inv.id,
                        role == UserRole.projectManager ? 'pm' : 'finance');
                  } catch (_) {}
                  String msg;
                  if (role == UserRole.projectManager) {
                    await appState.updateInvoiceStatus(
                        inv.id, InvoiceStatus.pmApproved, UserRole.finance,
                        signatureUrl: sigUrl);
                    msg = 'Approved — sent to Finance for final approval.';
                  } else {
                    await appState.updateInvoiceStatus(
                        inv.id, InvoiceStatus.approved, UserRole.finance,
                        signatureUrl: sigUrl);
                    msg = 'Expense fully approved.';
                  }
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(msg),
                          backgroundColor: AppColors.statusGreen),
                    );
                    onActioned();
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.cancel_outlined, size: 18),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusRed,
                  side: const BorderSide(color: AppColors.statusRed),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () async {
                  await context.read<AppState>().updateInvoiceStatus(
                      inv.id, InvoiceStatus.rejected, UserRole.siteEngineer);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Invoice rejected.'), backgroundColor: AppColors.statusRed),
                    );
                    onActioned();
                  }
                },
              ),
              OutlinedButton.icon(
                icon: const Icon(Icons.reply_outlined, size: 18),
                label: const Text('Send Back'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.statusOrange,
                  side: const BorderSide(color: AppColors.statusOrange),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                ),
                onPressed: () async {
                  await context.read<AppState>().updateInvoiceStatus(
                      inv.id, InvoiceStatus.submitted, UserRole.projectManager);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Sent back for clarification.'), backgroundColor: AppColors.statusOrange),
                    );
                    onActioned();
                  }
                },
              ),
              // Finance: Initiate Payment after full approval
              if (context.read<AppState>().currentRole == UserRole.finance &&
                  inv.status == InvoiceStatus.approved)
                ElevatedButton.icon(
                  icon: const Icon(Icons.send_to_mobile_rounded, size: 18),
                  label: const Text('Initiate Payment'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF0891B2),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 14),
                  ),
                  onPressed: () =>
                      _initiatePayment(context, inv, onActioned),
                ),
              // Finance: Mark as Paid after payment initiated
              if (context.read<AppState>().currentRole == UserRole.finance &&
                  inv.status == InvoiceStatus.paymentInitiated)
                ElevatedButton.icon(
                  icon: const Icon(Icons.payments_outlined, size: 18),
                  label: const Text('Mark as Paid'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accentBlue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  ),
                  onPressed: () async {
                    final sigBytes = await captureSignature(context,
                        title: 'Sign to Confirm Payment');
                    if (sigBytes == null || !context.mounted) return;
                    final appState = context.read<AppState>();
                    String? sigUrl;
                    try {
                      sigUrl = await appState.uploadSignatureBytes(
                          sigBytes, inv.id, 'finance_paid');
                    } catch (_) {}
                    await appState.updateInvoiceStatus(
                        inv.id, InvoiceStatus.paid, UserRole.finance,
                        signatureUrl: sigUrl);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                            content: Text('Expense marked as Paid.'),
                            backgroundColor: AppColors.accentBlue),
                      );
                      onActioned();
                    }
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }
}

Future<void> _initiatePayment(
    BuildContext context, InvoiceModel inv, VoidCallback onActioned) async {
  final commentCtrl = TextEditingController();

  final confirmed = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => AlertDialog(
      title: const Text('Initiate Payment',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Enter the bank transaction / reference number to confirm payment initiation.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: commentCtrl,
            maxLines: 3,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Transaction / Reference Details *',
              hintText: 'e.g. NEFT/RTGS ref no., UTR, bank name…',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel',
              style: TextStyle(color: AppColors.textSecondary)),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0891B2),
              foregroundColor: Colors.white),
          onPressed: () {
            if (commentCtrl.text.trim().isEmpty) {
              ScaffoldMessenger.of(ctx).showSnackBar(
                const SnackBar(
                    content: Text('Transaction reference is required.')),
              );
              return;
            }
            Navigator.pop(ctx, true);
          },
          child: const Text('Confirm'),
        ),
      ],
    ),
  );

  if (confirmed != true || !context.mounted) return;

  final appState = context.read<AppState>();
  await appState.addComment(inv.id, 'invoice', commentCtrl.text.trim());
  await appState.updateInvoiceStatus(
      inv.id, InvoiceStatus.paymentInitiated, UserRole.finance);

  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Payment initiated successfully.'),
        backgroundColor: Color(0xFF0891B2),
      ),
    );
    onActioned();
  }
}
