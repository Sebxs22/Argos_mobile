import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../ui/update_progress_dialog.dart';
import '../utils/ui_utils.dart';
import 'package:shared_preferences/shared_preferences.dart';

class VersionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> checkForUpdates(BuildContext context,
      {bool manual = false}) async {
    try {
      debugPrint("📡 ARGOS OTA: Iniciando chequeo manual=$manual");

      final response =
          await _supabase.from('app_config').select().eq('id', 1).maybeSingle();

      if (response == null) {
        debugPrint("⚠️ ARGOS OTA: Fila id=1 no encontrada.");
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
      _supabase
          .from('app_config')
          .stream(primaryKey: ['id'])
          .eq('id', 1)
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
    try {
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      String latestVersion = data['version_actual'] ?? "";
      String downloadUrl = data['link_descarga'] ?? "";
      bool isRequired = data['es_obligatoria'] ?? false;

      if (latestVersion.isEmpty) return;

      // Lógica Anti-Spam para el diálogo automático
      final prefs = await SharedPreferences.getInstance();
      final String lastNotified =
          prefs.getString('last_notified_ota_version') ?? "";

      if (latestVersion == lastNotified && !manual) {
        debugPrint("ℹ️ ARGOS OTA: Versión $latestVersion ya procesada.");
        return;
      }

      // Comparación
      if (currentVersion != latestVersion) {
        debugPrint("🔔 ARGOS OTA: Nueva versión detectada: $latestVersion");

        // Guardar que ya notificamos para este diálogo
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
    } catch (e) {
      debugPrint("❌ ARGOS OTA Error en _processUpdate: $e");
    }
  }
}
