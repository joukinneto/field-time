import 'package:flutter/material.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_typography.dart';

abstract final class JkddFieldTypography {
  static TextTheme textTheme(Brightness brightness) =>
      AppTypography.textTheme(brightness);
}
