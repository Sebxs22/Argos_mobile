import 'package:flutter/material.dart';
import '../../../core/network/api_service.dart';
import '../../../core/ui/argos_background.dart';
import '../../../core/ui/glass_box.dart';
import 'incident_classification_screen.dart';

class AlertConfirmationScreen extends StatefulWidget {
  final String? alertaId;
  const AlertConfirmationScreen({super.key, this.alertaId});

  @override
  State<AlertConfirmationScreen> createState() =>
      _AlertConfirmationScreenState();
}

class _AlertConfirmationScreenState extends State<AlertConfirmationScreen> {
  final ApiService _apiService = ApiService();

  Future<void> _cancelAlert() async {
    if (widget.alertaId != null) {
      await _apiService.cancelarAlerta(widget.alertaId!);
      if (mounted) Navigator.pop(context);
    } else {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return ArgosBackground(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icono central con efecto Aura
              Stack(
                alignment: Alignment.center,
                children: [
                  Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.redAccent.withValues(alpha: 0.05),
                    ),
                  ),
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.redAccent.withValues(alpha: 0.4),
                          blurRadius: 40,
                          spreadRadius: 10,
                        ),
                      ],
                    ),
                  ),
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.redAccent, width: 3),
                      color: Colors.redAccent.withValues(alpha: 0.1),
                    ),
                    child: const Icon(Icons.shield_rounded,
                        color: Colors.redAccent, size: 50),
                  ),
                ],
              ),
              const SizedBox(height: 50),
              Text(
                "¡ALERTA ENVIADA!",
                style: TextStyle(
                  color: textColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                "Tus guardianes han sido notificados.\nLa ayuda va en camino.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: textColor.withValues(alpha: 0.7),
                  fontSize: 16,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 60),

              // Card de vidrio para la acción principal
              GlassBox(
                borderRadius: 30,
                opacity: isDark ? 0.1 : 0.05,
                blur: 10,
                padding: const EdgeInsets.all(25),
                child: Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2563EB), Color(0xFF1E40AF)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.blueAccent.withValues(alpha: 0.3),
                              blurRadius: 15,
                              offset: const Offset(0, 5),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: () {
                            if (widget.alertaId != null) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      IncidentClassificationScreen(
                                          alertaId: widget.alertaId!),
                                ),
                              );
                            } else {
                              Navigator.pop(context);
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 20),
                            shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(20)),
                          ),
                          child: const Text("CLASIFICAR INCIDENTE",
                              style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _cancelAlert,
                      child: Text(
                        "CANCELAR FALSA ALARMA",
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.4),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
