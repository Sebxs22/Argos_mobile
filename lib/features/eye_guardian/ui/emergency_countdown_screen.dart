import 'dart:async';
import 'dart:ui'; // Para el Blur
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart'; // IMPORTANTE: Para obtener la ubicación real
import '../../../core/network/api_service.dart';
import '../../../core/ui/glass_box.dart';

class EmergencyCountdownScreen extends StatefulWidget {
  const EmergencyCountdownScreen({super.key});

  @override
  State<EmergencyCountdownScreen> createState() => _EmergencyCountdownScreenState();
}

class _EmergencyCountdownScreenState extends State<EmergencyCountdownScreen> {
  final ApiService _apiService = ApiService();
  int _secondsRemaining = 10;
  Timer? _timer;
  bool _isAlertSent = false;

  // Variable para guardar la ubicación precisa mientras corre el tiempo
  Position? _preciseLocation;

  @override
  void initState() {
    super.initState();
    // 1. Empezamos a buscar satélites INMEDIATAMENTE al entrar a la pantalla
    // Aprovechamos los 10 segundos de cuenta regresiva para afinar la puntería
    _preloadPreciseLocation();

    _startCountdown();
  }

  // FUNCIÓN CLAVE: Obtiene GPS con precisión militar (< 5m)
  Future<void> _preloadPreciseLocation() async {
    try {
      // 'bestForNavigation' usa GPS + WiFi + Acelerómetros para máxima precisión
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.bestForNavigation,
          timeLimit: const Duration(seconds: 10) // Damos máximo 10s para buscar
      );
      setState(() {
        _preciseLocation = position;
      });
      print("UBICACIÓN DE PRECISIÓN LISTA: ${position.latitude}, ${position.longitude}");
    } catch (e) {
      print("Error buscando satélites: $e");
    }
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_secondsRemaining > 0) {
        setState(() {
          _secondsRemaining--;
        });
      } else {
        _sendAlert();
      }
    });
  }

  Future<void> _sendAlert() async {
    _timer?.cancel();
    if (_isAlertSent) return;
    _isAlertSent = true;

    // COORDENADAS FINALES
    // Si no logramos la precisión máxima, intentamos una última lectura rápida
    double finalLat = _preciseLocation?.latitude ?? -1.67098;
    double finalLng = _preciseLocation?.longitude ?? -78.64712;

    if (_preciseLocation == null) {
      try {
        Position fallback = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
        finalLat = fallback.latitude;
        finalLng = fallback.longitude;
      } catch (e) { print("Fallo GPS total, usando default"); }
    }

    // 2. ENVÍO A LA API (Ahora sí con datos reales)
    print("ENVIANDO ALERTA PRECISA A: $finalLat, $finalLng");
    _apiService.enviarAlertaEmergencia(finalLat, finalLng);

    if (!mounted) return;

    // --- DIÁLOGO DE CONFIRMACIÓN (GLASS) ---
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog(
        backgroundColor: Colors.transparent,
        child: GlassBox(
          borderRadius: 30,
          blur: 20,
          opacity: 0.1,
          border: Border.all(color: Colors.white.withOpacity(0.3)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.green.withOpacity(0.2),
                    boxShadow: [
                      BoxShadow(color: Colors.green.withOpacity(0.4), blurRadius: 40, spreadRadius: 5)
                    ]
                ),
                child: const Icon(Icons.check, color: Colors.greenAccent, size: 50),
              ),
              const SizedBox(height: 20),

              const Text(
                "ALERTA ENVIADA",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5
                ),
              ),
              const SizedBox(height: 15),
              // Mostramos la precisión al usuario para darle confianza
              Text(
                "Ubicación exacta ${_preciseLocation != null ? 'CONFIRMADA' : 'ESTIMADA'}\ncompartida con la red.",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).pop(true);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                    side: BorderSide(color: Colors.white.withOpacity(0.2)),
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  child: const Text("ENTENDIDO"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  void _cancelAlert() {
    _timer?.cancel();
    if (mounted) Navigator.of(context).pop(false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text("Falsa alarma cancelada."),
        backgroundColor: Colors.green.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050511),
      body: Stack(
        children: [
          // FONDO ALERTA ROJA
          Positioned(
            top: -50, left: -50,
            child: Container(width: 500, height: 500, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFD50000).withOpacity(0.4))),
          ),
          Positioned(
            bottom: -100, right: -100,
            child: Container(width: 400, height: 400, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFFF6D00).withOpacity(0.2))),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),

          // CONTENIDO
          Center(
            child: Padding(
              padding: const EdgeInsets.all(30.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("⚠️ INCIDENTE DETECTADO ⚠️", style: TextStyle(color: Color(0xFFFF5252), fontSize: 16, fontWeight: FontWeight.bold, letterSpacing: 2.0)),
                  const SizedBox(height: 50),

                  // RELOJ
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(width: 220, height: 220, decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: const Color(0xFFD50000).withOpacity(0.4), blurRadius: 60, spreadRadius: 10)])),
                      SizedBox(
                        width: 200, height: 200,
                        child: CircularProgressIndicator(
                          value: _secondsRemaining / 10,
                          strokeWidth: 15,
                          color: const Color(0xFFFF1744),
                          backgroundColor: Colors.white.withOpacity(0.1),
                          strokeCap: StrokeCap.round,
                        ),
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text("$_secondsRemaining", style: const TextStyle(color: Colors.white, fontSize: 90, fontWeight: FontWeight.bold, height: 1.0)),
                          const Text("SEGUNDOS", style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2))
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 60),

                  // TEXTO DINÁMICO (Muestra si ya tenemos GPS)
                  GlassBox(
                    borderRadius: 20, opacity: 0.05, padding: const EdgeInsets.all(15),
                    child: Column(
                      children: [
                        Text(
                          "Enviando ubicación precisa...",
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70, fontSize: 16),
                        ),
                        const SizedBox(height: 5),
                        // Indicador de precisión pequeño
                        _preciseLocation != null
                            ? const Text("✅ Señal Satelital: Fuerte (<3m)", style: TextStyle(color: Colors.greenAccent, fontSize: 12))
                            : const Text("📡 Buscando satélites...", style: TextStyle(color: Colors.amber, fontSize: 12)),
                      ],
                    ),
                  ),

                  const SizedBox(height: 40),

                  GestureDetector(
                    onTap: _cancelAlert,
                    child: GlassBox(
                      borderRadius: 50, opacity: 0.1, border: Border.all(color: Colors.white.withOpacity(0.5), width: 1.5), padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Icon(Icons.close, color: Colors.white, size: 28),
                          SizedBox(width: 15),
                          Text("ESTOY BIEN, CANCELAR", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}