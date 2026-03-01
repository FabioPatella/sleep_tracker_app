import 'package:flutter/material.dart';

class AppTheme {
  // Brand colors derived from Tailwind config
  static const Color primaryIndigo = Color(0xFF4F46E5); // indigo-600
  static const Color primaryPurple = Color(0xFF9333EA); // purple-600
  static const Color primaryIndigoHover = Color(0xFF4338CA); // indigo-700
  static const Color primaryPurpleHover = Color(0xFF7E22CE); // purple-700
  
  static const Color backgroundLight = Color(0xFFFFFFFF); // bg-white
  static const Color surfaceLight = Color(0xFFF9FAFB); // bg-gray-50
  
  static const Color backgroundDark = Color(0xFF1F2937); // bg-gray-800
  static const Color surfaceDark = Color(0xFF374151); // bg-gray-700
  
  static const Color textLightPrimary = Color(0xFF111827); // gray-900
  static const Color textLightSecondary = Color(0xFF4B5563); // gray-600
  
  static const Color textDarkPrimary = Color(0xFFF9FAFB); // white/gray-50
  static const Color textDarkSecondary = Color(0xFF9CA3AF); // gray-400
  
  static const Color errorLight = Color(0xFFDC2626); // red-600
  static const Color successGreen = Color(0xFF10B981); // emerald-500
  
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: primaryIndigo,
      scaffoldBackgroundColor: surfaceLight,
      colorScheme: ColorScheme.light(
        primary: primaryIndigo,
        secondary: primaryPurple,
        surface: backgroundLight,
        error: errorLight,
      ),
      cardTheme: CardTheme(
        color: backgroundLight,
        elevation: 4,
        shadowColor: Colors.black.withOpacity(0.1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), // rounded-2xl
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: backgroundLight,
        selectedItemColor: primaryIndigo,
        unselectedItemColor: textLightSecondary,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textLightPrimary, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textLightPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textLightPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textLightPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textLightSecondary, fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: backgroundLight,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFFD1D5DB)), // gray-300
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryIndigo, width: 2), // focus:ring-2 focus:ring-indigo-500
        ),
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textLightSecondary),
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: primaryIndigo,
      scaffoldBackgroundColor: backgroundDark,
      colorScheme: ColorScheme.dark(
        primary: primaryIndigo,
        secondary: primaryPurple,
        surface: surfaceDark,
        error: errorLight,
      ),
      cardTheme: CardTheme(
        color: surfaceDark,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.3),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surfaceDark,
        selectedItemColor: primaryIndigo,
        unselectedItemColor: textDarkSecondary,
      ),
      textTheme: TextTheme(
        displayLarge: TextStyle(color: textDarkPrimary, fontSize: 32, fontWeight: FontWeight.bold),
        displayMedium: TextStyle(color: textDarkPrimary, fontSize: 24, fontWeight: FontWeight.bold),
        titleLarge: TextStyle(color: textDarkPrimary, fontSize: 20, fontWeight: FontWeight.w600),
        bodyLarge: TextStyle(color: textDarkPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: textDarkSecondary, fontSize: 14),
      ),
      inputDecorationTheme: InputDecorationTheme(
        fillColor: surfaceDark,
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: Color(0xFF4B5563)), // border-gray-600
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: primaryIndigo, width: 2),
        ),
        labelStyle: TextStyle(fontSize: 14, fontWeight: FontWeight.w500, color: textDarkSecondary),
      ),
    );
  }
}

// Widget Helper for Gradient Buttons since Flutter core buttons don't support gradients natively
class GradientButton extends StatelessWidget {
  final VoidCallback onPressed;
  final Widget child;
  final bool isDestructive;

  const GradientButton({
    Key? key,
    required this.onPressed,
    required this.child,
    this.isDestructive = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: isDestructive
            ? null
            : LinearGradient(
                colors: [AppTheme.primaryIndigo, AppTheme.primaryPurple],
              ),
        color: isDestructive ? AppTheme.errorLight : null,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: (isDestructive ? AppTheme.errorLight : AppTheme.primaryIndigo).withOpacity(0.3),
            spreadRadius: 1,
            blurRadius: 8,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            alignment: Alignment.center,
            child: child,
          ),
        ),
      ),
    );
  }
}
