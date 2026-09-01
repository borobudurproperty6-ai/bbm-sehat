import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'colors.dart';

/// Heading font is Cormorant Garamond (semibold cap, per the design system);
/// body copy is Lora; large stat numbers use tabular figures on the default
/// system sans so digits line up.
class AppText {
  AppText._();

  static TextStyle heading({
    double size = 16,
    FontWeight weight = FontWeight.w600,
    Color color = AppColors.text,
    double? height,
    double letterSpacing = -0.01,
  }) => GoogleFonts.cormorantGaramond(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
    letterSpacing: letterSpacing,
  );

  static TextStyle body({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color color = AppColors.text,
    double? height,
  }) => GoogleFonts.lora(
    fontSize: size,
    fontWeight: weight,
    color: color,
    height: height,
  );

  /// Large tabular-figure numbers (step counts, stats, timers).
  static TextStyle num({
    double size = 22,
    FontWeight weight = FontWeight.w800,
    Color color = AppColors.text,
    double letterSpacing = -0.03,
  }) => TextStyle(
    fontSize: size,
    fontWeight: weight,
    color: color,
    letterSpacing: letterSpacing,
    fontFeatures: const [FontFeature.tabularFigures()],
    height: 1.0,
  );
}
