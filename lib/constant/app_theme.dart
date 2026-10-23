import 'package:component_companion/constant/app_colors.dart';
import 'package:flutter/material.dart';

/// Theme chung: đặt màu cho mọi widget Material theo [AppColors] (không dùng
/// màu tím mặc định của Flutter).
class AppTheme {
  AppTheme._();

  static ThemeData light() {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: AppColors.onPrimary,
          primaryContainer: AppColors.primarySoft,
          onPrimaryContainer: AppColors.primaryDark,
          secondary: AppColors.primaryDark,
          onSecondary: AppColors.onPrimary,
          secondaryContainer: AppColors.primarySoft,
          onSecondaryContainer: AppColors.primaryDark,
          tertiary: AppColors.info,
          error: AppColors.error,
          surface: AppColors.surface,
          onSurface: AppColors.textMain,
          onSurfaceVariant: AppColors.textMuted,
          outline: AppColors.borderStrong,
          outlineVariant: AppColors.border,
          // Bỏ lớp phủ màu của Material 3 trên dialog / menu / card
          surfaceTint: Colors.transparent,
        );

    final roundedSmall = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(8),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      canvasColor: AppColors.background,
      dividerColor: AppColors.border,
      dividerTheme: const DividerThemeData(color: AppColors.border),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.primary,
        selectionColor: AppColors.primarySoft,
        selectionHandleColor: AppColors.primary,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
        linearTrackColor: AppColors.primarySoft,
      ),
      dialogTheme: const DialogThemeData(backgroundColor: AppColors.surface),
      popupMenuTheme: PopupMenuThemeData(
        color: AppColors.background,
        shape: roundedSmall,
      ),
      menuTheme: const MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(AppColors.background),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: AppColors.textMain.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.borderStrong),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(foregroundColor: AppColors.textMuted),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.primary : null,
        ),
        checkColor: const WidgetStatePropertyAll(AppColors.onPrimary),
        side: const BorderSide(color: AppColors.borderStrong, width: 1.6),
      ),
      radioTheme: RadioThemeData(
        fillColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.onPrimary
              : AppColors.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.surfaceVariant,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? AppColors.primary
              : AppColors.borderStrong,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.background,
        selectedColor: AppColors.primarySoft,
        checkmarkColor: AppColors.primaryDark,
        side: const BorderSide(color: AppColors.border),
        labelStyle: const TextStyle(color: AppColors.textMain),
        secondaryLabelStyle: const TextStyle(color: AppColors.primaryDark),
        shape: roundedSmall,
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.primarySoft
                : AppColors.background,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.selected)
                ? AppColors.primaryDark
                : AppColors.textMain,
          ),
          side: const WidgetStatePropertyAll(
            BorderSide(color: AppColors.borderStrong),
          ),
        ),
      ),
      listTileTheme: const ListTileThemeData(
        selectedColor: AppColors.primaryDark,
        selectedTileColor: AppColors.primarySoft,
        iconColor: AppColors.textMuted,
      ),
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: AppColors.primary,
        collapsedIconColor: AppColors.textMuted,
      ),
      inputDecorationTheme: InputDecorationTheme(
        floatingLabelStyle: const TextStyle(color: AppColors.primary),
        focusedBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.primary, width: 2),
        ),
        enabledBorder: const UnderlineInputBorder(
          borderSide: BorderSide(color: AppColors.borderStrong),
        ),
        hintStyle: const TextStyle(color: AppColors.textDisabled),
        errorStyle: const TextStyle(color: AppColors.error),
        prefixIconColor: AppColors.textMuted,
        suffixIconColor: AppColors.textMuted,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          AppColors.textMuted.withValues(alpha: 0.35),
        ),
      ),
    );
  }
}
