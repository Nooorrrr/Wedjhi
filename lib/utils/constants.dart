import 'package:flutter/material.dart';

/// App-wide constants for consistent UI styling
class AppColors {
  // Primary brand colors
  static const Color primary = Color(0xFF3F51B5); // Indigo
  static const Color primaryDark = Color(0xFF303F9F); // Darker indigo
  static const Color accent = Color(0xFF2196F3); // Blue

  // Status colors
  static const Color success = Color(0xFF4CAF50); // Green
  static const Color error = Color(0xFFF44336); // Red
  static const Color warning = Color(0xFFFF9800); // Orange

  // Background and text colors
  static const Color background = Color(0xFFF5F5F5); // Light gray
  static const Color cardBackground = Colors.white;
  static const Color textPrimary = Color(0xFF212121); // Almost black
  static const Color textSecondary = Color(0xFF757575); // Medium gray
  static const Color divider = Color(0xFFBDBDBD); // Light gray
}

/// Text styles for the app
class AppTextStyles {
  static const TextStyle headline1 = TextStyle(
    fontSize: 28.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle headline2 = TextStyle(
    fontSize: 24.0,
    fontWeight: FontWeight.bold,
    color: AppColors.textPrimary,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 18.0,
    fontWeight: FontWeight.w500,
    color: AppColors.textSecondary,
  );

  static const TextStyle body = TextStyle(
    fontSize: 16.0,
    color: AppColors.textPrimary,
  );

  static const TextStyle button = TextStyle(
    fontSize: 16.0,
    fontWeight: FontWeight.w600,
    color: Colors.white,
  );

  static const TextStyle caption = TextStyle(
    fontSize: 14.0,
    color: AppColors.textSecondary,
  );
}

/// Standard padding used throughout the app
class AppPadding {
  static const EdgeInsets screen = EdgeInsets.all(24.0);
  static const EdgeInsets card = EdgeInsets.all(16.0);
  static const EdgeInsets formField = EdgeInsets.symmetric(vertical: 12.0);
  static const double gap = 16.0;
  static const double smallGap = 8.0;
  static const double largeGap = 24.0;
}

/// App-wide animation durations
class AppAnimations {
  static const Duration short = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration long = Duration(milliseconds: 400);
}

/// Shadow styles
class AppShadows {
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 4.0,
      offset: Offset(0, 2),
    ),
  ];

  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Colors.black12,
      blurRadius: 8.0,
      offset: Offset(0, 4),
    ),
  ];
}

/// Input decoration theme for text fields
class AppInputDecorations {
  static InputDecoration textField({
    required String labelText,
    IconData? prefixIcon,
    String? hintText,
  }) {
    return InputDecoration(
      labelText: labelText,
      hintText: hintText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon) : null,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.divider),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.primary, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12.0),
        borderSide: const BorderSide(color: AppColors.error),
      ),
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
      filled: true,
      fillColor: Colors.white,
    );
  }
}
