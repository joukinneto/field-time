import 'package:flutter/material.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_colors.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_radius.dart';
import 'package:jkdd_field_time_records_production/core/theme/app_typography.dart';

abstract final class AppTheme {
  static ThemeData light() => _theme(Brightness.light);

  static ThemeData dark() => _theme(Brightness.dark);

  static ThemeData _theme(Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.blue,
      brightness: brightness,
      primary: AppColors.blue,
      secondary: AppColors.green,
      tertiary: AppColors.teal,
      error: AppColors.red,
      surface: dark ? AppColors.darkSurface : AppColors.surface,
    );
    final textTheme = AppTypography.textTheme(brightness);
    return ThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: dark ? AppColors.navy : AppColors.surface,
      textTheme: textTheme,
      useMaterial3: true,
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: dark ? AppColors.navy : AppColors.white,
        foregroundColor: dark ? AppColors.white : AppColors.navy,
        surfaceTintColor: Colors.transparent,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: dark ? AppColors.darkCard : AppColors.white,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: BorderSide(
              color: dark ? const Color(0xff334155) : AppColors.border),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark ? const Color(0xff19344a) : AppColors.infoSoft,
        side: BorderSide(
            color: dark ? const Color(0xff2f5c7a) : const Color(0xffbfdbfe)),
        labelStyle: TextStyle(color: dark ? AppColors.white : AppColors.navy),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm)),
      ),
      dividerTheme: DividerThemeData(
        color: dark ? const Color(0xff334155) : AppColors.border,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(48, 48),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.blue),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.md)),
          textStyle: textTheme.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark ? AppColors.darkCard : AppColors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: dark ? AppColors.navy : AppColors.white,
        indicatorColor: dark ? const Color(0xff1e40af) : AppColors.infoSoft,
        labelTextStyle: WidgetStateProperty.all(textTheme.labelMedium),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: AppColors.navy,
        selectedIconTheme: const IconThemeData(color: AppColors.green),
        selectedLabelTextStyle:
            textTheme.labelLarge?.copyWith(color: AppColors.white),
        unselectedIconTheme: const IconThemeData(color: Color(0xff94a3b8)),
        unselectedLabelTextStyle:
            textTheme.labelMedium?.copyWith(color: const Color(0xffcbd5e1)),
        indicatorColor: const Color(0xff102a4c),
      ),
    );
  }
}
