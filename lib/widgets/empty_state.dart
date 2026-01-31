import 'package:flutter/material.dart';
import '../config/theme.dart';

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;

  const EmptyState({
    super.key,
    this.message = 'No Items Found',
    this.icon = Icons.folder_open_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppTheme.textTertiary.withOpacity(0.5),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: const TextStyle(
              fontSize: 17,
              color: AppTheme.textTertiary,
              fontWeight: FontWeight.w400,
              letterSpacing: -0.2,
            ),
          ),
        ],
      ),
    );
  }
}
