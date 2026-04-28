import 'package:flutter/material.dart';
import '../../core/app_colors.dart';
import '../../core/models/invoice_model.dart';
import '../../shared/widgets/approval_timeline.dart';
import '../../shared/widgets/section_header.dart';
import '../../shared/widgets/status_badge.dart';

class ApprovalWorkflowScreen extends StatelessWidget {
  final String invoiceId;

  const ApprovalWorkflowScreen({super.key, required this.invoiceId});

  @override
  Widget build(BuildContext context) {
    final inv = kInvoices.firstWhere(
      (i) => i.id == invoiceId,
      orElse: () => kInvoices.first,
    );

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invoice summary card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.receipt_long_rounded,
                        color: AppColors.accentBlue, size: 28),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(inv.invoiceNumber,
                            style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary)),
                        const SizedBox(height: 4),
                        Text(inv.vendorName,
                            style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary)),
                        const SizedBox(height: 4),
                        Text(inv.projectName,
                            style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      StatusBadge(status: inv.statusLabel),
                      const SizedBox(height: 8),
                      Text(
                        'Rs. ${_fmt(inv.total)}',
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.accentBlue),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Progress summary
            _ProgressBar(stages: inv.approvalStages),
            const SizedBox(height: 24),
            // Full timeline
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Approval Chain'),
                  const SizedBox(height: 6),
                  Text(
                    'Each stage must be approved before proceeding to the next.',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  ApprovalTimeline(stages: inv.approvalStages),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  String _fmt(double v) => v.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
}

class _ProgressBar extends StatelessWidget {
  final List<ApprovalStage> stages;

  const _ProgressBar({required this.stages});

  @override
  Widget build(BuildContext context) {
    final approved =
        stages.where((s) => s.status == ApprovalStageStatus.approved).length;
    final total = stages.length;
    final pct = approved / total;

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
              Text(
                'Progress: $approved of $total stages approved',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary),
              ),
              const Spacer(),
              Text(
                '${(pct * 100).toInt()}%',
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentBlue),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: pct,
              minHeight: 10,
              backgroundColor: AppColors.borderColor,
              valueColor: const AlwaysStoppedAnimation(AppColors.accentBlue),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: stages.map((s) {
              Color c;
              switch (s.status) {
                case ApprovalStageStatus.approved:
                  c = AppColors.statusGreen;
                  break;
                case ApprovalStageStatus.rejected:
                  c = AppColors.statusRed;
                  break;
                case ApprovalStageStatus.pending:
                  c = AppColors.textSecondary;
                  break;
              }
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: c.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(s.stageName,
                    style: TextStyle(
                        fontSize: 11,
                        color: c,
                        fontWeight: FontWeight.w600)),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
