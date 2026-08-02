import 'package:flutter/material.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_radius.dart';

enum JkddStatusTone { success, info, warning, danger, neutral }

final class JkddStatusChip extends StatelessWidget {
  const JkddStatusChip({
    super.key,
    required this.label,
    required this.icon,
    required this.tone,
  });

  final String label;
  final IconData icon;
  final JkddStatusTone tone;

  @override
  Widget build(BuildContext context) {
    final colors = _colors(tone);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.$1,
        borderRadius: BorderRadius.circular(AppRadius.sm),
        border: Border.all(color: colors.$2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.$3),
          const SizedBox(width: 6),
          Text(
            label,
            style: Theme.of(context)
                .textTheme
                .labelLarge
                ?.copyWith(color: colors.$3),
          ),
        ],
      ),
    );
  }

  (Color, Color, Color) _colors(JkddStatusTone tone) => switch (tone) {
        JkddStatusTone.success => (
            AppColors.successSoft,
            const Color(0xff86efac),
            const Color(0xff166534),
          ),
        JkddStatusTone.info => (
            AppColors.infoSoft,
            const Color(0xff93c5fd),
            AppColors.blue,
          ),
        JkddStatusTone.warning => (
            AppColors.warningSoft,
            const Color(0xfffed7aa),
            const Color(0xff9a3412),
          ),
        JkddStatusTone.danger => (
            AppColors.dangerSoft,
            const Color(0xfffca5a5),
            AppColors.red,
          ),
        JkddStatusTone.neutral => (
            const Color(0xfff1f5f9),
            AppColors.lightGray,
            AppColors.gray,
          ),
      };
}
