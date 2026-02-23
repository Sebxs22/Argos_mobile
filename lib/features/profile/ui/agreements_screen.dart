import 'package:flutter/material.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';

class AgreementsScreen extends StatelessWidget {
  const AgreementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return ArgosBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Acuerdos y Compromisos",
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(isDark, textColor),
                const SizedBox(height: 30),
                _buildSection(
                  "🤝 Compromiso de Seguridad Argos",
                  "Al utilizar ARGOS, usted acepta formar parte de una red de auxilio ciudadano sujeta a las leyes de la República del Ecuador. Su uso implica responsabilidad civil y penal.",
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                _buildAgreementItem(
                  "Cumplimiento del COIP (Art. 396)",
                  "El uso indebido de servicios de emergencia o la activación de falsas alarmas será sancionado conforme al Código Orgánico Integral Penal (COIP). ARGOS colaborará con las autoridades competentes en caso de malicia.",
                  Icons.gavel_rounded,
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                _buildAgreementItem(
                  "Protección de Datos (LOPDP)",
                  "Sus datos de ubicación son tratados bajo la Ley Orgánica de Protección de Datos Personales (LOPDP). La geolocalización solo se comparte con su círculo de confianza en eventos de emergencia activa.",
                  Icons.security_update_good_rounded,
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                _buildAgreementItem(
                  "Deber del Guardián (COIP Art. 28)",
                  "El guardián acepta el compromiso de auxilio inmediato. La omisión de socorro es analizada bajo los principios de solidaridad ciudadana establecidos en el marco legal ecuatoriano.",
                  Icons.shield_outlined,
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                _buildAgreementItem(
                  "Privacidad y Consentimiento",
                  "Al registrarse, usted otorga consentimiento expreso para el rastreo en tiempo real necesario para la funcionalidad de 'Ojo de Guardián' y el resguardo de su integridad física.",
                  Icons.lock_person_outlined,
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                const SizedBox(height: 30),
                Center(
                  child: Text(
                    "Bajo el amparo de la Ley y la Solidaridad Ciudadana.",
                    style: TextStyle(
                      color: const Color(0xFFE53935),
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(bool isDark, Color textColor) {
    return Center(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFE53935).withValues(alpha: 0.1),
              border: Border.all(
                  color: const Color(0xFFE53935).withValues(alpha: 0.3)),
            ),
            child: const Icon(
              Icons.balance_rounded,
              color: Color(0xFFE53935),
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "MARCO LEGAL Y COMPROMISO ÉTICO",
            style: TextStyle(
              color: textColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content, Color textColor,
      Color secondaryTextColor, bool isDark) {
    return GlassBox(
      borderRadius: 20,
      // v2.8.0: Usa defaults premium
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              color: secondaryTextColor,
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAgreementItem(String title, String content, IconData icon,
      Color textColor, Color secondaryTextColor, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.1) // v2.8.0
                  : Colors.black.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.1),
                width: 0.5,
              ),
            ),
            child: Icon(icon, color: const Color(0xFFE53935), size: 24),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  content,
                  style: TextStyle(
                    color: secondaryTextColor,
                    fontSize: 12,
                    height: 1.4,
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
