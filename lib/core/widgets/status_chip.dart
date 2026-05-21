import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class StatusChip extends StatelessWidget {
  final String label;
  final Color? color;

  const StatusChip({
    super.key,
    required this.label,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final Color chipColor = color ?? _defaultColor;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: chipColor.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: chipColor,
        ),
      ),
    );
  }

  Color get _defaultColor {
    switch (label.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'approved':
        return AppTheme.success;
      case 'rejected':
      case 'archived':
        return AppTheme.error;
      default:
        return AppTheme.textSecondary;
    }
  }
}
