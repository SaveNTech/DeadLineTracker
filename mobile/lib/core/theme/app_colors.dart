import 'package:flutter/material.dart';

/// Brand palette: a calm indigo as the primary action color, and a warm
/// coral/red reserved exclusively for overdue/urgent state — so red always
/// means "this deadline burned" and nothing else competes with it.
class AppColors {
  AppColors._();

  static const primary = Color(0xFF5B5FEF);
  static const primaryLight = Color(0xFF8B8FF7);

  static const overdue = Color(0xFFEF4444);
  static const overdueLight = Color(0xFFFCA5A5);

  static const success = Color(0xFF22C55E);

  static const surfaceLight = Color(0xFFF7F7FB);
  static const surfaceDark = Color(0xFF14141B);

  static const cardLight = Color(0xFFFFFFFF);
  static const cardDark = Color(0xFF1F1F29);
}
