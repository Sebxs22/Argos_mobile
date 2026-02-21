import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/theme/theme_service.dart';
import 'agreements_screen.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';
import '../../../core/utils/ui_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final AuthService _auth = AuthService();
  final ThemeService _themeService = ThemeService();

  bool _isLoading = true;
  String _appVersion = "...";

  // Form controllers
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _cedulaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);
    final data = await _auth.obtenerMiPerfil();
    final info = await PackageInfo.fromPlatform();

    if (mounted) {
      setState(() {
        _appVersion = "${info.version}+${info.buildNumber}";
        if (data != null) {
          _nombreController.text = data['nombre_completo'] ?? "";
          _telefonoController.text = data['telefono'] ?? "";
          _cedulaController.text = data['cedula'] ?? "";
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _guardarPerfil() async {
    try {
      UiUtils.showWarning("Actualizando perfil...");
      await _auth.actualizarPerfil(
        nombre: _nombreController.text,
        telefono: _telefonoController.text,
        cedula: _cedulaController.text,
      );
      UiUtils.showSuccess("Perfil actualizado correctamente");
    } catch (e) {
      UiUtils.showError("Error al actualizar perfil");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return ArgosBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            "Configuración y Perfil",
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          centerTitle: true,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // --- SECCIÓN PERFIL ---
                    _buildSectionTitle("MI PERFIL", isDark),
                    const SizedBox(height: 15),
                    GlassBox(
                      borderRadius: 20,
                      opacity: isDark ? 0.05 : 0.03,
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          _buildInputField(
                            label: "Nombre Completo",
                            controller: _nombreController,
                            icon: Icons.person_outline,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 15),
                          _buildInputField(
                            label: "Teléfono",
                            controller: _telefonoController,
                            icon: Icons.phone_outlined,
                            isDark: isDark,
                            keyboardType: TextInputType.phone,
                          ),
                          const SizedBox(height: 15),
                          _buildInputField(
                            label: "Cédula / DNI",
                            controller: _cedulaController,
                            icon: Icons.badge_outlined,
                            isDark: isDark,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _guardarPerfil,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                              child: const Text("Guardar Cambios"),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 30),

                    // --- SECCIÓN TEMA ---
                    _buildSectionTitle("APARIENCIA", isDark),
                    const SizedBox(height: 15),
                    ValueListenableBuilder<ThemeMode>(
                        valueListenable: _themeService.themeNotifier,
                        builder: (context, currentMode, _) {
                          return GlassBox(
                            borderRadius: 20,
                            opacity: isDark ? 0.05 : 0.03,
                            padding: const EdgeInsets.all(10),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _buildThemeOption(
                                  mode: ThemeMode.light,
                                  currentMode: currentMode,
                                  icon: Icons.light_mode,
                                  label: "Claro",
                                  isDark: isDark,
                                ),
                                _buildThemeOption(
                                  mode: ThemeMode.dark,
                                  currentMode: currentMode,
                                  icon: Icons.dark_mode,
                                  label: "Oscuro",
                                  isDark: isDark,
                                ),
                                _buildThemeOption(
                                  mode: ThemeMode.system,
                                  currentMode: currentMode,
                                  icon: Icons.settings_brightness,
                                  label: "Sistema",
                                  isDark: isDark,
                                ),
                              ],
                            ),
                          );
                        }),

                    const SizedBox(height: 30),

                    // --- SECCIÓN INFO ---
                    _buildSectionTitle("INFORMACIÓN", isDark),
                    const SizedBox(height: 15),
                    GlassBox(
                      borderRadius: 20,
                      opacity: isDark ? 0.05 : 0.03,
                      padding: const EdgeInsets.all(20),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text("Versión instalada",
                              style: TextStyle(
                                  color: isDark
                                      ? Colors.white70
                                      : Colors.black54)),
                          Text(
                            _appVersion,
                            style: const TextStyle(
                                color: Colors.blueAccent,
                                fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => const AgreementsScreen()),
                        );
                      },
                      child: GlassBox(
                        borderRadius: 20,
                        opacity: isDark ? 0.05 : 0.03,
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined,
                                color: Colors.blueAccent, size: 20),
                            const SizedBox(width: 15),
                            Text(
                              "Acuerdos y Compromisos",
                              style: TextStyle(
                                color: isDark ? Colors.white70 : Colors.black87,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Spacer(),
                            const Icon(Icons.arrow_forward_ios,
                                color: Colors.blueAccent, size: 14),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: isDark ? Colors.white38 : Colors.black38,
        fontSize: 12,
        fontWeight: FontWeight.bold,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildInputField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    required bool isDark,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final textColor = isDark ? Colors.white : Colors.black87;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: isDark ? Colors.white60 : Colors.black54, fontSize: 11)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
            filled: true,
            fillColor:
                isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.05),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide.none),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildThemeOption({
    required ThemeMode mode,
    required ThemeMode currentMode,
    required IconData icon,
    required String label,
    required bool isDark,
  }) {
    final isSelected = mode == currentMode;
    return GestureDetector(
      onTap: () => _themeService.setTheme(mode),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.blueAccent.withValues(alpha: 0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
              color: isSelected ? Colors.blueAccent : Colors.transparent),
        ),
        child: Column(
          children: [
            Icon(icon,
                color: isSelected
                    ? Colors.blueAccent
                    : (isDark ? Colors.white30 : Colors.black26)),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? Colors.blueAccent
                    : (isDark ? Colors.white30 : Colors.black26),
                fontSize: 10,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
