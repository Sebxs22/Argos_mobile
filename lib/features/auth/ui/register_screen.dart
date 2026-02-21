import 'dart:ui';
import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';
import '../../../../main.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import '../../../core/utils/validators.dart';

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
  bool _cedulaInvalida = false; // Nuevo: rastrear error de cédula

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

    // Validación de Cédula Real
    if (!Validators.isValidCedula(_cedulaController.text)) {
      setState(() => _cedulaInvalida = true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Cédula o DNI ecuatoriano no válido"),
          backgroundColor: Color(0xFFE53935),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white38 : Colors.black45;

    return ArgosBackground(
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 20),
            child: Column(
              children: [
                // Icono superior
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark
                        ? Colors.white.withOpacity(0.03)
                        : Colors.black.withOpacity(0.02),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/icon.png',
                    width: 50,
                    height: 50,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.shield_outlined,
                      color: Color(0xFFE53935),
                      size: 40,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Text(
                  "REGISTRO",
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 6,
                    color: textColor,
                  ),
                ),
                Text(
                  "IDENTIDAD DE SEGURIDAD",
                  style: TextStyle(
                    fontSize: 8,
                    letterSpacing: 1.5,
                    color: secondaryTextColor,
                  ),
                ),
                const SizedBox(height: 30),

                // Caja de Registro (Liquid Glass)
                GlassBox(
                  borderRadius: 30,
                  opacity: isDark ? 0.05 : 0.03,
                  blur: 20,
                  padding: const EdgeInsets.all(25),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      // Override para asegurar que los diálogos y buscadores se vean bien en negro
                      dialogTheme: DialogThemeData(
                        backgroundColor:
                            isDark ? const Color(0xFF0F172A) : Colors.white,
                      ),
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: const Color(0xFFE53935),
                        brightness: isDark ? Brightness.dark : Brightness.light,
                        surface:
                            isDark ? const Color(0xFF0F172A) : Colors.white,
                        onSurface: isDark ? Colors.white : Colors.black87,
                      ),
                      textTheme: TextTheme(
                        titleMedium: TextStyle(color: textColor),
                        bodyMedium: TextStyle(color: textColor),
                      ),
                    ),
                    child: Column(
                      children: [
                        _buildField(
                          _nombreController,
                          "Nombre Completo",
                          Icons.person_outline,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 15),
                        _buildField(
                          _emailController,
                          "Correo Electrónico",
                          Icons.alternate_email,
                          isDark: isDark,
                        ),
                        const SizedBox(height: 15),

                        // --- SELECTOR DE TELÉFONO ---
                        _buildFieldWrapper(
                          isDark: isDark,
                          child: IntlPhoneField(
                            initialCountryCode: 'EC',
                            dropdownIconPosition: IconPosition.trailing,
                            dropdownTextStyle:
                                TextStyle(color: textColor, fontSize: 13),
                            style: TextStyle(color: textColor, fontSize: 13),
                            cursorColor: const Color(0xFFE53935),
                            decoration: InputDecoration(
                              hintText: 'Número Celular',
                              hintStyle: TextStyle(
                                  color: secondaryTextColor, fontSize: 14),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 15),
                            ),
                            languageCode: "es",
                            onChanged: (phone) {
                              _telefonoCompleto = phone.completeNumber;
                            },
                            pickerDialogStyle: PickerDialogStyle(
                              backgroundColor: isDark
                                  ? const Color(0xFF0F172A)
                                  : Colors.white,
                              countryNameStyle:
                                  TextStyle(color: textColor, fontSize: 14),
                              countryCodeStyle: TextStyle(
                                  color: secondaryTextColor, fontSize: 13),
                              searchFieldCursorColor: const Color(0xFFE53935),
                              searchFieldInputDecoration: InputDecoration(
                                hintText: 'Buscar país...',
                                hintStyle: TextStyle(
                                    color: secondaryTextColor, fontSize: 13),
                                prefixIcon: Icon(Icons.search,
                                    color: secondaryTextColor, size: 20),
                                filled: true,
                                fillColor: isDark
                                    ? Colors.white.withOpacity(0.05)
                                    : Colors.black.withOpacity(0.03),
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
                          isDark: isDark,
                          error: _cedulaInvalida,
                          onChanged: (val) {
                            if (_cedulaInvalida) {
                              setState(() => _cedulaInvalida =
                                  !Validators.isValidCedula(val));
                            }
                          },
                        ),
                        const SizedBox(height: 20),

                        // --- SELECTOR DE PAÍS/CIUDAD ---
                        Text(
                          "UBICACIÓN GEOGRÁFICA",
                          style: TextStyle(
                              color: secondaryTextColor,
                              fontSize: 9,
                              letterSpacing: 1),
                        ),
                        const SizedBox(height: 10),
                        // --- SELECTOR DE UBICACIÓN (Vertical Layout) ---
                        _buildFieldWrapper(
                          isDark: isDark,
                          padding: const EdgeInsets.all(12),
                          child: CSCPickerPlus(
                            showStates: true,
                            showCities: true,
                            flagState: CountryFlag.ENABLE,
                            layout: Layout.vertical,
                            countryStateLanguage:
                                CountryStateLanguage.englishOrNative,
                            dropdownDecoration:
                                const BoxDecoration(color: Colors.transparent),
                            disabledDropdownDecoration:
                                const BoxDecoration(color: Colors.transparent),
                            countrySearchPlaceholder: "Buscar País",
                            stateSearchPlaceholder: "Buscar Estado",
                            citySearchPlaceholder: "Buscar Ciudad",
                            countryDropdownLabel: "País",
                            stateDropdownLabel: "Estado / Provincia",
                            cityDropdownLabel: "Ciudad",
                            selectedItemStyle:
                                TextStyle(color: textColor, fontSize: 13),
                            dropdownHeadingStyle: TextStyle(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold),
                            dropdownItemStyle:
                                TextStyle(color: textColor, fontSize: 13),
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
                          isDark: isDark,
                          obscure: true,
                        ),
                        const SizedBox(height: 20),

                        // T&C Checkbox
                        Theme(
                          data: ThemeData(
                            unselectedWidgetColor: secondaryTextColor,
                          ),
                          child: CheckboxListTile(
                            value: _aceptaTerminos,
                            onChanged: (val) =>
                                setState(() => _aceptaTerminos = val ?? false),
                            title: Text(
                              "Acepto los términos, condiciones y políticas de privacidad.",
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 11,
                              ),
                            ),
                            controlAffinity: ListTileControlAffinity.leading,
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
                                  minimumSize: const Size(double.infinity, 55),
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
                  child: Text(
                    "¿Ya tienes cuenta? Inicia sesión",
                    style: TextStyle(color: secondaryTextColor, fontSize: 13),
                  ),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildField(
    TextEditingController controller,
    String hint,
    IconData icon, {
    bool obscure = false,
    bool isDark = true,
    bool error = false,
    Function(String)? onChanged,
  }) {
    return Focus(
      child: Builder(builder: (context) {
        final bool isFocused = Focus.of(context).hasFocus;
        return _buildFieldWrapper(
          isFocused: isFocused,
          isDark: isDark,
          error: error,
          child: TextField(
            controller: controller,
            obscureText: obscure,
            onChanged: onChanged,
            style: TextStyle(
                color: isDark ? Colors.white : Colors.black87, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                  color: isDark ? Colors.white24 : Colors.black38,
                  fontSize: 13),
              prefixIcon: Icon(icon,
                  color: error
                      ? Colors.orange
                      : (isFocused
                          ? const Color(0xFFE53935)
                          : (isDark ? Colors.white54 : Colors.black45)),
                  size: 20),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        );
      }),
    );
  }

  // Wrapper estandarizado con ClipRRect para evitar esquinas rectangulares
  Widget _buildFieldWrapper({
    required Widget child,
    bool isFocused = false,
    bool isDark = true,
    bool error = false,
    EdgeInsetsGeometry? padding,
  }) {
    Color borderColor = isDark ? Colors.white10 : Colors.black12;
    if (error) {
      borderColor = Colors.orange.withValues(alpha: 0.5);
    } else if (isFocused) {
      borderColor = const Color(0xFFE53935);
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: padding,
      decoration: BoxDecoration(
        color: isFocused
            ? (isDark
                ? Colors.white.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03))
            : (isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.black.withValues(alpha: 0.01)),
        borderRadius: BorderRadius.circular(15), // Mismo radio que Login
        border: Border.all(
          color: borderColor,
          width: isFocused || error ? 1.5 : 1,
        ),
        boxShadow: (isFocused || error)
            ? [
                BoxShadow(
                    color: (error ? Colors.orange : const Color(0xFFE53935))
                        .withValues(alpha: 0.1),
                    blurRadius: 10)
              ]
            : [],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(15),
        child: child,
      ),
    );
  }
}
