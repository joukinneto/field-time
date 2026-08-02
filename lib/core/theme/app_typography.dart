import 'package:flutter/material.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';

abstract final class AppTypography {
  static TextTheme textTheme(Brightness brightness) {
    final color =
        brightness == Brightness.dark ? AppColors.white : AppColors.navy;
    return TextTheme(
      headlineLarge: TextStyle(
        color: color,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'Arial'],
        fontSize: 28,
        fontWeight: FontWeight.w800,
        height: 1.08,
      ),
      headlineMedium: TextStyle(
        color: color,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'Arial'],
        fontSize: 24,
        fontWeight: FontWeight.w800,
      ),
      titleLarge: TextStyle(
        color: color,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'Arial'],
        fontSize: 20,
        fontWeight: FontWeight.w700,
      ),
      titleMedium: TextStyle(
        color: color,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'Arial'],
        fontSize: 16,
        fontWeight: FontWeight.w700,
      ),
      bodyLarge: TextStyle(
        color: color,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'Arial'],
        fontSize: 16,
      ),
      bodyMedium: TextStyle(
        color: color,
        fontFamily: 'Inter',
        fontFamilyFallback: const ['Roboto', 'Arial'],
        fontSize: 14,
      ),
      labelLarge: const TextStyle(
        fontFamily: 'Inter',
        fontFamilyFallback: ['Roboto', 'Arial'],
        fontSize: 14,
        fontWeight: FontWeight.w700,
      ),
      labelMedium: const TextStyle(
        color: AppColors.gray,
        fontFamily: 'Inter',
        fontFamilyFallback: ['Roboto', 'Arial'],
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}
