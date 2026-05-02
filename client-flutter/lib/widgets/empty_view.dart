import 'package:flutter/material.dart';
import '../config/app_colors.dart';

class EmptyView extends StatelessWidget {
  final String? message;
  final String? title;
  final String? subtitle;
  final IconData? icon;

  const EmptyView({
    super.key,
    this.message,
    this.title,
    this.subtitle,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null)
              Icon(icon, color: AppColors.muted.withOpacity(0.5), size: 48),
            if (icon != null) const SizedBox(height: 16),
            if (title != null)
              Text(
                title!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            if (title != null && (subtitle != null || message != null))
              const SizedBox(height: 8),
            if (subtitle != null || message != null)
              Text(
                subtitle ?? message ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AppColors.muted,
                  fontSize: 14,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
