import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';
import '../../../../main.dart';
import 'package:csc_picker_plus/csc_picker_plus.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:intl_phone_field/country_picker_dialog.dart';
import '../../../core/utils/validators.dart';
import '../../../core/utils/ui_utils.dart'; // Import UiUtils
import '../../../core/ui/argos_notifications.dart'; // v2.14.1
import '../../../core/utils/ui_tokens.dart'; // v2.15.1
import '../../profile/ui/agreements_screen.dart';

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
  String _telefonoNumero = "";
  int _maxPhoneLength = 9; // Por defecto Ecuador
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
      UiUtils.showWarning("Por favor, llena todos los campos obligatorios");
      return;
    }

    if (!Validators.isValidCedula(_cedulaController.text)) {
      setState(() => _cedulaInvalida = true);
      UiUtils.showError("Cédula o DNI ecuatoriano no válido");
      return;
    }

    if (!_aceptaTerminos) {
      UiUtils.showWarning("Debes aceptar los términos y condiciones");
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
        ArgosNotifications.show(
          context,
          "¡Bienvenido a la Red ARGOS!",
          type: ArgosNotificationType.success,
        );
        // Al registrarse, lo mandamos directo al Navigator principal
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
                        ? Colors.white.withValues(alpha: 0.03)
                        : Colors.black.withValues(alpha: 0.02),
                    border: Border.all(
                      color: isDark ? Colors.white10 : Colors.black12,
                    ),
                  ),
                  child: const Icon(
                    Icons.shield_outlined,
                    color: Color(0xFFE53935),
                    size: 40,
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
                  opacity: isDark ? 0.08 : 0.05,
                  blur: 25,
                  padding: const EdgeInsets.all(25),
                  child: Theme(
                    data: Theme.of(context).copyWith(
                      // Override para asegurar que los diálogos y buscadores se vean bien en negro
                      dialogTheme: DialogThemeData(
                        backgroundColor: UiTokens.surface(context),
                      ),
                      colorScheme: ColorScheme.fromSeed(
                        seedColor: UiTokens.argosRed,
                        brightness: isDark ? Brightness.dark : Brightness.light,
                        surface: UiTokens.surface(context),
                        onSurface: UiTokens.textColor(context),
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
                            showCursor: true,
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
                              counterText: "", // Ocultar el contador interno
                              contentPadding: const EdgeInsets.symmetric(
                                  vertical: 18, horizontal: 15),
                            ),
                            languageCode: "es",
                            onChanged: (phone) {
                              setState(() {
                                _telefonoNumero = phone.number;
                                _telefonoCompleto = phone.completeNumber;
                              });
                            },
                            onCountryChanged: (country) {
                              setState(() {
                                _maxPhoneLength = country.maxLength;
                              });
                            },
                            pickerDialogStyle: PickerDialogStyle(
                              backgroundColor: UiTokens.surface(context),
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
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.03),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                              ),
                            ),
                          ),
                        ),
                        // --- CONTADOR DE TELÉFONO EXTERNO ---
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              "${_telefonoNumero.length}/$_maxPhoneLength",
                              style: TextStyle(
                                color: secondaryTextColor,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
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
                        // --- AVISO DE CÉDULA EXTERNO ---
                        if (_cedulaInvalida)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0, left: 8.0),
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                "✕ Cédula o DNI ecuatoriano no válido",
                                style: TextStyle(
                                  color: Colors.orange.withValues(alpha: 0.9),
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ),
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
                        // Wrap in a separate widget or use a key to minimize rebuilds if possible
                        _buildFieldWrapper(
                          isDark: isDark,
                          padding: const EdgeInsets.all(12),
                          child: CSCPickerPlus(
                            key: const ValueKey(
                                'csc_picker'), // Ensure it doesn't rebuild entire state needlessly
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
                              if (_paisSeleccionado != value) {
                                setState(() => _paisSeleccionado = value);
                              }
                            },
                            onStateChanged: (value) {
                              String cleaned = _cleanLocationName(value);
                              if (_estadoSeleccionado != cleaned) {
                                setState(() => _estadoSeleccionado = cleaned);
                              }
                            },
                            onCityChanged: (value) {
                              String cleaned = _cleanLocationName(value);
                              if (_ciudadSeleccionada != cleaned) {
                                setState(() => _ciudadSeleccionada = cleaned);
                              }
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
                            title: GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          const AgreementsScreen()),
                                );
                              },
                              child: RichText(
                                text: TextSpan(
                                  style: TextStyle(
                                    color: secondaryTextColor,
                                    fontSize: 11,
                                    // fontFamily: 'Outfit', // v2.16.0: Limpieza
                                  ),
                                  children: [
                                    const TextSpan(text: "Acepto los "),
                                    TextSpan(
                                      text:
                                          "términos, condiciones y acuerdos de compromiso",
                                      style: TextStyle(
                                        color: isDark
                                            ? Colors.white
                                            : UiTokens.argosRed,
                                        fontWeight: FontWeight.bold,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                    const TextSpan(text: " de la red Argos."),
                                  ],
                                ),
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
                            ? CircularProgressIndicator(
                                color: UiTokens.argosRed,
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
                          ? UiTokens.argosRed
                          : UiTokens.secondaryTextColor(context)),
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
      borderColor = UiTokens.argosRed;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: padding,
      decoration: BoxDecoration(
        color: isFocused
            ? UiTokens.surface(context).withValues(alpha: isDark ? 0.08 : 0.8)
            : UiTokens.surface(context).withValues(alpha: isDark ? 0.05 : 0.5),
        borderRadius: BorderRadius.circular(15), // Mismo radio que Login
        border: Border.all(
          color: borderColor,
          width: isFocused || error ? 1.5 : 1,
        ),
        boxShadow: (isFocused || error)
            ? [
                BoxShadow(
                    color: (error ? Colors.orange : UiTokens.argosRed)
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
