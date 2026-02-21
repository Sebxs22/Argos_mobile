import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../../main.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';

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
  final _cedulaController = TextEditingController();

  String _telefonoCompleto = "";
  String _paisSeleccionado = "";
  String _estadoSeleccionado = "";
  String _ciudadSeleccionada = "";

  // Función para limpiar nombres (ej: "Chimborazo Province" -> "Chimborazo")
  String _cleanLocationName(String? name) {
    if (name == null || name.isEmpty) return "";
    return name
        .replaceAll(
            RegExp(
                r' (Province|State|Region|Department|District|Prefecture|Area|Zone|Territory)',
                caseSensitive: false),
            "")
        .trim();
  }

  bool _isLoading = false;
  bool _aceptaTerminos = false;

  void _handleRegister() async {
    // Validación básica
    if (_nombreController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passController.text.isEmpty ||
        _cedulaController.text.isEmpty ||
        _telefonoCompleto.isEmpty ||
        _paisSeleccionado.isEmpty ||
        _estadoSeleccionado.isEmpty ||
        _ciudadSeleccionada.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Por favor, llena todos los campos obligatorios"),
        ),
      );
      return;
    }

    if (!_aceptaTerminos) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Debes aceptar los términos y condiciones"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final error = await _auth.registrarUsuario(
      email: _emailController.text.trim(),
      password: _passController.text.trim(),
      nombre: _nombreController.text.trim(),
      telefono: _telefonoCompleto,
      cedula: _cedulaController.text.trim(),
      pais: _paisSeleccionado,
      estado: _estadoSeleccionado,
      ciudad: _ciudadSeleccionada,
      aceptaTerminos: _aceptaTerminos,
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
          // --- CAPA 1: FONDO AURORA (Igual al LoginScreen) ---
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFE53935).withValues(alpha: 0.15),
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
                color: const Color(0xFF2962FF).withValues(alpha: 0.1),
              ),
            ),
          ),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),

          // --- CAPA 2: CONTENIDO ---
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding:
                    const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
                child: Column(
                  children: [
                    // Icono superior
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.03),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: const Icon(
                        Icons.shield_outlined,
                        color: Color(0xFFE53935),
                        size: 40,
                      ),
                    ),
                    const SizedBox(height: 15),
                    const Text(
                      "REGISTRO",
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 6,
                        color: Colors.white,
                      ),
                    ),
                    const Text(
                      "IDENTIDAD DE SEGURIDAD",
                      style: TextStyle(
                        fontSize: 8,
                        letterSpacing: 1.5,
                        color: Colors.white38,
                      ),
                    ),
                    const SizedBox(height: 30),

                    // Caja de Registro (Liquid Glass)
                    GlassBox(
                      borderRadius: 30,
                      opacity: 0.05,
                      blur: 20,
                      padding: const EdgeInsets.all(25),
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          // Override para asegurar que los diálogos y buscadores se vean bien en negro
                          dialogTheme: const DialogThemeData(
                              backgroundColor: Color(0xFF0F172A)),
                          colorScheme: ColorScheme.fromSeed(
                            seedColor: const Color(0xFFE53935),
                            brightness: Brightness.dark,
                            surface: const Color(0xFF0F172A),
                            onSurface: Colors.white,
                          ),
                          textTheme: const TextTheme(
                            titleMedium: TextStyle(color: Colors.white),
                            bodyMedium: TextStyle(color: Colors.white),
                          ),
                          inputDecorationTheme: InputDecorationTheme(
                            hintStyle: const TextStyle(color: Colors.white24),
                            labelStyle: const TextStyle(color: Colors.white70),
                            fillColor: Colors.white.withValues(alpha: 0.05),
                            filled: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(15),
                              borderSide: BorderSide(color: Colors.white10),
                            ),
                          ),
                        ),
                        child: Column(
                          children: [
                            _buildField(
                              _nombreController,
                              "Nombre Completo",
                              Icons.person_outline,
                            ),
                            const SizedBox(height: 15),
                            _buildField(
                              _emailController,
                              "Correo Electrónico",
                              Icons.alternate_email,
                            ),
                            const SizedBox(height: 15),

                            // --- SELECTOR DE TELÉFONO ---
                            _buildFieldWrapper(
                              child: IntlPhoneField(
                                initialCountryCode: 'EC',
                                dropdownIconPosition: IconPosition.trailing,
                                dropdownTextStyle: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                style: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                cursorColor: const Color(0xFFE53935),
                                decoration: const InputDecoration(
                                  hintText: 'Número Celular',
                                  hintStyle: TextStyle(
                                      color: Colors.white24, fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(
                                      vertical: 18, horizontal: 15),
                                ),
                                languageCode: "es",
                                onChanged: (phone) {
                                  _telefonoCompleto = phone.completeNumber;
                                },
                                pickerDialogStyle: PickerDialogStyle(
                                  backgroundColor: const Color(0xFF0F172A),
                                  countryNameStyle: const TextStyle(
                                      color: Colors.white, fontSize: 14),
                                  countryCodeStyle: const TextStyle(
                                      color: Colors.white70, fontSize: 13),
                                  searchFieldCursorColor:
                                      const Color(0xFFE53935),
                                  searchFieldInputDecoration: InputDecoration(
                                    hintText: 'Buscar país...',
                                    hintStyle: const TextStyle(
                                        color: Colors.white24, fontSize: 13),
                                    prefixIcon: const Icon(Icons.search,
                                        color: Colors.white38, size: 20),
                                    filled: true,
                                    fillColor:
                                        Colors.white.withValues(alpha: 0.05),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),

                            _buildField(
                              _cedulaController,
                              "Cédula / DNI / ID",
                              Icons.badge_outlined,
                            ),
                            const SizedBox(height: 20),

                            // --- SELECTOR DE PAÍS/CIUDAD ---
                            const Text(
                              "UBICACIÓN GEOGRÁFICA",
                              style: TextStyle(
                                  color: Colors.white38,
                                  fontSize: 9,
                                  letterSpacing: 1),
                            ),
                            const SizedBox(height: 10),
                            // --- SELECTOR DE PAÍS/CIUDAD ---
                            _buildFieldWrapper(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              child: CSCPickerPlus(
                                showStates: true,
                                showCities: true,
                                flagState: CountryFlag.ENABLE,
                                countryStateLanguage:
                                    CountryStateLanguage.englishOrNative,
                                dropdownDecoration: const BoxDecoration(
                                    color: Colors.transparent),
                                disabledDropdownDecoration: const BoxDecoration(
                                    color: Colors.transparent),
                                countrySearchPlaceholder: "Buscar País",
                                stateSearchPlaceholder: "Buscar Estado",
                                citySearchPlaceholder: "Buscar Ciudad",
                                countryDropdownLabel: "País",
                                stateDropdownLabel: "Estado / Provincia",
                                cityDropdownLabel: "Ciudad",
                                selectedItemStyle: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                dropdownHeadingStyle: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold),
                                dropdownItemStyle: const TextStyle(
                                    color: Colors.white, fontSize: 13),
                                dropdownDialogRadius: 20.0,
                                searchBarRadius: 10.0,
                                onCountryChanged: (value) {
                                  setState(() => _paisSeleccionado = value);
                                },
                                onStateChanged: (value) {
                                  setState(() => _estadoSeleccionado =
                                      _cleanLocationName(value));
                                },
                                onCityChanged: (value) {
                                  setState(() => _ciudadSeleccionada =
                                      _cleanLocationName(value));
                                },
                              ),
                            ),
                            const SizedBox(height: 20),

                            _buildField(
                              _passController,
                              "Contraseña Segura",
                              Icons.lock_outline,
                              obscure: true,
                            ),
                            const SizedBox(height: 20),

                            // T&C Checkbox
                            Theme(
                              data: ThemeData(
                                unselectedWidgetColor: Colors.white24,
                              ),
                              child: CheckboxListTile(
                                value: _aceptaTerminos,
                                onChanged: (val) => setState(
                                    () => _aceptaTerminos = val ?? false),
                                title: const Text(
                                  "Acepto los términos, condiciones y políticas de privacidad.",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 11,
                                  ),
                                ),
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                contentPadding: EdgeInsets.zero,
                                activeColor: const Color(0xFFE53935),
                                checkColor: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 25),

                            _isLoading
                                ? const CircularProgressIndicator(
                                    color: Color(0xFFE53935),
                                  )
                                : ElevatedButton(
                                    onPressed: _handleRegister,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFFE53935),
                                      foregroundColor: Colors.white,
                                      minimumSize:
                                          const Size(double.infinity, 55),
                                      elevation: 0,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(15),
                                      ),
                                    ),
                                    child: const Text(
                                      "UNIRSE A LA RED",
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.2,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 20),

                    // Botón Volver
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        "¿Ya tienes cuenta? Inicia sesión",
                        style: TextStyle(color: Colors.white54, fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 30),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
  }) {
    return Focus(
      child: Builder(builder: (context) {
        final bool isFocused = Focus.of(context).hasFocus;
        return _buildFieldWrapper(
          isFocused: isFocused,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            style: const TextStyle(color: Colors.white, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
              prefixIcon: Icon(icon,
                  color: isFocused ? const Color(0xFFE53935) : Colors.white54,
                  size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        );
      }),
    );
  }

  // Wrapper estandarizado para campos de entrada para mantener consistencia
  Widget _buildFieldWrapper({
    required Widget child,
    bool isFocused = false,
    EdgeInsetsGeometry? padding,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: padding,
      decoration: BoxDecoration(
        color: isFocused
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isFocused ? const Color(0xFFE53935) : Colors.white10,
          width: isFocused ? 1.5 : 1,
        ),
        boxShadow: isFocused
            ? [
                BoxShadow(
                    color: const Color(0xFFE53935).withValues(alpha: 0.1),
                    blurRadius: 10)
              ]
            : [],
      ),
      child: child,
    );
  }
}
