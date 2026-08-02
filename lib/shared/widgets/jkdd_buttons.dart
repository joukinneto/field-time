import 'package:flutter/material.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_radius.dart';

final class JkddPrimaryButton extends StatelessWidget {
  const JkddPrimaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.loading = false,
    this.critical = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool critical;

  @override
  Widget build(BuildContext context) {
    final background = critical ? AppColors.red : AppColors.green;
    return FilledButton.icon(
      onPressed: loading ? null : onPressed,
      icon: loading
          ? const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : Icon(icon),
      label: Text(label),
      style: FilledButton.styleFrom(
        backgroundColor: background,
        foregroundColor: AppColors.white,
        disabledBackgroundColor: AppColors.lightGray,
        disabledForegroundColor: AppColors.gray,
        minimumSize: const Size.fromHeight(56),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
    );
  }
}

final class JkddSecondaryButton extends StatelessWidget {
  const JkddSecondaryButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon),
      label: Text(label, textAlign: TextAlign.center),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.blue,
        disabledForegroundColor: AppColors.gray,
        side: BorderSide(color: enabled ? AppColors.blue : AppColors.lightGray),
        minimumSize: const Size.fromHeight(52),
      ),
    );
  }
}
