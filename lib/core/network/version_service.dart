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
      // 1. Obtener versión local
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Obtener versión remota de Supabase
      final data = await _supabase.from('app_config').select().single();

      String latestVersion = data['version_actual'];
      String downloadUrl = data['link_descarga'];
      bool isRequired = data['es_obligatoria'] ?? false;

      // 3. Comparar
      if (currentVersion != latestVersion) {
        // v2.8.7: Notificación Push real vía OneSignal
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
        // Mejorado con UiUtils v2.6.6
        UiUtils.showSuccess("Argos está al día (v$currentVersion)");
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
      if (manual && context.mounted) {
        UiUtils.showError("No se pudo verificar la versión");
      }
    }
  }
}
