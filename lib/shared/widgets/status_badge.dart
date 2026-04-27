import 'package:flutter/material.dart';
import '../../core/app_colors.dart';

class StatusBadge extends StatelessWidget {
  final String status;
  final bool small;

  const StatusBadge({super.key, required this.status, this.small = false});

  Color get _fg {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.statusGreen;
      case 'paid':
        return AppColors.statusBlue;
      case 'rejected':
        return AppColors.statusRed;
      case 'pending':
      case 'submitted':
        return AppColors.statusOrange;
      case 'pmapproved':
      case 'pm approved':
        return const Color(0xFF7C3AED);
      case 'paymentinitiated':
      case 'payment initiated':
        return const Color(0xFF0891B2);
      default:
        return Colors.grey.shade700;
    }
  }

  Color get _bg {
    switch (status.toLowerCase()) {
      case 'approved':
        return AppColors.statusGreenBg;
      case 'paid':
        return AppColors.statusBlueBg;
      case 'rejected':
        return AppColors.statusRedBg;
      case 'pending':
      case 'submitted':
        return AppColors.statusOrangeBg;
      case 'pmapproved':
      case 'pm approved':
        return const Color(0xFFF3E8FF);
      case 'paymentinitiated':
      case 'payment initiated':
        return const Color(0xFFE0F2FE);
      default:
        return Colors.grey.shade100;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: small ? 8 : 10,
        vertical: small ? 3 : 5,
      ),
      decoration: BoxDecoration(
        color: _bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status,
        style: TextStyle(
          color: _fg,
          fontSize: small ? 11 : 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}
