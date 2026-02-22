import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';
import '../../../core/utils/ui_utils.dart'; // Import UiUtils
import '../../../../main.dart'; // Para navegar al MainNavigator
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _auth = AuthService();
  bool _isLoading = false;

  void _handleLogin() async {
    if (_emailController.text.isEmpty || _passController.text.isEmpty) {
      UiUtils.showWarning("Por favor, completa todos los campos");
      return;
    }

    setState(() => _isLoading = true);

    final error = await _auth.iniciarSesion(
      email: _emailController.text.trim(),
      password: _passController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        UiUtils.showSuccess("Bienvenido a ARGOS");
        // Navegamos al MainNavigator para tener acceso a todas las pestañas
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigator()),
        );
      } else {
        UiUtils.showError(error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white38 : Colors.black45;

    return ArgosBackground(
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              // Logo Principal
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.03)
                      : Colors.black.withValues(alpha: 0.02),
                  border: Border.all(
                    color: isDark ? Colors.white10 : Colors.black12,
                  ),
                ),
                child: Icon(
                  Icons.shield_moon_outlined,
                  color: const Color(0xFFE53935),
                  size: 50,
                ),
              ),
              const SizedBox(height: 25),
              Text(
                "ARGOS",
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 8,
                  color: textColor,
                ),
              ),
              Text(
                "SISTEMA DE PROTECCIÓN URBANA",
                style: TextStyle(
                  fontSize: 10,
                  letterSpacing: 2,
                  color: secondaryTextColor,
                ),
              ),
              const SizedBox(height: 50),

              // Caja de Login (Glass)
              GlassBox(
                borderRadius: 30,
                opacity: isDark ? 0.08 : 0.05,
                blur: 25,
                padding: const EdgeInsets.all(30),
                child: Column(
                  children: [
                    _buildInputField(
                      controller: _emailController,
                      hint: "Correo Electrónico",
                      icon: Icons.alternate_email,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 20),
                    _buildInputField(
                      controller: _passController,
                      hint: "Contraseña",
                      icon: Icons.lock_outline,
                      isPassword: true,
                      isDark: isDark,
                    ),
                    const SizedBox(height: 35),
                    _isLoading
                        ? const CircularProgressIndicator(
                            color: Color(0xFFE53935),
                          )
                        : ElevatedButton(
                            onPressed: _handleLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 55),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: const Text(
                              "INICIAR SESIÓN",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                  ],
                ),
              ),

              const SizedBox(height: 30),

              // Botón para ir al Registro
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const RegisterScreen(),
                    ),
                  );
                },
                child: RichText(
                  text: TextSpan(
                    text: "¿No tienes una cuenta? ",
                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                    children: const [
                      TextSpan(
                        text: "Regístrate",
                        style: TextStyle(
                          color: Color(0xFFE53935),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget para mantener los inputs con el estilo de la app
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool isDark = true,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black87,
          fontSize: 15,
        ),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(
            color: isDark ? Colors.white24 : Colors.black38,
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: isDark ? Colors.white54 : Colors.black45,
            size: 20,
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}
