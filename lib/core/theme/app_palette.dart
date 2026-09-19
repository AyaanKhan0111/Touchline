import 'package:flutter/material.dart';

/// Touchline Design System — Palette V2
/// "Pitch-Side Editorial" — premium sports magazine meets game UI.
/// Deep charcoal-navy dark mode with gold/green/coral semantic accents.
class AppPalette {
  AppPalette._();

  // ─── Dark Theme Tokens ─────────────────────────────────────────────
  static const Color darkBg        = Color(0xFF0A0C10);  // Near-black, blue undertone
  static const Color darkSurface   = Color(0xFF141820);  // Deep navy-charcoal
  static const Color darkCard      = Color(0xFF1C2230);  // Card/raised surface
  static const Color darkHover     = Color(0xFF242A38);  // Hover/active highlight
  static const Color darkBorder    = Color(0xFF2A3040);  // Subtle, not prominent
  static const Color darkInk       = Color(0xFFF0F0EC);  // Warm white
  static const Color darkInkMuted  = Color(0xFF8A90A0);  // Cool grey
  static const Color darkInkDim    = Color(0xFF4A5060);  // Disabled/hint

  // ─── Light Theme Tokens ────────────────────────────────────────────
  static const Color lightBg         = Color(0xFFF2F3F0);  // Warm paper
  static const Color lightSurface    = Color(0xFFFFFFFF);  // Pure white
  static const Color lightCard       = Color(0xFFF8F9F5);  // Slight warmth
  static const Color lightHover      = Color(0xFFEDEEEA);  // Hover
  static const Color lightBorder     = Color(0xFFDCDDD8);  // Soft edge
  static const Color lightInk        = Color(0xFF0F1218);  // Near-black
  static const Color lightInkMuted   = Color(0xFF606878);  // Medium grey-blue
  static const Color lightInkDim     = Color(0xFFA0A4AC);  // Disabled

  // ─── Semantic Accents (same in both themes) ────────────────────────
  static const Color gold     = Color(0xFFD4A843);  // Coins, rewards, premium
  static const Color goldDark = Color(0xFFB8860B);  // Gold for light mode
  static const Color green    = Color(0xFF2ECC71);  // Turf green — wins, correct
  static const Color red      = Color(0xFFE74C3C);  // Coral — losses, wrong
  static const Color amber    = Color(0xFFF39C12);  // Warnings, draws, caution
  static const Color blue     = Color(0xFF3498DB);  // Info, stats, neutral

  // ─── Position Colors (for avatar rings) ────────────────────────────
  static const Color posGK   = Color(0xFFE8B923);  // Goalkeeper gold
  static const Color posDEF  = Color(0xFF27AE60);  // Defender green
  static const Color posMID  = Color(0xFF2980B9);  // Midfielder blue
  static const Color posFWD  = Color(0xFFE74C3C);  // Forward red

  // ─── Tonal Steps (Connections, tier indicators) ──────────────────
  static const Color tonalStep1 = Color(0xFFE8E5DA); // Sand
  static const Color tonalStep2 = Color(0xFFB0C4B1); // Sage
  static const Color tonalStep3 = Color(0xFF4A7C59); // Moss
  static const Color tonalStep4 = Color(0xFF1F6F4A); // Deep Green

  // ─── Convenience Aliases (backward compat) ─────────────────────────
  static const Color darkSurfaceRaised  = darkCard;
  static const Color lightSurfaceRaised = lightCard;
  static const Color darkAccent         = gold;
  static const Color lightAccent        = goldDark;
  static const Color positive           = green;
  static const Color negative           = red;
  static const Color warn               = amber;

  /// Position-based color for avatar rings
  static Color positionColor(String position) {
    final p = position.toUpperCase();
    if (p == 'GK') return posGK;
    if (['CB', 'LB', 'RB', 'LWB', 'RWB'].contains(p)) return posDEF;
    if (['CM', 'CDM', 'CAM', 'LM', 'RM'].contains(p)) return posMID;
    return posFWD; // ST, CF, LW, RW, SS
  }

  /// Rating tier color
  static Color ratingColor(int rating) {
    if (rating >= 85) return green;
    if (rating >= 75) return blue;
    if (rating >= 65) return amber;
    return red;
  }
}
