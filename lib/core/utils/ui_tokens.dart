import 'package:flutter/material.dart';

class UiTokens {
  // --- PALETA DE MARCA (Fija) ---
  static const Color argosRed = Color(0xFFE53935);
  static const Color glacialBlue = Color(0xFF2962FF);
  static const Color emeraldGreen = Color(0xFF2E7D32); // v2.14.9: Más elegante
  static const Color alertOrange = Color(0xFFFF9800);

  // --- COLORES ADAPTATIVOS ---

  // Fondos de Pantalla
  static Color background(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF030308) : const Color(0xFFF1F5F9);
  }

  // Superficies (Cards, Dialogs)
  static Color surface(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFF0F172A) : Colors.white;
  }

  // Texto Principal
  static Color textColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white : const Color(0xFF0F172A);
  }

  // Texto Secundario / Hint
  static Color secondaryTextColor(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? Colors.white38 : Colors.black45;
  }

  // --- ESTILOS DE CRISTAL ---

  static double glassOpacity(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? 0.1 : 0.08;
  }

  static Color glassBorder(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark
        ? Colors.white.withValues(alpha: 0.15)
        : Colors.black.withValues(alpha: 0.08);
  }

  // --- ESTILOS DE DIÁLOGOS ---

  static ShapeBorder dialogShape = RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(25),
  );
}
