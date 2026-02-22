import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../../core/ui/glass_box.dart';
import 'alert_confirmation_screen.dart';

class EyeGuardianScreen extends StatefulWidget {
  const EyeGuardianScreen({super.key});

  @override
  State<EyeGuardianScreen> createState() => _EyeGuardianScreenState();
}

enum GuardianState { monitoring, sending, success }

class _EyeGuardianScreenState extends State<EyeGuardianScreen>
    with TickerProviderStateMixin {
  GuardianState _currentState = GuardianState.monitoring;
  int _sentAlertsCount = 0;

  late AnimationController _pulseController;
  late AnimationController _rotateController;

  // TU COLOR ROJO EXACTO
  final Color _argosRed = const Color(0xFFE53935);

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _rotateController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    // ESCUCHAR AL GUARDIÁN DE FONDO (El Sensor Maestro)
    _listenToBackgroundService();
  }

  void _listenToBackgroundService() {
    FlutterBackgroundService().on('onShake').listen((event) {
      if (mounted) {
        _handleBackgroundShake(event);
      }
    });
  }

  void _handleBackgroundShake(Map<String, dynamic>? data) {
    if (_currentState != GuardianState.monitoring) return;

    final String? alertaId = data?['alertaId'];

    setState(() {
      _currentState = GuardianState.success;
      _sentAlertsCount++;
    });

    // Navegar a confirmación si estamos en esta pantalla
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => AlertConfirmationScreen(alertaId: alertaId),
          ),
        ).then((_) {
          if (mounted) setState(() => _currentState = GuardianState.monitoring);
        });
      }
    });
  }

  void _triggerManualAlert() {
    setState(() => _currentState = GuardianState.sending);
    FlutterBackgroundService().invoke('onManualAlert');
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _rotateController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Color mainColor;
    Color glowColor;
    IconData centerIcon;
    String statusSubtext;

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white38 : Colors.black45;

    switch (_currentState) {
      case GuardianState.sending:
        mainColor = _argosRed;
        glowColor = _argosRed;
        centerIcon = Icons.upload_rounded;
        statusSubtext = "ENVIANDO DATOS...";
        break;
      case GuardianState.success:
        mainColor = const Color(0xFF00E676);
        glowColor = Colors.greenAccent;
        centerIcon = Icons.check_circle_outline_rounded;
        statusSubtext = "ALERTA RECIBIDA";
        break;
      default:
        // ESTILO ORIGINAL PERO MÁS AZULADO (Azul Glacial Premium)
        mainColor = isDark ? const Color(0xFFB3E5FC) : Colors.blue.shade900;
        glowColor = isDark
            ? Colors.blueAccent.withValues(alpha: 0.8)
            : Colors.blue.shade400;
        centerIcon = Icons.verified_user_sharp;
        statusSubtext = "SISTEMA PROTEGIDO";
        break;
    }

    return Scaffold(
      // === CLAVE DEL ÉXITO ===
      // Fondo transparente para que se vea la Aurora del MainNavigator
      backgroundColor: Colors.transparent,

      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(
              height: 10,
            ), // Espacio pequeño, el padding lo maneja el Main
            // TÍTULO ARGOS
            Text(
              "ARGOS SYSTEM",
              style: TextStyle(
                color: textColor,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: 5.0,
                shadows: [
                  Shadow(
                    color: glowColor.withValues(alpha: isDark ? 0.5 : 0.3),
                    blurRadius: 20,
                  ),
                  if (!isDark)
                    Shadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // CONTADOR DE ALERTAS
            AnimatedOpacity(
              duration: const Duration(milliseconds: 500),
              opacity: _sentAlertsCount > 0 ? 1.0 : 0.0,
              child: GlassBox(
                borderRadius: 20,
                opacity: isDark ? 0.1 : 0.05,
                blur: 5,
                padding: const EdgeInsets.symmetric(
                  horizontal: 15,
                  vertical: 6,
                ),
                child: Text(
                  "$_sentAlertsCount ALERTAS ENVIADAS",
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),

            // ZONA CENTRAL: EL OJO
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 300,
                      height: 300,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          // Anillos
                          RotationTransition(
                            turns: _rotateController,
                            child: Container(
                              width: 280,
                              height: 280,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: mainColor.withValues(alpha: 0.3),
                                  width: 1,
                                ),
                              ),
                              child: Align(
                                alignment: Alignment.topCenter,
                                child: Container(
                                  width: 4,
                                  height: 10,
                                  color: mainColor.withValues(alpha: 0.8),
                                ),
                              ),
                            ),
                          ),
                          RotationTransition(
                            turns: ReverseAnimation(_rotateController),
                            child: Container(
                              width: 220,
                              height: 220,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: mainColor.withValues(alpha: 0.4),
                                  width: 2,
                                ),
                              ),
                            ),
                          ),
                          // Núcleo
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 400),
                            width: _currentState == GuardianState.sending
                                ? 160
                                : 140,
                            height: _currentState == GuardianState.sending
                                ? 160
                                : 140,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: mainColor.withValues(alpha: 0.1),
                              boxShadow: [
                                BoxShadow(
                                  color: glowColor.withValues(alpha: 0.5),
                                  blurRadius:
                                      _currentState == GuardianState.sending
                                          ? 70
                                          : 40,
                                  spreadRadius: 5,
                                ),
                              ],
                              border: Border.all(
                                color: mainColor.withValues(alpha: 0.7),
                                width: 2,
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                centerIcon,
                                key: ValueKey(_currentState),
                                size: 70,
                                color: _currentState == GuardianState.monitoring
                                    ? (isDark
                                        ? Colors.white
                                        : Colors.blue.shade900)
                                    : Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 25),
                    // Subtexto
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: Text(
                        statusSubtext,
                        key: ValueKey(statusSubtext),
                        style: TextStyle(
                          color: secondaryTextColor,
                          fontSize: 12,
                          letterSpacing: 2.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // BOTÓN MANUAL
            Padding(
              padding: const EdgeInsets.only(bottom: 50.0),
              child: GestureDetector(
                onTap: _triggerManualAlert,
                child: GlassBox(
                  borderRadius: 30,
                  opacity: isDark ? 0.1 : 0.05,
                  blur: 10,
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black12,
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 60,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.05)
                          : Colors.white.withValues(alpha: 0.7),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: !isDark
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              )
                            ]
                          : [],
                    ),
                    child: Text(
                      "ACTIVACIÓN MANUAL",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        letterSpacing: 2.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
