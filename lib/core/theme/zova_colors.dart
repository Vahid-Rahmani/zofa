import 'package:flutter/material.dart';

/// Brand palette for zova.
///
/// The visual identity is a modern dark theme anchored by a vivid primary
/// blue, supported by clean whites and neutral greys.
abstract final class ZovaColors {
  static const Color primary = Color(0xFF3D7BFF);
  static const Color primaryDark = Color(0xFF1F3B8C);
  static const Color secondary = Color(0xFF59C1FF);

  static const Color background = Color(0xFF0F1524);
  static const Color surface = Color(0xFF1A2234);
  static const Color surfaceRaised = Color(0xFF232D45);

  static const Color textPrimary = Color(0xFFF4F7FF);
  static const Color textSecondary = Color(0xFFA7B2C9);

  static const Color success = Color(0xFF2FBF71);
  static const Color warning = Color(0xFFFFC24B);
  static const Color error = Color(0xFFFF5C6C);
  static const Color gold = Color(0xFFFFC24B);

  static const Color gradientStart = Color(0xFF3D7BFF);
  static const Color gradientEnd = Color(0xFF59C1FF);
}
