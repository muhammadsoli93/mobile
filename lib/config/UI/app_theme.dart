import 'package:flutter/material.dart';
import 'package:kumarket/config/UI/app_colors.dart';
import 'package:kumarket/config/UI/app_text_styles.dart';

final appTheme = ThemeData(
  scaffoldBackgroundColor: AppColors.hexFFFFFF,

  //fonts
  fontFamily: 'Schyler',

  //appBar
  appBarTheme: AppBarTheme(
    centerTitle: true,
    backgroundColor: AppColors.hexFFFFFF,
    surfaceTintColor: AppColors.hexFFFFFF,
    // shadowColor: AppColors.hex696969,
  ),

  //bottomNav
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.hexFFFFFF,
    type: BottomNavigationBarType.fixed,
  ),

  //style -> textfield
  inputDecorationTheme: InputDecorationTheme(
    border: _border,
    focusedBorder: _border,
    enabledBorder: _border,
    hintStyle: AppTextStyles.s14w400hB2B2B2,
  ),
  textSelectionTheme: TextSelectionThemeData(
    //style -> textfield
    cursorColor: AppColors.hex000000,
  ),
  textTheme: TextTheme(
    //style -> textfield
    bodyLarge: AppTextStyles.s14w400h000000,
  ),
);

final _border = OutlineInputBorder(
  borderSide: BorderSide(
    color: AppColors.hexE7E7E7,
    width: 1,
  ),
  borderRadius: BorderRadius.circular(16),
);
