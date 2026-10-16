import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class AppColors {
  static const paper = Color(0xFFF3F0E8);
  static const paperDeep = Color(0xFFE6E1D6);
  static const surface = Color(0xFFFFFCF8);
  static const ink = Color(0xFF161513);
  static const muted = Color(0xFF6E6960);
  static const line = Color(0xFFDDD6C8);
  static const available = Color(0xFF146B3A);
  static const busy = Color(0xFFA12E28);
  static const hero = Color(0xFF12110F);
  static const onImage = Color(0xFFF6F3EC);
  static const onImageMuted = Color(0xFFD9D1C5);
}

ThemeData buildTheme() {
  final sans = GoogleFonts.schibstedGrotesk();
  final displayFace = GoogleFonts.bricolageGrotesque();

  TextStyle display(
    double size, {
    double height = 1.05,
    double spacing = -0.5,
  }) {
    return displayFace.copyWith(
      fontSize: size,
      height: height,
      letterSpacing: spacing,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
    );
  }

  TextStyle text(
    double size, {
    FontWeight weight = FontWeight.w400,
    double height = 1.45,
  }) {
    return sans.copyWith(
      fontSize: size,
      height: height,
      fontWeight: weight,
      color: AppColors.ink,
    );
  }

  final border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(4),
    borderSide: const BorderSide(color: AppColors.line),
  );

  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.paper,
    canvasColor: AppColors.paper,
    colorScheme: const ColorScheme.light(
      primary: AppColors.ink,
      onPrimary: Colors.white,
      secondary: AppColors.ink,
      surface: AppColors.surface,
      onSurface: AppColors.ink,
      error: AppColors.busy,
      onError: Colors.white,
    ),
    dividerColor: AppColors.line,
    textTheme: TextTheme(
      displaySmall: display(46, spacing: -0.8),
      headlineMedium: display(36, spacing: -0.6),
      headlineSmall: display(28, spacing: -0.3),
      titleLarge: display(22, height: 1.15, spacing: -0.2),
      titleMedium: text(16, weight: FontWeight.w600, height: 1.3),
      bodyLarge: text(16, height: 1.55),
      bodyMedium: text(15),
      bodySmall: text(13, height: 1.4).copyWith(color: AppColors.muted),
      labelLarge: text(14, weight: FontWeight.w600, height: 1.2),
      labelMedium: text(
        12,
        weight: FontWeight.w600,
        height: 1.2,
      ).copyWith(letterSpacing: 1.4, color: AppColors.muted),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      labelStyle: text(14).copyWith(color: AppColors.muted),
      hintStyle: text(15).copyWith(color: AppColors.muted),
      border: border,
      enabledBorder: border,
      focusedBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.ink, width: 1.4),
      ),
      errorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.busy),
      ),
      focusedErrorBorder: border.copyWith(
        borderSide: const BorderSide(color: AppColors.busy, width: 1.4),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        disabledBackgroundColor: AppColors.paperDeep,
        disabledForegroundColor: AppColors.muted,
        minimumSize: const Size(0, 48),
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
        textStyle: text(15, weight: FontWeight.w600, height: 1.1),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.ink,
        textStyle: text(14, weight: FontWeight.w600, height: 1.1),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.ink,
    ),
    dialogTheme: const DialogThemeData(
      backgroundColor: AppColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(8)),
        side: BorderSide(color: AppColors.line),
      ),
    ),
  );
}

ThemeData onImageTheme(ThemeData base) {
  TextStyle paint(TextStyle? style, Color color) {
    return (style ?? const TextStyle()).copyWith(color: color);
  }

  final text = base.textTheme;
  return base.copyWith(
    colorScheme: base.colorScheme.copyWith(
      onSurface: AppColors.onImage,
      onSurfaceVariant: AppColors.onImageMuted,
    ),
    textTheme: text.copyWith(
      displaySmall: paint(text.displaySmall, AppColors.onImage),
      headlineMedium: paint(text.headlineMedium, AppColors.onImage),
      headlineSmall: paint(text.headlineSmall, AppColors.onImage),
      titleLarge: paint(text.titleLarge, AppColors.onImage),
      titleMedium: paint(text.titleMedium, AppColors.onImage),
      bodyLarge: paint(text.bodyLarge, AppColors.onImage),
      bodyMedium: paint(text.bodyMedium, AppColors.onImage),
      bodySmall: paint(text.bodySmall, AppColors.onImageMuted),
      labelLarge: paint(text.labelLarge, AppColors.onImage),
      labelMedium: paint(text.labelMedium, AppColors.onImageMuted),
    ),
    iconTheme: const IconThemeData(color: AppColors.onImage),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: AppColors.onImage,
        textStyle: text.labelLarge?.copyWith(color: AppColors.onImage),
      ),
    ),
    iconButtonTheme: IconButtonThemeData(
      style: IconButton.styleFrom(foregroundColor: AppColors.onImage),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.onImage,
        disabledForegroundColor: AppColors.onImageMuted,
        side: const BorderSide(color: AppColors.onImageMuted),
      ),
    ),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: AppColors.onImage,
    ),
  );
}

class OnImageThemeScope extends InheritedWidget {
  const OnImageThemeScope({super.key, required this.ink, required super.child});

  final ThemeData ink;

  static ThemeData? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<OnImageThemeScope>()?.ink;
  }

  @override
  bool updateShouldNotify(OnImageThemeScope oldWidget) => ink != oldWidget.ink;
}

/// Restores dark text for content that sits on a light box, field or dialog.
class InkSurface extends StatelessWidget {
  const InkSurface({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ink = OnImageThemeScope.maybeOf(context);
    if (ink == null) return child;
    return Theme(
      data: ink,
      child: DefaultTextStyle(
        style: ink.textTheme.bodyMedium ?? const TextStyle(color: AppColors.ink),
        child: child,
      ),
    );
  }
}
