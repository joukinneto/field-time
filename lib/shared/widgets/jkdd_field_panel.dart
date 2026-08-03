import 'package:flutter/material.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_spacing.dart';

final class JkddFieldPanel extends StatelessWidget {
  const JkddFieldPanel({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: padding ?? const EdgeInsets.all(AppSpacing.lg),
          child: child,
        ),
      );
}
