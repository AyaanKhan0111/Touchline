import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Touchline Design System — Typography V2
/// Dual-font editorial system:
/// - Playfair Display for dramatic headings (sports magazine identity)
/// - Inter for body/data/UI (excellent tabular figures)
class AppTypography {
  AppTypography._();

  /// Body/data font
  static const String bodyFamily = 'Inter';

  /// Tabular figures for all numbers
  static const List<FontFeature> tabularFeatures = [
    FontFeature.tabularFigures(),
  ];

  /// Editorial heading — app title, mode names, hero text
  static TextStyle heading(Color color, {double fontSize = 28, FontWeight weight = FontWeight.w700}) {
    return GoogleFonts.playfairDisplay(
      fontSize: fontSize,
      fontWeight: weight,
      color: color,
      height: 1.15,
      letterSpacing: -0.3,
    );
  }

  /// Display — large hero numbers, big scores
  static TextStyle display(Color color) => GoogleFonts.playfairDisplay(
    fontSize: 48,
    fontWeight: FontWeight.w700,
    color: color,
    height: 1.0,
  );

  /// Title large — screen titles
  static TextStyle titleLarge(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 24,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.3,
    color: color,
    height: 1.2,
  );

  /// Title medium — section titles, card headers
  static TextStyle titleMedium(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 18,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
    color: color,
    height: 1.25,
  );

  /// Body large — primary content
  static TextStyle bodyLarge(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.1,
    color: color,
    height: 1.4,
  );

  /// Body medium — secondary content
  static TextStyle bodyMedium(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.4,
  );

  /// Body small — detail text, subtitles
  static TextStyle bodySmall(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.4,
  );

  /// Caption — smallest readable text
  static TextStyle caption(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: color,
    height: 1.3,
  );

  /// Section header — uppercase label (e.g. "TODAY'S CHALLENGES")
  static TextStyle sectionHeader(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: color,
  );

  /// Stat number — tabular, bold, for scores/ratings/stats
  static TextStyle statNumber(Color color, {double fontSize = 17, FontWeight weight = FontWeight.w600}) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: fontSize,
    fontWeight: weight,
    color: color,
    fontFeatures: tabularFeatures,
  );

  /// Timer / clock display
  static TextStyle timerDisplay(Color color) => TextStyle(
    fontFamily: bodyFamily,
    fontSize: 15,
    fontWeight: FontWeight.w700,
    color: color,
    fontFeatures: tabularFeatures,
  );

  // ─── Backward compatibility alias ──────────────────────────
  static const String fontFamily = bodyFamily;
}
