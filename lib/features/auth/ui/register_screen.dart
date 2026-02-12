import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../../main.dart'; // Para navegar al MainNavigator tras el registro

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _auth = AuthService();
  final _nombreController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _telController = TextEditingController();
  bool _isLoading = false;

  void _handleRegister() async {
    // Validación básica
    if (_nombreController.text.isEmpty || _emailController.text.isEmpty || _passController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Por favor, llena los campos principales")),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await _auth.registrarUsuario(
      email: _emailController.text.trim(),
      password: _passController.text.trim(),
      nombre: _nombreController.text.trim(),
      telefono: _telController.text.trim(),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (error == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("¡Bienvenido a la Red ARGOS!")),
        );
        // Al registrarse, lo mandamos directo al Navigator principal
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MainNavigator()),
              (route) => false,
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Error: $error"),
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
          // --- CAPA 1: FONDO AURORA (Sinergia con MainNavigator) ---
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFF2962FF).withOpacity(0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
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
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 70, sigmaY: 70),
            child: Container(color: Colors.transparent),
          ),

          // --- CAPA 2: CONTENIDO ---
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 50),
              child: Column(
                children: [
                  // Icono superior con estilo
                  Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.03),
                      border: Border.all(color: Colors.white10),
                    ),
                    child: const Icon(Icons.shield_outlined, color: Color(0xFFE53935), size: 45),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "REGISTRO",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 6,
                      color: Colors.white,
                    ),
                  ),
                  const Text(
                    "CREA TU IDENTIDAD DE SEGURIDAD",
                    style: TextStyle(fontSize: 9, letterSpacing: 1.5, color: Colors.white38),
                  ),
                  const SizedBox(height: 40),

                  // Caja de Registro
                  GlassBox(
                    borderRadius: 30,
                    opacity: 0.05,
                    blur: 20,
                    padding: const EdgeInsets.all(25),
                    child: Column(
                      children: [
                        _buildField(_nombreController, "Nombre Completo", Icons.person_outline),
                        const SizedBox(height: 15),
                        _buildField(_emailController, "Correo Electrónico", Icons.alternate_email),
                        const SizedBox(height: 15),
                        _buildField(_telController, "Teléfono de Contacto", Icons.phone_android_outlined),
                        const SizedBox(height: 15),
                        _buildField(_passController, "Contraseña", Icons.lock_outline, obscure: true),
                        const SizedBox(height: 30),

                        _isLoading
                            ? const CircularProgressIndicator(color: Color(0xFFE53935))
                            : ElevatedButton(
                          onPressed: _handleRegister,
                          style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFE53935),
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 55),
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                          ),
                          child: const Text("CREAR CUENTA", style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Botón Volver
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "¿Ya tienes cuenta? Inicia sesión",
                      style: TextStyle(color: Colors.white54, fontSize: 13),
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

  Widget _buildField(TextEditingController controller, String hint, IconData icon, {bool obscure = false}) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        obscureText: obscure,
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