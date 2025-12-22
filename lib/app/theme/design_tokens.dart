import 'package:flutter/material.dart';

/// Design tokens for consistent styling across the app
class DesignTokens {
  DesignTokens._();

  // ========== Spacing ==========
  static const double spacingXs = 4;
  static const double spacingSm = 8;
  static const double spacingMd = 12;
  static const double spacingLg = 16;
  static const double spacingXl = 24;
  static const double spacingXxl = 32;

  // ========== Border Radius ==========
  static const double radiusXs = 4;
  static const double radiusSm = 8;
  static const double radiusMd = 12;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusXxl = 24;
  static const double radiusFull = 100;

  // ========== Card Elevation ==========
  static const double elevationNone = 0;
  static const double elevationLow = 2;
  static const double elevationMed = 4;
  static const double elevationHigh = 8;

  // ========== Font Sizes ==========
  static const double fontXs = 10;
  static const double fontSm = 12;
  static const double fontMd = 14;
  static const double fontLg = 16;
  static const double fontXl = 18;
  static const double fontXxl = 22;
  static const double fontDisplay = 28;

  // ========== Icon Sizes ==========
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double iconDisplay = 48;

  // ========== Card Styles ==========
  static BoxDecoration cardDecoration({
    required bool isDark,
    double radius = radiusLg,
    bool hasShadow = true,
  }) {
    return BoxDecoration(
      color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.06),
      ),
      boxShadow: hasShadow
          ? [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ]
          : null,
    );
  }

  /// Action card decoration (for buttons/action items)
  static BoxDecoration actionCardDecoration({
    required bool isDark,
    required Color accentColor,
    double radius = radiusLg,
  }) {
    return BoxDecoration(
      color: accentColor.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(radius),
      border: Border.all(
        color: accentColor.withValues(alpha: 0.2),
      ),
    );
  }

  /// Icon container decoration
  static BoxDecoration iconContainerDecoration({
    required bool isDark,
    required Color color,
    double radius = radiusMd,
  }) {
    return BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(radius),
    );
  }

  // ========== Text Styles ==========
  static TextStyle sectionHeaderStyle({required bool isDark}) {
    return TextStyle(
      fontSize: fontSm,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.grey[400] : Colors.grey[600],
      letterSpacing: 0.5,
    );
  }

  static TextStyle cardTitleStyle({required bool isDark}) {
    return TextStyle(
      fontSize: fontLg,
      fontWeight: FontWeight.w600,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  static TextStyle cardSubtitleStyle({required bool isDark}) {
    return TextStyle(
      fontSize: fontMd,
      color: isDark ? Colors.grey[400] : Colors.grey[600],
    );
  }

  static TextStyle greetingStyle({required bool isDark}) {
    return TextStyle(
      fontSize: fontXxl,
      fontWeight: FontWeight.bold,
      color: isDark ? Colors.white : Colors.black87,
    );
  }

  // ========== Consistent Padding ==========
  static const EdgeInsets screenPadding = EdgeInsets.all(spacingLg);
  static const EdgeInsets cardPadding = EdgeInsets.all(spacingLg);
  static const EdgeInsets listItemPadding = EdgeInsets.symmetric(
    horizontal: spacingLg,
    vertical: spacingMd,
  );
}
