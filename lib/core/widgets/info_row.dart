import 'package:flutter/material.dart';
import '../constants/app_theme.dart';

class InfoRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;

  const InfoRow({
    super.key,
    this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 16, color: AppTheme.textSecondary),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: icon != null ? null : 120,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
