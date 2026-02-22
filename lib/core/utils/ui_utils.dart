import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import '../ui/glass_box.dart';

class UiUtils {
  static void _showGlassNotification({
    required String message,
    required Color accentColor,
    Duration duration = const Duration(seconds: 3),
  }) {
    showOverlayNotification(
      (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Material(
              color: Colors.transparent,
              child: GlassBox(
                borderRadius: 20,
                blur: 20,
                opacity: isDark ? 0.15 : 0.08,
                padding: const EdgeInsets.all(0),
                child: IntrinsicHeight(
                  child: Row(
                    children: [
                      // Barra lateral sutil en lugar de icono
                      Container(
                        width: 4,
                        decoration: BoxDecoration(
                          color: accentColor.withValues(alpha: 0.8),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(20),
                            bottomLeft: Radius.circular(20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              vertical: 18, horizontal: 10),
                          child: Text(
                            message,
                            style: TextStyle(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.9)
                                  : Colors.black87,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              fontFamily: 'Outfit',
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
      duration: duration,
    );
  }

  static void showSuccess(String message) {
    _showGlassNotification(
      message: message,
      accentColor: Colors.greenAccent.shade400,
    );
  }

  static void showError(String message) {
    _showGlassNotification(
      message: message,
      accentColor: Colors.redAccent.shade200,
      duration: const Duration(seconds: 4),
    );
  }

  static void showWarning(String message) {
    _showGlassNotification(
      message: message,
      accentColor: Colors.amberAccent,
    );
  }
}
