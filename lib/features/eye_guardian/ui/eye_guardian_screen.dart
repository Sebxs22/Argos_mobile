import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import v2.7.0
import 'package:flutter_background_service/flutter_background_service.dart';

import '../../../core/ui/glass_box.dart';
import '../../../core/utils/ui_tokens.dart'; // v2.14.9

class EyeGuardianScreen extends StatefulWidget {
  const EyeGuardianScreen({super.key});

  @override
  State<EyeGuardianScreen> createState() => _EyeGuardianScreenState();
}

enum GuardianState { monitoring, sending, success }

class _EyeGuardianScreenState extends State<EyeGuardianScreen>
    with TickerProviderStateMixin {
  GuardianState _currentState = GuardianState.monitoring;
  final int _sentAlertsCount = 0;

  late AnimationController _pulseController;
  late AnimationController _rotateController;

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
  }

  void _triggerManualAlert() {
    setState(() => _currentState = GuardianState.sending);
    FlutterBackgroundService().invoke('onManualAlert');
    HapticFeedback.vibrate(); // v2.8.4 Tactile confirmation on send

    // El MainNavigator se encargará de mostrar la pantalla de éxito.
    // Nosotros reseteamos nuestro estado local después de un breve delay
    // para que el usuario sienta la transición.
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) setState(() => _currentState = GuardianState.monitoring);
    });
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
    final textColor = UiTokens.textColor(context);
    final secondaryTextColor = UiTokens.secondaryTextColor(context);

    switch (_currentState) {
      case GuardianState.sending:
        mainColor = UiTokens.argosRed;
        glowColor = UiTokens.argosRed;
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
        // v2.14.9: Glacial Blue Premium adaptativo
        mainColor = isDark ? const Color(0xFFB3E5FC) : UiTokens.glacialBlue;
        glowColor = isDark
            ? Colors.blueAccent.withValues(alpha: 0.8)
            : UiTokens.glacialBlue.withValues(alpha: 0.6);
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
                                        : UiTokens.glacialBlue)
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

            // BOTÓN MANUAL (v2.7.0: Ajustado para evitar nav bar flotante)
            Padding(
              padding: const EdgeInsets.only(bottom: 130.0),
              child: GestureDetector(
                onTap: () {
                  // v2.8.4: No vibrate on touch, only on success
                  _triggerManualAlert();
                },
                child: GlassBox(
                  borderRadius: 30,
                  // v2.8.0: Refinamiento premium solicitado
                  border: Border.all(
                    color: isDark
                        ? Colors.white.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.2), // Más contraste
                    width: 0.8,
                  ),
                  child: Container(
                    decoration: isDark
                        ? BoxDecoration(
                            borderRadius: BorderRadius.circular(30),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.05),
                                blurRadius: 20,
                                spreadRadius: 2,
                              )
                            ],
                          )
                        : null,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 45,
                      vertical: 10, // v2.8.7: Más estilizado y delgado
                    ),
                    child: Text(
                      "ACTIVACIÓN MANUAL",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 11, // v2.8.7: Tipografía más fina
                        letterSpacing: 1.2, // v2.8.7: Glifos más juntos
                        shadows: isDark
                            ? [
                                const Shadow(
                                  color: Colors.white24,
                                  blurRadius: 10,
                                )
                              ]
                            : null,
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
