import 'package:flutter/material.dart';
import '../../core/models/invoice_model.dart';
import '../../core/app_colors.dart';

class ApprovalTimeline extends StatelessWidget {
  final List<ApprovalStage> stages;

  const ApprovalTimeline({super.key, required this.stages});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(stages.length, (i) {
        final stage = stages[i];
        final isLast = i == stages.length - 1;
        final isPending = stage.status == ApprovalStageStatus.pending;
        final isApproved = stage.status == ApprovalStageStatus.approved;
        final isRejected = stage.status == ApprovalStageStatus.rejected;
        // active = first pending stage
        final isActive = isPending &&
            stages.sublist(0, i).every((s) => s.status == ApprovalStageStatus.approved);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // timeline column
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    _StepDot(
                      isApproved: isApproved,
                      isRejected: isRejected,
                      isActive: isActive,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: isApproved
                              ? AppColors.statusGreen
                              : AppColors.borderColor,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // content
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(bottom: isLast ? 0 : 20),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isActive
                          ? AppColors.accentBlue.withOpacity(0.04)
                          : AppColors.backgroundLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isActive
                            ? AppColors.accentBlue.withOpacity(0.3)
                            : AppColors.borderColor,
                        width: isActive ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              stage.stageName,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                                color: isActive
                                    ? AppColors.accentBlue
                                    : AppColors.textPrimary,
                              ),
                            ),
                            const Spacer(),
                            _statusChip(stage.status),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${stage.personName} · ${stage.role}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        if (stage.timestamp != null) ...[
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.access_time_rounded,
                                  size: 12, color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                stage.timestamp!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (stage.remark != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            stage.remark!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _statusChip(ApprovalStageStatus status) {
    String label;
    Color color;
    switch (status) {
      case ApprovalStageStatus.approved:
        label = 'Approved';
        color = AppColors.statusGreen;
        break;
      case ApprovalStageStatus.rejected:
        label = 'Rejected';
        color = AppColors.statusRed;
        break;
      case ApprovalStageStatus.pending:
        label = 'Pending';
        color = AppColors.statusOrange;
        break;
    }
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      ),
    );
  }
}

class _StepDot extends StatefulWidget {
  final bool isApproved;
  final bool isRejected;
  final bool isActive;

  const _StepDot({
    required this.isApproved,
    required this.isRejected,
    required this.isActive,
  });

  @override
  State<_StepDot> createState() => _StepDotState();
}

class _StepDotState extends State<_StepDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _pulse = Tween<double>(begin: 1.0, end: 1.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    if (widget.isActive) {
      _ctrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color color;
    Widget icon;
    if (widget.isApproved) {
      color = AppColors.statusGreen;
      icon = const Icon(Icons.check, size: 14, color: Colors.white);
    } else if (widget.isRejected) {
      color = AppColors.statusRed;
      icon = const Icon(Icons.close, size: 14, color: Colors.white);
    } else if (widget.isActive) {
      color = AppColors.accentBlue;
      icon = const SizedBox(
        width: 8,
        height: 8,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: Colors.white,
        ),
      );
    } else {
      color = AppColors.borderColor;
      icon = const SizedBox.shrink();
    }

    if (widget.isActive) {
      return AnimatedBuilder(
        animation: _pulse,
        builder: (_, __) => Transform.scale(
          scale: _pulse.value,
          child: _dot(color, icon),
        ),
      );
    }
    return _dot(color, icon);
  }

  Widget _dot(Color color, Widget icon) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: AppColors.accentBlue.withOpacity(0.4),
                  blurRadius: 8,
                  spreadRadius: 2,
                ),
              ]
            : null,
      ),
      child: Center(child: icon),
    );
  }
}
