import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, completa todos los campos")),
      );
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
        // Navegamos al MainNavigator para tener acceso a todas las pestañas
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigator()),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error),
            backgroundColor: const Color(0xFFE53935),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050511),
      body: Stack(
        children: [
          // --- CAPA 1: FONDO AURORA (Igual al MainNavigator) ---
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE53935).withOpacity(0.15),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2962FF).withOpacity(0.1),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),

          // --- CAPA 2: CONTENIDO ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  // Logo o Icono de Cabecera
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(Icons.shield_moon_outlined,
                        color: Color(0xFFE53935), size: 50),
                  ),
                  const SizedBox(height: 25),
                  const Text(
                    "ARGOS",
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 8,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "SISTEMA DE PROTECCIÓN URBANA",
                    style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 2,
                      color: Colors.white38,
                    ),
                  ),
                  const SizedBox(height: 50),

                  // Caja de Login (Glass)
                  GlassBox(
                    borderRadius: 30,
                    opacity: 0.05,
                    blur: 20,
                    padding: const EdgeInsets.all(30),
                    child: Column(
                      children: [
                        _buildInputField(
                          controller: _emailController,
                          hint: "Correo Electrónico",
                          icon: Icons.alternate_email,
                        ),
                        const SizedBox(height: 20),
                        _buildInputField(
                          controller: _passController,
                          hint: "Contraseña",
                          icon: Icons.lock_outline,
                          isPassword: true,
                        ),
                        const SizedBox(height: 35),

                        _isLoading
                            ? const CircularProgressIndicator(color: Color(0xFFE53935))
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
                        MaterialPageRoute(builder: (context) => const RegisterScreen()),
                      );
                    },
                    child: RichText(
                      text: const TextSpan(
                        text: "¿No tienes una cuenta? ",
                        style: TextStyle(color: Colors.white38, fontSize: 13),
                        children: [
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
        ],
      ),
    );
  }

  // Widget para mantener los inputs con el estilo de la app
  Widget _buildInputField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    bool isPassword = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: isPassword,
        style: const TextStyle(color: Colors.white, fontSize: 15),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(color: Colors.white24, fontSize: 14),
          prefixIcon: Icon(icon, color: Colors.white54, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
        ),
      ),
    );
  }
}