import 'package:package_info_plus/package_info_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';
import '../ui/update_progress_dialog.dart';

class VersionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<void> checkForUpdates(BuildContext context) async {
    try {
      // 1. Obtener versión local
      PackageInfo packageInfo = await PackageInfo.fromPlatform();
      String currentVersion = packageInfo.version;

      // 2. Obtener versión remota de Supabase
      final data = await _supabase.from('app_config').select().single();

      String latestVersion = data['version_actual'];
      String downloadUrl = data['link_descarga'];
      bool isRequired = data['es_obligatoria'] ?? false;

      // 3. Comparar (Lógica simple de strings para este MVP)
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
      }
    } catch (e) {
      debugPrint("Error checking for updates: $e");
    }
  }
}
