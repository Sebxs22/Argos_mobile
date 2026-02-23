import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../ui/update_progress_dialog.dart';
import '../utils/ui_utils.dart'; // Import UiUtils (v2.6.6)
import 'api_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:typed_data';

class VersionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> checkForUpdates(BuildContext context,
      {bool manual = false}) async {
    try {
      final data = await _supabase.from('app_config').select().single();
      await _processUpdate(context, data, manual: manual);
    } catch (e) {
      debugPrint("Error checking for updates: $e");
      if (manual && context.mounted) {
        UiUtils.showError("No se pudo verificar la versión");
      }
    }
  }

  // v2.8.9: Escucha en tiempo real cambios en Supabase para broadcast automático
  void listenForUpdates(BuildContext context) {
    _supabase
        .from('app_config')
        .stream(primaryKey: ['id']).listen((List<Map<String, dynamic>> data) {
      if (data.isNotEmpty && context.mounted) {
        _processUpdate(context, data.first, manual: false);
      }
    });
  }

  Future<void> _processUpdate(BuildContext context, Map<String, dynamic> data,
      {bool manual = false}) async {
    // 1. Obtener versión local
    PackageInfo packageInfo = await PackageInfo.fromPlatform();
    String currentVersion = packageInfo.version;

    String latestVersion = data['version_actual'];
    String downloadUrl = data['link_descarga'];
    bool isRequired = data['es_obligatoria'] ?? false;

    // 3. Comparar
    if (currentVersion != latestVersion) {
      // v2.8.7: Notificación Push real vía OneSignal (BROADCAST)
      // v2.8.9: Se dispara automáticamente al detectar cambio en Supabase
      final apiService = ApiService();
      await apiService.notificarNuevaVersion(latestVersion);

      // Notificación local de respaldo
      final FlutterLocalNotificationsPlugin notifications =
          FlutterLocalNotificationsPlugin();
      await notifications.show(
        id: 777,
        title: '🚀 NUEVA VERSIÓN DISPONIBLE: v$latestVersion',
        body:
            'ARGOS se ha actualizado. Toca para ver las novedades y descargar.',
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'argos_updates',
            'Actualizaciones ARGOS',
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
