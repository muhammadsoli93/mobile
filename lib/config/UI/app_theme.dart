import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';

final appTheme = ThemeData(
  useMaterial3: true,
  fontFamily: 'Gilroy',
  splashFactory: InkRipple.splashFactory,
  scaffoldBackgroundColor: const Color(0xFFF2F2F7),
  colorScheme: const ColorScheme.light(
    primary: Color(0xFF7B2CF5),
    secondary: Color(0xFF34C759),
    surface: Color(0xFFF2F2F7),
    onSurface: Color(0xFF111827),
  ),
  pageTransitionsTheme: const PageTransitionsTheme(
    builders: <TargetPlatform, PageTransitionsBuilder>{
      TargetPlatform.android: CupertinoPageTransitionsBuilder(),
      TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
      TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
      TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
    },
  ),
  appBarTheme: const AppBarTheme(
    centerTitle: true,
    backgroundColor: Color(0xFFF2F2F7),
    surfaceTintColor: AppColors.hexFFFFFF,
    elevation: 0,
    titleTextStyle: AppTextStyles.title,
    iconTheme: IconThemeData(color: Color(0xFF7B2CF5)),
  ),
  bottomNavigationBarTheme: const BottomNavigationBarThemeData(
    backgroundColor: AppColors.hexFFFFFF,
    type: BottomNavigationBarType.fixed,
    selectedItemColor: Color(0xFF7B2CF5),
    unselectedItemColor: Color(0xFF8E8E93),
    showSelectedLabels: true,
    showUnselectedLabels: true,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    color: AppColors.hexFFFFFF,
    elevation: 0,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(18),
    ),
    margin: EdgeInsets.zero,
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.hexFFFFFF,
    border: _border,
    focusedBorder: _border,
    enabledBorder: _border,
    errorBorder: _errorBorder,
    focusedErrorBorder: _errorBorder,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
    hintStyle: AppTextStyles.s14w400hB2B2B2,
  ),
  textSelectionTheme: const TextSelectionThemeData(
    cursorColor: Color(0xFF7B2CF5),
    selectionColor: Color(0x337B2CF5),
    selectionHandleColor: Color(0xFF7B2CF5),
  ),
  textTheme: const TextTheme(
    bodyLarge: AppTextStyles.s14w400h000000,
    bodyMedium: AppTextStyles.body,
    titleLarge: AppTextStyles.title,
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      foregroundColor: AppColors.hexFFFFFF,
      backgroundColor: const Color(0xFF7B2CF5),
      disabledBackgroundColor: AppColors.hex99A6B8,
      minimumSize: const Size(double.infinity, 52),
      textStyle: AppTextStyles.s16w600hFFFFFF,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      elevation: 0,
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: const Color(0xFF7B2CF5),
      side: const BorderSide(color: Color(0x337B2CF5)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
      textStyle: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  ),
);

final _border = OutlineInputBorder(
  borderSide: const BorderSide(
    color: Color(0x33000000),
    width: 1,
  ),
  borderRadius: BorderRadius.circular(14),
);

final _errorBorder = OutlineInputBorder(
  borderSide: const BorderSide(
    color: AppColors.danger,
    width: 1,
  ),
  borderRadius: BorderRadius.circular(14),
);
