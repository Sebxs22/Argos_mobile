import 'package:flutter/material.dart';
import 'package:overlay_support/overlay_support.dart';

class UiUtils {
  static void showSuccess(String message) {
    showSimpleNotification(
      Text(message, style: const TextStyle(color: Colors.white)),
      background: Colors.green,
      duration: const Duration(seconds: 3),
      slideDismissDirection: DismissDirection.horizontal,
    );
  }

  static void showError(String message) {
    showSimpleNotification(
      Text(message, style: const TextStyle(color: Colors.white)),
      background: Colors.redAccent,
      duration: const Duration(seconds: 4),
      slideDismissDirection: DismissDirection.horizontal,
      leading: const Icon(Icons.error_outline, color: Colors.white),
    );
  }

  static void showWarning(String message) {
    showSimpleNotification(
      Text(message, style: const TextStyle(color: Colors.black)),
      background: Colors.amber,
      duration: const Duration(seconds: 3),
      slideDismissDirection: DismissDirection.horizontal,
      leading: const Icon(Icons.warning_amber_rounded, color: Colors.black),
    );
  }
}
