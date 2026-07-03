import 'package:flutter/material.dart';
import '../utils/my_colors.dart';

enum AppTheme { White, Dark }

/// Returns enum value name without enum class name.
String enumName(AppTheme anyEnum) {
  return anyEnum.toString().split('.')[1];
}

final appThemeData = {
  AppTheme.White: ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MyColors.primary,
      brightness: Brightness.light,
      primary: MyColors.primary,
      secondary: const Color(0xFFFFB52E),
      surface: Colors.white,
    ),
    dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(
      color: Colors.black,
    )),
    brightness: Brightness.light,
    primaryColor: MyColors.primary,
    //primarySwatch: MyColors.primary,
    scaffoldBackgroundColor: const Color(0xFFF5F8FA),
    appBarTheme: AppBarTheme(
        backgroundColor: MyColors.primary,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: MyColors.primary,
      foregroundColor: Colors.white,
      iconSize: 28,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8EC)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFE2E8EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide(color: MyColors.primary, width: 1.4),
      ),
    ),
    cardTheme: CardThemeData(
      color: Colors.white,
    ),
    iconTheme: IconThemeData(
      color: Colors.black87,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      headlineSmall: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      labelMedium: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      labelLarge: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      titleLarge: TextStyle(
        color: Colors.black,
        fontSize: 20.0,
        fontFamily: 'WorkSans',
      ),
      titleSmall: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
        fontSize: 18.0,
      ),
      headlineMedium: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      displaySmall: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      displayMedium: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      displayLarge: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      titleMedium: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      bodyMedium: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      bodyLarge: TextStyle(
        color: Colors.black,
        fontFamily: 'WorkSans',
      ),
      labelSmall: TextStyle(
        color: Colors.black,
      ),
      bodySmall: TextStyle(
        color: Colors.black,
      ),
    ),
  ),
  AppTheme.Dark: ThemeData(
    //scaffoldBackgroundColor: MyColors.grey_90,
    //primaryColor: MyColors.grey_90,
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: MyColors.primary,
      brightness: Brightness.dark,
      primary: MyColors.primary,
      secondary: const Color(0xFFFFC857),
      surface: const Color(0xFF102532),
    ),
    scaffoldBackgroundColor: const Color(0xFF071720),
    dialogTheme: DialogThemeData(
        titleTextStyle: TextStyle(
      color: Colors.white,
    )),
    bottomSheetTheme: BottomSheetThemeData(
        //backgroundColor: MyColors.grey_90,
        ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: MyColors.grey_95,
    ),
    bottomAppBarTheme: BottomAppBarThemeData(color: MyColors.grey_95),
    appBarTheme: AppBarTheme(
        backgroundColor: MyColors.primary,
        foregroundColor: Colors.white,
        iconTheme: IconThemeData(
          color: Colors.white,
        ),
        titleTextStyle: TextStyle(color: Colors.white, fontSize: 18)),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: const Color(0xFFFFC857),
      foregroundColor: MyColors.primary,
      iconSize: 28,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: const Color(0xFF102532),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Colors.white12),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: Color(0xFFFFC857), width: 1.4),
      ),
    ),
    dividerColor: Colors.grey.shade800,
    //bottomAppBarTheme: BottomAppBarThemeData(color: MyColors.grey_90),
    cardTheme: CardThemeData(
        //color: MyColors.grey_80,
        ),
    iconTheme: IconThemeData(
      color: Colors.white,
    ),
    textTheme: TextTheme(
      headlineLarge: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      headlineSmall: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      labelMedium: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      labelLarge: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      titleLarge: TextStyle(
        color: Colors.white,
        fontSize: 20.0,
        fontFamily: 'WorkSans',
      ),
      titleSmall: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
        fontSize: 18.0,
      ),
      headlineMedium: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      displaySmall: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      displayMedium: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      displayLarge: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      titleMedium: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      bodyMedium: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      bodyLarge: TextStyle(
        color: Colors.white,
        fontFamily: 'WorkSans',
      ),
      labelSmall: TextStyle(
        color: Colors.white,
      ),
      bodySmall: TextStyle(
        color: Colors.white,
      ),
    ),
  ),
};
