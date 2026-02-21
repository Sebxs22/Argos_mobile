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
                  "🤝 Compromiso Argos",
                  "Al usar esta plataforma, te unes a una red de protección mutua. Tu compromiso es fundamental para la seguridad de todos.",
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                _buildAgreementItem(
                  "Responsabilidad del Guardián",
                  "Si eres designado como guardián, te comprometes a estar atento a las notificaciones de emergencia y actuar de manera responsable para ayudar a tu protegido.",
                  Icons.shield_outlined,
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                _buildAgreementItem(
                  "Uso Ético de Alertas",
                  "Las alertas de emergencia son herramientas críticas. El uso indebido o las falsas alarmas perjudican la confianza de la red y pueden resultar en la suspensión de la cuenta.",
                  Icons.report_gmailerrorred_rounded,
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                _buildAgreementItem(
                  "Privacidad Compartida",
                  "Entiendes que tu ubicación y datos de contacto se compartirán con tus guardianes designados únicamente durante una activación de emergencia activa.",
                  Icons.lock_person_outlined,
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                _buildAgreementItem(
                  "Comunidad y Respeto",
                  "Argos es un espacio de soporte ciudadano. Mantenemos una cultura de respeto y apoyo mutuo sin excepciones.",
                  Icons.people_alt_outlined,
                  textColor,
                  secondaryTextColor,
                  isDark,
                ),
                const SizedBox(height: 20),
                Center(
                  child: Text(
                    "Juntos construimos una ciudad más segura.",
                    style: TextStyle(
                      color: const Color(0xFFE53935),
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
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
              Icons.handshake_outlined,
              color: Color(0xFFE53935),
              size: 50,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            "RED DE PROTECCIÓN CIUDADANA",
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
      opacity: isDark ? 0.08 : 0.05,
      padding: const EdgeInsets.all(20),
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
                  ? Colors.white.withValues(alpha: 0.05)
                  : Colors.black.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(12),
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
