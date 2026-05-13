import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';
import '../../../core/utils/ui_tokens.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../../main.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passController = TextEditingController();
  final _confirmPassController = TextEditingController();
  final _auth = AuthService();
  bool _isLoading = false;

  void _handleReset() async {
    final pass = _passController.text;
    final confirm = _confirmPassController.text;

    if (pass.isEmpty || confirm.isEmpty) {
      UiUtils.showWarning("Completa ambos campos");
      return;
    }

    if (pass != confirm) {
      UiUtils.showError("Las contraseñas no coinciden");
      return;
    }

    if (pass.length < 6) {
      UiUtils.showError("La contraseña debe tener al menos 6 caracteres");
      return;
    }

    setState(() => _isLoading = true);

    final error = await _auth.actualizarContrasena(pass);

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        UiUtils.showSuccess("Contraseña actualizada correctamente");
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigator()),
          (route) => false,
        );
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
        body: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(30),
            child: Column(
              children: [
                Icon(
                  Icons.vpn_key_rounded,
                  color: UiTokens.argosRed,
                  size: 60,
                ),
                const SizedBox(height: 25),
                Text(
                  "NUEVA CONTRASEÑA",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  "Ingresa tu nueva clave de acceso para continuar.",
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
                        controller: _passController,
                        hint: "Nueva contraseña",
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                      ),
                      const SizedBox(height: 15),
                      _buildInputField(
                        controller: _confirmPassController,
                        hint: "Confirmar contraseña",
                        icon: Icons.lock_reset_rounded,
                        isPassword: true,
                      ),
                      const SizedBox(height: 35),
                      _isLoading
                          ? CircularProgressIndicator(color: UiTokens.argosRed)
                          : ElevatedButton(
                              onPressed: _handleReset,
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
                                "ACTUALIZAR CONTRASEÑA",
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
    bool isPassword = false,
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
        obscureText: isPassword,
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
