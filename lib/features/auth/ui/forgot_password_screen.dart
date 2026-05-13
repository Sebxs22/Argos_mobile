import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';
import '../../../core/utils/ui_tokens.dart';
import '../../../core/utils/ui_utils.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _auth = AuthService();
  bool _isLoading = false;

  void _handleResetRequest() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      UiUtils.showWarning("Ingresa tu correo electrónico");
      return;
    }

    setState(() => _isLoading = true);

    final error = await _auth.enviarCorreoRecuperacion(email);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        UiUtils.showSuccess("Correo de recuperación enviado");
        Navigator.pop(context); // Volver al login
      } else {
        UiUtils.showError(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = UiTokens.textColor(context);
    final secondaryTextColor = UiTokens.secondaryTextColor(context);

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
        ),
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Icon(
                  Icons.lock_reset_rounded,
                  color: UiTokens.argosRed,
                  size: 60,
                ),
                const SizedBox(height: 25),
                Text(
                  "RECUPERAR ACCESO",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Te enviaremos un correo con las instrucciones para restablecer tu contraseña.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 40),
                GlassBox(
                  borderRadius: 30,
                  child: Column(
                    children: [
                      _buildInputField(
                        controller: _emailController,
                        hint: "Correo electrónico",
                        icon: Icons.alternate_email_rounded,
                      ),
                      const SizedBox(height: 35),
                      _isLoading
                          ? CircularProgressIndicator(color: UiTokens.argosRed)
                          : ElevatedButton(
                              onPressed: _handleResetRequest,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: UiTokens.argosRed,
                                foregroundColor: Colors.white,
                                minimumSize: const Size(double.infinity, 55),
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(15),
                                ),
                              ),
                              child: const Text(
                                "ENVIAR INSTRUCCIONES",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
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
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: UiTokens.surface(context).withValues(alpha: isDark ? 0.3 : 0.8),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: UiTokens.glassBorder(context),
          width: 0.8,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.emailAddress,
        style: TextStyle(
          color: UiTokens.textColor(context),
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: UiTokens.secondaryTextColor(context),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: UiTokens.secondaryTextColor(context),
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
