import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  static const Color darkNavy = Color(0xFF002347);
  static const Color lightBlue = Color(0xFFBFE7FF);
  static const Color accentBlue = Color(0xFF5CC6FF);
  static const Color background = Color(0xFFF5F7FB);

  // IUCN conservation status colors (from fish_detail_page.dart)
  static const Map<String, Color> statusColors = {
    'Extinct (EX)': Color(0xFF000000),
    'Extinct in the Wild (EW)': Color(0xFF4A0080),
    'Critically Endangered (CR)': Color(0xFFCC0000),
    'Endangered (EN)': Color(0xFFE65C00),
    'Vulnerable (VU)': Color(0xFFE6A800),
    'Near Threatened (NT)': Color(0xFF2E8B57),
    'Least Concern (LC)': Color(0xFF006400),
    'Data Deficient (DD)': Color(0xFF607D8B),
    'Not Evaluated (NE)': Color(0xFF9E9E9E),
  };
}
