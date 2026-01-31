import 'package:flutter/material.dart';
import 'dart:ui';

class AppTheme {
  // iOS-like dark backgrounds (soft blacks and charcoals)
  static const Color bgPrimary = Color(0xFF000000);
  static const Color bgSecondary = Color(0xFF1C1C1E);
  static const Color bgElevated = Color(0xFF2C2C2E);
  static const Color bgCard = Color(0xFF3A3A3C);
  
  // Glass effect colors
  static const Color glassLight = Color(0x0FFFFFFF);
  static const Color glassMedium = Color(0x1AFFFFFF);
  static const Color glassDark = Color(0x0DFFFFFF);

  // Neutral gray text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFFAEAEB2);
  static const Color textTertiary = Color(0xFF8E8E93);

  // Subtle accent (soft teal blue - iOS-like)
  static const Color accentPrimary = Color(0xFF5AC8FA);
  static const Color accentSecondary = Color(0xFF48B5E3);
  
  // Functional colors
  static const Color borderColor = Color(0xFF38383A);
  static const Color separator = Color(0xFF48484A);
  static const Color danger = Color(0xFFFF453A);
  static const Color success = Color(0xFF32D74B);

  // File type colors (subtle, not bright)
  static const Color folderColor = Color(0xFF5AC8FA);
  static const Color pdfColor = Color(0xFFFF6961);
  static const Color textFileColor = Color(0xFF32D74B);
  static const Color imageColor = Color(0xFF5E5CE6);
  static const Color videoColor = Color(0xFFBF5AF2);
  static const Color audioColor = Color(0xFF32ADE6);
  static const Color sheetColor = Color(0xFF30D158);
  static const Color presentationColor = Color(0xFFFF9F0A);
  static const Color defaultFileColor = textSecondary;

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: bgPrimary,
      
      colorScheme: const ColorScheme.dark(
        primary: accentPrimary,
        secondary: accentSecondary,
        surface: bgSecondary,
        error: danger,
        onPrimary: Colors.white,
        onSurface: textPrimary,
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: IconThemeData(color: textPrimary),
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),

      textTheme: const TextTheme(
        displayLarge: TextStyle(
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: -0.5,
        ),
        titleLarge: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        bodyLarge: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w400,
          color: textPrimary,
        ),
        bodyMedium: TextStyle(
          fontSize: 15,
          color: textSecondary,
        ),
        bodySmall: TextStyle(
          fontSize: 13,
          color: textTertiary,
        ),
      ),

      iconTheme: const IconThemeData(
        color: textPrimary,
        size: 22,
      ),

      dividerTheme: const DividerThemeData(
        color: separator,
        thickness: 0.5,
      ),

      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      dialogTheme: const DialogThemeData(
        backgroundColor: bgElevated,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
        titleTextStyle: TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: textPrimary,
        ),
        contentTextStyle: TextStyle(
          fontSize: 13,
          color: textSecondary,
        ),
      ),
    );
  }
}

