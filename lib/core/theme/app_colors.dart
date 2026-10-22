import 'package:flutter/material.dart';

/// Modern, cohesive color system for Norbit communication app.
/// Palette: Deep Purple / Indigo primary, Vibrant Cyan / Teal accent,
/// Warm Sunset Orange secondary, with sleek dark & light neutrals.
class AppColors {
  AppColors._();

  // ── Brand Primary (Deep Purple / Indigo) ─────────────────────────────────
  static const Color primary = Color(0xFF6366F1); // Indigo-500
  static const Color primaryDark = Color(0xFF4F46E5); // Indigo-600
  static const Color primaryDarker = Color(0xFF4338CA); // Indigo-700
  static const Color primaryLight = Color(0xFF818CF8); // Indigo-400
  static const Color primarySubtle = Color(0xFFEEF2FF); // Indigo-50

  // ── Accent Colors (Vibrant Teal / Cyan & Sunset Orange) ──────────────────
  static const Color accentTeal = Color(0xFF06B6D4); // Cyan-500
  static const Color tealDark = Color(0xFF0891B2);
  static const Color accentTealLight = Color(0xFF22D3EE);
  static const Color accentOrange = Color(0xFFF97316); // Orange-500
  static const Color orangeLight = Color(0xFFFB923C);

  // ── Dark Mode Foundations ────────────────────────────────────────────────
  static const Color darkBg = Color(0xFF090D16);
  static const Color darkSurface = Color(0xFF111827);
  static const Color darkSurfaceElevated = Color(0xFF1E293B);
  static const Color darkBorder = Color(0xFF334155);
  static const Color darkTextPrimary = Color(0xFFF8FAFC);
  static const Color darkTextSecondary = Color(0xFF94A3B8);

  // ── Light Mode Foundations ───────────────────────────────────────────────
  static const Color lightBg = Color(0xFFF8FAFC);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceElevated = Color(0xFFF1F5F9);
  static const Color lightBorder = Color(0xFFE2E8F0);
  static const Color lightTextPrimary = Color(0xFF0F172A);
  static const Color lightTextSecondary = Color(0xFF64748B);

  // ── Status & Presence Colors ─────────────────────────────────────────────
  static const Color online = Color(0xFF10B981); // Emerald green
  static const Color away = Color(0xFFF59E0B); // Amber
  static const Color offline = Color(0xFF94A3B8); // Muted slate
  static const Color error = Color(0xFFEF4444); // Red
  static const Color success = Color(0xFF10B981);
  static const Color warning = Color(0xFFF59E0B);
  static const Color info = Color(0xFF3B82F6);

  // ── Common Neutrals ──────────────────────────────────────────────────────
  static const Color white = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFF8FAFC);
  static const Color lightGrey = Color(0xFFE2E8F0);
  static const Color grey = Color(0xFF94A3B8);
  static const Color darkGrey = Color(0xFF1E293B);
  static const Color black = Color(0xFF000000);

  // ── Legacy Aliases (maintains 100% backward compatibility) ────────────────
  static const Color purple1 = primary;
  static const Color purple = primaryDark;
  static const Color orange1 = accentOrange;
  static const Color orange2 = orangeLight;
  static const Color orange = accentOrange;
  static const Color tealGreen = accentTeal;
  static const Color pink1 = Color(0xFFA5B4FC);
  static const Color pink2 = Color(0xFFC7D2FE);
  static const Color pinkLight = Color(0xFFE0E7FF);
  static const Color pinkDark = Color(0xFF818CF8);

  // ── Premium Gradients ────────────────────────────────────────────────────
  /// Main Brand Gradient: Rich Indigo to Vibrant Violet
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFF6366F1), // Indigo
      Color(0xFF8B5CF6), // Purple
      Color(0xFF06B6D4), // Cyan accent
    ],
  );

  /// Sleek Button Gradient
  static const LinearGradient buttonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    stops: [0.0, 1.0],
    colors: [
      Color(0xFF6366F1),
      Color(0xFF06B6D4),
    ],
  );

  /// Subtle Ambient Background Gradient (Light Mode)
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.4, 1.0],
    colors: [
      Color(0xFFF1F5F9),
      Color(0xFFF8FAFC),
      Color(0xFFFFFFFF),
    ],
  );

  /// Ambient Dark Mode Background Gradient
  static const LinearGradient darkBackgroundGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    stops: [0.0, 0.45, 1.0],
    colors: [
      Color(0xFF0F172A),
      Color(0xFF0B0F19),
      Color(0xFF060911),
    ],
  );

  /// Call Screen Dark Gradient
  static const RadialGradient callGradient = RadialGradient(
    center: Alignment(0, -0.3),
    radius: 1.25,
    colors: [
      Color(0xFF1E1B4B), // Deep indigo core
      Color(0xFF0F172A),
      Color(0xFF030712),
    ],
  );

  /// Card Border Glow
  static Border sideGlowBorder({bool isDark = false}) => Border.all(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : primary.withValues(alpha: 0.12),
        width: 1,
      );
}
