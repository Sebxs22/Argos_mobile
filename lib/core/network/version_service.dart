import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../ui/update_progress_dialog.dart';

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
        // Si es manual y ya está actualizado
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text("🚀 Argos está actualizado (v${packageInfo.version})"),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
      if (manual && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("❌ Error al verificar la versión"),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
