import 'package:flutter/material.dart';
import '../../../core/network/api_service.dart';
import '../../../core/ui/argos_background.dart';
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
              // Icono de éxito pulsante
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.redAccent.withValues(alpha: 0.1),
                  border: Border.all(color: Colors.redAccent, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.redAccent.withValues(alpha: 0.3),
                      blurRadius: 30,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Icon(Icons.security_rounded,
                    color: Colors.redAccent, size: 60),
              ),
              const SizedBox(height: 40),
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

              // Botón de Clasificar
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (widget.alertaId != null) {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => IncidentClassificationScreen(
                              alertaId: widget.alertaId!),
                        ),
                      );
                    } else {
                      Navigator.pop(context);
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                  ),
                  child: const Text("CLASIFICAR INCIDENTE",
                      style: TextStyle(
                          fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),

              const SizedBox(height: 20),

              // Botón de Falsa Alarma
              TextButton(
                onPressed: _cancelAlert,
                child: Text(
                  "FUE UNA FALSA ALARMA (CANCELAR)",
                  style: TextStyle(
                    color: textColor.withValues(alpha: 0.5),
                    fontWeight: FontWeight.bold,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
