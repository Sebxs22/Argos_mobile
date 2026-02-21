import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';
import '../ui/glass_box.dart';

class UiUtils {
  static void _showGlassNotification({
    required String message,
    required IconData icon,
    required Color iconColor,
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
                borderRadius: 25,
                blur: 15,
                opacity: isDark ? 0.2 : 0.1,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, color: iconColor, size: 22),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        message,
                        style: TextStyle(
                          color: isDark ? Colors.white : Colors.black87,
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          fontFamily: 'Outfit',
                        ),
                      ),
                    ),
                  ],
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
      icon: Icons.check_circle_outline_rounded,
      iconColor: Colors.greenAccent.shade400,
    );
  }

  static void showError(String message) {
    _showGlassNotification(
      message: message,
      icon: Icons.error_outline_rounded,
      iconColor: Colors.redAccent.shade200,
      duration: const Duration(seconds: 4),
    );
  }

  static void showWarning(String message) {
    _showGlassNotification(
      message: message,
      icon: Icons.warning_amber_rounded,
      iconColor: Colors.amberAccent,
    );
  }
}
