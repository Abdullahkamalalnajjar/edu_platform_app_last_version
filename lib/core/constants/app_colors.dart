import 'package:flutter/material.dart';

class AppColors {
  // ═══════════════════════════════════════════════════════════════════════
  // BLACK & RED PREMIUM COLOR SYSTEM
  // A bold, dramatic palette with deep blacks and vibrant reds
  // ═══════════════════════════════════════════════════════════════════════

  // Primary Brand Colors - Red Theme
  static const Color primary = Color(0xFFE53935); // Vibrant Red
  static const Color primaryDark = Color(0xFFB71C1C); // Deep Red
  static const Color secondary = Color(0xFFFF5252); // Light Red / Coral
  static const Color accent = Color(0xFFFF1744); // Accent Red

  // Background & Surface - Deep Black Theme
  static const Color background = Color(0xFF0A0A0A); // Almost Pure Black
  static const Color surface = Color(0xFF141414); // Dark Surface
  static const Color surfaceLight = Color(0xFF1F1F1F); // Lighter Surface
  static const Color card = Color(0xFF1A1A1A); // Card Background

  // Typography Colors
  static const Color textPrimary = Color(0xFFFAFAFA); // Almost White
  static const Color textSecondary = Color(0xFFB0B0B0); // Light Grey
  static const Color textMuted = Color(0xFF707070); // Muted Grey

  // Light Theme Colors — Premium 2026 Warm Minimal Palette
  static const Color backgroundLight = Color(0xFFF5F4F2);   // Warm Creamy Off-White
  static const Color surfaceLightMode = Color(0xFFFFFFFF);   // Pure White surface
  static const Color surfaceLightVariant = Color(0xFFEFEDE9); // Warm grey surface
  static const Color cardLight = Color(0xFFFFFFFF);           // Clean White Card

  static const Color textPrimaryLight = Color(0xFF1A1A2E);   // Deep Navy-Black
  static const Color textSecondaryLight = Color(0xFF5A5A72); // Muted Indigo-Grey
  static const Color textMutedLight = Color(0xFF9A9AB0);     // Light Muted

  static const Color inputFillLight = Color(0xFFF0EFEC);
  static const Color inputBorderLight = Color(0xFFDAD9D5);

  // Functional Colors
  static const Color error = Color(0xFFFF5252); // Bright Red
  static const Color errorLight = Color(0xFFFFCDD2); // Light Red
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color successLight = Color(0xFFC8E6C9); // Light Green
  static const Color warning = Color(0xFFFFB300); // Amber
  static const Color warningLight = Color(0xFFFFECB3); // Light Amber
  static const Color info = Color(0xFF42A5F5); // Blue

  // Input & Form Elements
  static Color inputFill = const Color(0xFF1A1A1A);
  static Color inputBorder = const Color(0xFF2A2A2A);
  static Color inputFocusBorder = const Color(0xFFE53935);

  // Overlay & Glass Effect
  static Color overlay = const Color(0xFF0A0A0A).withOpacity(0.85);
  static Color glass = Colors.white.withOpacity(0.05);
  static Color glassBorder = Colors.white.withOpacity(0.08);

  // ═══════════════════════════════════════════════════════════════════════
  // BLACK & RED GRADIENTS
  // ═══════════════════════════════════════════════════════════════════════

  // Primary Button Gradient - Red to Dark Red
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [
      Color(0xFFE53935), // Vibrant Red
      Color(0xFFB71C1C), // Deep Dark Red
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Accent Gradient - Fire Red
  static const LinearGradient accentGradient = LinearGradient(
    colors: [
      Color(0xFFFF5252), // Light Red
      Color(0xFFD32F2F), // Medium Red
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Surface Gradient - Black gradient
  static const LinearGradient surfaceGradient = LinearGradient(
    colors: [
      Color(0xFF1A1A1A), // Dark
      Color(0xFF0A0A0A), // Darker
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Card Gradient - Subtle dark variation
  static LinearGradient cardGradient = LinearGradient(
    colors: [Colors.white.withOpacity(0.08), Colors.white.withOpacity(0.02)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Light Card Gradient
  static LinearGradient cardGradientLight = LinearGradient(
    colors: [Colors.white, const Color(0xFFF8F9FA)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Hero Gradient - Black with red hint
  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF0A0A0A),
      Color(0xFF1A0A0A), // Slight red tint
      Color(0xFF0A0A0A),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Dark Red Gradient - For special elements
  static const LinearGradient darkRedGradient = LinearGradient(
    colors: [
      Color(0xFF2A0A0A), // Very dark red
      Color(0xFF1A0505), // Almost black with red
    ],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  // Mesh Gradient Colors - Decorative orbs
  static const Color meshNavy = Color(0xFF1A237E);
  static const Color meshDarkNavy = Color(0xFF0D1642);
  static const Color meshGold = Color(0xFFFFD700);
  static const Color meshBlue = Color(0xFF3949AB);

  // Additional Mesh Colors - Red accents
  static const Color meshRed = Color(0xFFDC143C);
  static const Color meshDarkRed = Color(0xFF8B0000); // Pink-red

  // ═══════════════════════════════════════════════════════════════════════
  // SHADOWS & EFFECTS
  // ═══════════════════════════════════════════════════════════════════════

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.5),
      blurRadius: 20,
      offset: const Offset(0, 10),
    ),
    BoxShadow(
      color: const Color(0xFFE53935).withOpacity(0.1),
      blurRadius: 40,
      offset: const Offset(0, 20),
    ),
  ];

  static List<BoxShadow> buttonShadow = [
    BoxShadow(
      color: const Color(0xFFE53935).withOpacity(0.5),
      blurRadius: 20,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> subtleShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 10,
      offset: const Offset(0, 4),
    ),
  ];

  // Glow Effect for Red elements
  static List<BoxShadow> redGlow = [
    BoxShadow(
      color: const Color(0xFFE53935).withOpacity(0.4),
      blurRadius: 30,
      spreadRadius: 0,
    ),
  ];

  // Subject Card Colors - Red variations with accents
  static const List<List<Color>> subjectColors = [
    [Color(0xFFE53935), Color(0xFFB71C1C)], // Red
    [Color(0xFFD32F2F), Color(0xFF8B0000)], // Dark Red
    [Color(0xFFFF5252), Color(0xFFE53935)], // Light Red
    [Color(0xFFC62828), Color(0xFF7F0000)], // Deep Red
    [Color(0xFFAD1457), Color(0xFF6D0A3A)], // Pink-Red
    [Color(0xFF6A1B9A), Color(0xFF4A148C)], // Purple accent
    [Color(0xFFFF1744), Color(0xFFD50000)], // Bright Red
    [Color(0xFF880E4F), Color(0xFF4A0028)], // Maroon
  ];
}
