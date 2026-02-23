import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/ui/argos_background.dart';
import '../../../../core/ui/glass_box.dart';

class PermissionExplanationScreen extends StatefulWidget {
  final VoidCallback onPermissionsGranted;
  const PermissionExplanationScreen(
      {super.key, required this.onPermissionsGranted});

  @override
  State<PermissionExplanationScreen> createState() =>
      _PermissionExplanationScreenState();
}

class _PermissionExplanationScreenState
    extends State<PermissionExplanationScreen> {
  bool _isChecking = false;

  Future<void> _requestPermissions() async {
    setState(() => _isChecking = true);

    // 1. Pedir Notificaciones (Base)
    await Permission.notification.request();

    // 2. Pedir Ubicación (While in Use)
    PermissionStatus status = await Permission.location.request();

    if (status.isGranted) {
      // 3. Pedir Ubicación (Always) - Solo si se aceptó el anterior
      await Permission.locationAlways.request();
    }

    // 4. Ignorar optimización de batería (Opcional pero recomendado para background)
    await Permission.ignoreBatteryOptimizations.request();

    setState(() => _isChecking = false);
    _checkAndProceed();
  }

  Future<void> _checkAndProceed() async {
    final locationStatus = await Permission.locationAlways.status;
    final notificationStatus = await Permission.notification.status;

    if (locationStatus.isGranted && notificationStatus.isGranted) {
      widget.onPermissionsGranted();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return ArgosBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 30),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(),

                // Icono Central Premium
                Container(
                  padding: const EdgeInsets.all(25),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    border: Border.all(
                        color: const Color(0xFFE53935).withValues(alpha: 0.3),
                        width: 2),
                  ),
                  child: const Icon(
                    Icons.security_rounded,
                    color: Color(0xFFE53935),
                    size: 80,
                  ),
                ),

                const SizedBox(height: 40),

                Text(
                  "Configuración de Seguridad",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),

                const SizedBox(height: 20),

                Text(
                  "Para que ARGOS pueda protegerte y avisar a tu círculo de confianza en tiempo real, necesitamos los siguientes accesos críticos:",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.7),
                    fontSize: 15,
                    height: 1.5,
                  ),
                ),

                const SizedBox(height: 40),

                // Lista de Permisos
                _buildPermissionRule(
                  icon: Icons.location_on_rounded,
                  title: "Ubicación 'Siempre'",
                  desc:
                      "Permite rastrearte incluso si la app está cerrada o el teléfono bloqueado.",
                  isDark: isDark,
                ),
                const SizedBox(height: 15),
                _buildPermissionRule(
                  icon: Icons.notifications_active_rounded,
                  title: "Notificaciones Críticas",
                  desc:
                      "Para que tú y tus guardianes reciban alertas inmediatas de emergencia.",
                  isDark: isDark,
                ),

                const SizedBox(height: 15),

                _buildPermissionRule(
                  icon: Icons.battery_saver_rounded,
                  title: "Sin Restricciones de Batería",
                  desc:
                      "En la configuración de la app, selecciona 'Batería' > 'Sin restricciones' para evitar que el sistema cierre ARGOS.",
                  isDark: isDark,
                ),

                const SizedBox(height: 50), // v2.14.1: Más aire antes del botón

                // Botón Acción
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: _isChecking ? null : _requestPermissions,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    child: _isChecking
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "CONCEDER ACCESOS",
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                letterSpacing: 1.2),
                          ),
                  ),
                ),

                const SizedBox(height: 20),

                TextButton(
                  onPressed: () => openAppSettings(),
                  child: Text(
                    "Abrir ajustes del sistema",
                    style: TextStyle(
                        color: textColor.withValues(alpha: 0.5), fontSize: 13),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPermissionRule({
    required IconData icon,
    required String title,
    required String desc,
    required bool isDark,
  }) {
    return GlassBox(
      borderRadius: 15,
      opacity: isDark ? 0.05 : 0.03,
      padding: const EdgeInsets.all(15),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFFE53935), size: 30),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  desc,
                  style: TextStyle(
                    color: isDark ? Colors.white54 : Colors.black54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
