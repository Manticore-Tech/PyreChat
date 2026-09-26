import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import 'package:pyrechat_flutter/theme/pyre_colors.dart';

export 'pyre_colors.dart';

ThemeData pyreTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: PyreColors.ember,
    brightness: Brightness.light,
    surface: PyreColors.paper,
  ).copyWith(
    primary: PyreColors.ember,
    onPrimary: PyreColors.paper,
    secondary: PyreColors.emberSoft,
    onSecondary: PyreColors.ink,
    surface: PyreColors.paper,
    onSurface: PyreColors.ink,
    error: PyreColors.errorOnPaper,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: PyreColors.canvas,
    colorScheme: scheme,
    splashFactory: InkSparkle.splashFactory,
    pageTransitionsTheme: const PageTransitionsTheme(
      builders: {
        TargetPlatform.android: PredictiveBackPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
        TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
      },
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        color: PyreColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.9,
      ),
      headlineMedium: TextStyle(
        color: PyreColors.ink,
        fontWeight: FontWeight.w900,
        letterSpacing: -0.6,
      ),
      titleMedium: TextStyle(
        color: PyreColors.ink,
        fontWeight: FontWeight.w800,
      ),
      bodyMedium: TextStyle(
        color: PyreColors.onPaperMuted,
        height: 1.35,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: PyreColors.paperDim,
      hintStyle: const TextStyle(color: PyreColors.hintOnPaper),
      labelStyle: const TextStyle(color: PyreColors.onPaperMuted),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(
          color: PyreColors.ink.withValues(alpha: 0.06),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: PyreColors.ember, width: 1.6),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        textStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w800,
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: PyreColors.ink,
      contentTextStyle: const TextStyle(color: PyreColors.paper),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
