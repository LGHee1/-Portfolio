import 'package:flutter/material.dart';

class AppTheme {
  static const Color primaryColor = Color(0xFFCCF6FF);
  static const Color secondaryColor = Color(0xFFCCF6FF);
  static const Color darkTextColor = Color(0xFF000000);
  static const Color lightTextColor = Color(0xFF757575);
  static const Color backgroundColor = Color(0xFFFFFFFF);

  static ThemeData get theme => ThemeData(
        primaryColor: primaryColor,
        scaffoldBackgroundColor: backgroundColor,
        appBarTheme: AppBarTheme(
          backgroundColor: backgroundColor,
          elevation: 0,
          iconTheme: IconThemeData(color: darkTextColor),
          titleTextStyle: TextStyle(
            color: darkTextColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: darkTextColor,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(30),
            ),
          ),
        ),
      );
}
