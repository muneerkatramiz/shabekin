import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

const kGreen = Color(0xFF0B3F3C);
const kGold = Color(0xFFFFBD35);

ThemeData buildTheme() {
  final scheme = ColorScheme.fromSeed(seedColor: kGreen, primary: kGreen, secondary: kGold, brightness: Brightness.light);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, scaffoldBackgroundColor: const Color(0xFFF6F7F5));
  return base.copyWith(
    textTheme: GoogleFonts.tajawalTextTheme(base.textTheme),
    appBarTheme: const AppBarTheme(backgroundColor: kGreen, foregroundColor: Colors.white, centerTitle: true),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.grey.shade300)),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: kGreen,
        minimumSize: const Size.fromHeight(50),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(indicatorColor: const Color(0x59FFBD35)),
  );
}
