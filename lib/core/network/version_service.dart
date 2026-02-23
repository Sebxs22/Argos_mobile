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
      debugPrint("📡 ARGOS OTA: Iniciando chequeo manual=$manual");

      // Consultamos específicamente el ID 1 (el que usa el GitHub Action)
      final response =
          await _supabase.from('app_config').select().eq('id', 1).maybeSingle();

      if (response == null) {
        debugPrint("⚠️ ARGOS OTA: Fila id=1 no encontrada en app_config.");
        if (manual && context.mounted) {
          UiUtils.showError(
              "Servicio de actualización no disponible (Fila 1 vacía)");
        }
        return;
      }

      debugPrint("✅ ARGOS OTA: Datos recibidos: $response");

      if (!context.mounted) return;
      await _processUpdate(context, response, manual: manual);
    } catch (e) {
      debugPrint("❌ ARGOS OTA Error Crítico: $e");
      if (manual && context.mounted) {
        UiUtils.showError("Error al verificar versión: $e");
      }
    }
  }

  void listenForUpdates(BuildContext context) {
    try {
      debugPrint("📡 ARGOS OTA: Iniciando Stream Listener...");
      _supabase
          .from('app_config')
          .stream(primaryKey: ['id'])
          .eq('id', 1) // Escuchar solo la fila principal
          .listen((List<Map<String, dynamic>> data) {
            if (data.isNotEmpty && context.mounted) {
              debugPrint(
                  "🚀 ARGOS OTA Stream: Cambio detectado! Procesando...");
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
    try {
      // 1. Obtener versión local
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      String latestVersion = data['version_actual'] ?? "";
      String downloadUrl = data['link_descarga'] ?? "";
      bool isRequired = data['es_obligatoria'] ?? false;

      debugPrint("📊 ARGOS OTA: Local=$currentVersion, Remota=$latestVersion");

      if (latestVersion.isEmpty) {
        debugPrint("⚠️ ARGOS OTA: La versión remota está vacía.");
        return;
      }

      // 2. Lógica Anti-Spam
      final prefs = await SharedPreferences.getInstance();
      final String lastNotified =
          prefs.getString('last_notified_ota_version') ?? "";

      if (latestVersion == lastNotified && !manual) {
        debugPrint(
            "ℹ️ ARGOS OTA: Ya notificamos la v$latestVersion, ignorando.");
        return;
      }

      // 3. Comparación de versiones (Lógica simple: si es diferente y Supabase > Local)
      // Nota: En el futuro podrías usar Version.parse(v1) > Version.parse(v2)
      if (currentVersion != latestVersion) {
        debugPrint(
            "🔔 ARGOS OTA: ¡Nueva versión disponible! Mostrando diálogo...");

        // Notificación local de respaldo
        final FlutterLocalNotificationsPlugin notifications =
            FlutterLocalNotificationsPlugin();

        await notifications.show(
          id: 777,
          title: '🚀 ACTUALIZACIÓN DISPONIBLE (v$latestVersion)',
          body: 'Nuevas funciones de seguridad listas para instalar.',
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

        // Guardar que ya notificamos
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
        debugPrint("✅ ARGOS OTA: La app está actualizada.");
        UiUtils.showSuccess("Argos está al día (v$currentVersion)");
      }
    } catch (e) {
      debugPrint("❌ ARGOS OTA Error en _processUpdate: $e");
      if (manual && context.mounted) {
        UiUtils.showError("Error al procesar actualización: $e");
      }
    }
  }
}
