import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../ui/update_progress_dialog.dart';
import '../utils/ui_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

class VersionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> checkForUpdates(BuildContext context,
      {bool manual = false}) async {
    try {
      final response =
          await _supabase.from('app_config').select().maybeSingle();

      if (response == null) {
        debugPrint("⚠️ ARGOS OTA: No se encontró configuración en app_config.");
        if (manual && context.mounted) {
          UiUtils.showError("Servicio de actualización no disponible");
        }
        return;
      }

      if (!context.mounted) return;
      await _processUpdate(context, response, manual: manual);
    } catch (e) {
      debugPrint("❌ ARGOS OTA Error: $e");
      if (manual && context.mounted) {
        UiUtils.showError("Error al verificar versión: $e");
      }
    }
  }

  void listenForUpdates(BuildContext context) {
    try {
      _supabase.from('app_config').stream(primaryKey: ['id']).listen(
          (List<Map<String, dynamic>> data) {
        if (data.isNotEmpty && context.mounted) {
          _processUpdate(context, data.first, manual: false);
        }
      }, onError: (e) {
        debugPrint("❌ ARGOS OTA Stream Error: $e");
      });
    } catch (e) {
      debugPrint("❌ ARGOS OTA Stream Initial Exception: $e");
    }
  }

  Future<void> _processUpdate(BuildContext context, Map<String, dynamic> data,
      {bool manual = false}) async {
    // 1. Obtener versión local
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    String latestVersion = data['version_actual'] ?? "";
    String downloadUrl = data['link_descarga'] ?? "";
    bool isRequired = data['es_obligatoria'] ?? false;

    if (latestVersion.isEmpty) return;

    // 2. Lógica Anti-Spam (v2.9.2)
    final prefs = await SharedPreferences.getInstance();
    final String lastNotified =
        prefs.getString('last_notified_ota_version') ?? "";

    // Si ya notificamos esta versión y no es un chequeo manual, salimos
    if (latestVersion == lastNotified && !manual) {
      debugPrint(
          "ℹ️ ARGOS OTA: Versión $latestVersion ya notificada previamente.");
      return;
    }

    // 3. Comparar
    if (currentVersion != latestVersion) {
      // Notificación local de respaldo
      final FlutterLocalNotificationsPlugin notifications =
          FlutterLocalNotificationsPlugin();

      await notifications.show(
        id: 777,
        title: '🚀 NUEVA VERSIÓN: v$latestVersion',
        body: 'Mejoras de seguridad disponibles. Toca para descargar.',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'argos_updates',
            'Actualizaciones',
            importance: Importance.max,
            priority: Priority.high,
            enableVibration: true,
            vibrationPattern: Int64List.fromList([0, 200, 100, 200]),
          ),
        ),
      );

      // Guardar que ya notificamos para no repetir (Anti-Spam)
      await prefs.setString('last_notified_ota_version', latestVersion);

      if (context.mounted) {
        showDialog(
          context: context,
          barrierDismissible: !isRequired,
          builder: (context) => UpdateProgressDialog(
            downloadUrl: downloadUrl,
            version: latestVersion,
            isRequired: isRequired,
          ),
        );
      }
    } else if (manual && context.mounted) {
      UiUtils.showSuccess("Argos está al día (v$currentVersion)");
    }
  }
}
