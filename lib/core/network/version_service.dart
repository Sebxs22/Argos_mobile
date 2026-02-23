import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../ui/update_progress_dialog.dart';
import '../utils/ui_utils.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';

class VersionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> checkForUpdates(BuildContext context,
      {bool manual = false}) async {
    try {
      // Usamos maybeSingle() para evitar excepciones si la tabla está vacía
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
        UiUtils.showError("Error al verificar versión");
      }
    }
  }

  // v2.9.1: Mantenemos el listener pero con manejo de errores robusto
  void listenForUpdates(BuildContext context) {
    try {
      _supabase
          .from('app_config')
          .stream(primaryKey: ['id']) // Asegúrate que 'id' exista
          .listen((List<Map<String, dynamic>> data) {
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

    // 3. Comparar (Lógica v2.9.1: Solo si la remota es distinta)
    if (currentVersion != latestVersion) {
      // IMPORTANTE: Hemos quitado 'notificarNuevaVersion' de aquí.
      // El broadcast global NO debe hacerlo el cliente para evitar bucles.

      // Notificación local de respaldo
      final FlutterLocalNotificationsPlugin notifications =
          FlutterLocalNotificationsPlugin();

      // Evitar spam de notificaciones locales si ya se mostró el diálogo
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
