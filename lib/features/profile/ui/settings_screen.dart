import 'package:flutter/material.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/theme/theme_service.dart';
import 'agreements_screen.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';
import '../../../core/utils/ui_utils.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../../../core/network/version_service.dart';
import '../../../core/utils/ui_tokens.dart'; // v2.14.9
import 'package:image_picker/image_picker.dart';
// import 'dart:io'; // v2.12.0: Removed unused
// import 'dart:typed_data'; // v2.12.0: Removed unused

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final ThemeService _themeService = ThemeService();

  bool _isLoading = true;
  bool _isCheckingUpdate = false; // v2.8.4
  String _appVersion = "...";
  String? _avatarUrl;

  late AnimationController _radarController;

  // Form controllers
  final _nombreController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _cedulaController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _cargarDatos();
  }

  @override
  void dispose() {
    _radarController.dispose();
    _nombreController.dispose();
    _telefonoController.dispose();
    _cedulaController.dispose();
    super.dispose();
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
          _avatarUrl = data['avatar_url'];
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _seleccionarFoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 50,
      maxWidth: 500,
    );

    if (image != null) {
      UiUtils.showSuccess("Subiendo imagen...");
      final bytes = await image.readAsBytes();
      final String fileName =
          "profile_${DateTime.now().millisecondsSinceEpoch}.jpg";

      final url = await _auth.subirFotoPerfil(bytes, fileName);
      if (url != null) {
        setState(() => _avatarUrl = url);
        UiUtils.showSuccess("Foto actualizada");
      } else {
        UiUtils.showError("No se pudo subir la foto");
      }
    }
  }

  // v2.8.7: Novedades de la versión (Spanish)
  void _showChangelog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UiTokens.surface(context),
        shape: UiTokens.dialogShape,
        title: Text("🚀 NOVEDADES v2.15.1",
            style: TextStyle(
                color: UiTokens.textColor(context),
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
                "• Bloqueo de navegación en pantallas de alerta (Seguridad total).",
                style: TextStyle(color: UiTokens.secondaryTextColor(context))),
            const SizedBox(height: 8),
            Text(
                "• Clasificación de incidentes mandatoria (Mejora comunitaria).",
                style: TextStyle(color: UiTokens.secondaryTextColor(context))),
            const SizedBox(height: 8),
            Text(
                "• Visibilidad optimizada para Modo Claro (Perfil y Sistemas).",
                style: TextStyle(color: UiTokens.secondaryTextColor(context))),
            const SizedBox(height: 8),
            Text("• Sistema anti-spam de alertas de fondo (v2.15.1).",
                style: TextStyle(color: UiTokens.secondaryTextColor(context))),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("EXCELENTE",
                style: TextStyle(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }

  Future<void> _buscarActualizacionManual() async {
    setState(() => _isCheckingUpdate = true);
    _radarController.repeat();

    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      await VersionService().checkForUpdates(context, manual: true);
      _radarController.animateTo(0,
          duration: const Duration(milliseconds: 500), curve: Curves.easeOut);
      setState(() => _isCheckingUpdate = false);
    }
  }

  Future<void> _guardarPerfil() async {
    try {
      await _auth.actualizarPerfil(
        nombre: _nombreController.text,
        telefono: _telefonoController.text,
        cedula: _cedulaController.text,
      );
      if (mounted) {
        UiUtils.showSuccess("Perfil actualizado");
        Navigator.pop(context);
      }
    } catch (e) {
      UiUtils.showError("Error al actualizar perfil");
    }
  }

  @override
  Widget build(BuildContext context) {
    final textColor = UiTokens.textColor(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    // --- CABECERA DE PERFIL (v2.12.0) ---
                    _buildProfileHeader(isDark),
                    const SizedBox(height: 30),

                    // --- SECCIÓN PERFIL ---
                    _buildSectionTitle("DATOS PERSONALES", isDark),
                    const SizedBox(height: 15),
                    GlassBox(
                      borderRadius: 20,
                      // v2.8.0: Usa defaults premium
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
                            readOnly: true, // v2.6.4: Solo lectura
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: _guardarPerfil,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blueAccent,
                                foregroundColor: Colors.white,
                                elevation: 0,
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
                    _buildSectionTitle("SISTEMA ARGOS", isDark),
                    const SizedBox(height: 15),
                    _buildPremiumVersionCard(isDark),

                    const SizedBox(height: 15),
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
                        padding: const EdgeInsets.all(18),
                        child: Row(
                          children: [
                            const Icon(Icons.description_outlined,
                                color: Colors.blueAccent, size: 20),
                            const SizedBox(width: 15),
                            Text(
                              "Acuerdos y Compromisos",
                              style: TextStyle(
                                color: UiTokens.textColor(context),
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

  Widget _buildProfileHeader(bool isDark) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent,
                      Colors.blueAccent.withValues(alpha: 0.2)
                    ],
                  ),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: isDark ? Colors.grey[900] : Colors.grey[200],
                  backgroundImage:
                      _avatarUrl != null ? NetworkImage(_avatarUrl!) : null,
                  child: _avatarUrl == null
                      ? Icon(Icons.person,
                          size: 50,
                          color: UiTokens.secondaryTextColor(context)
                              .withValues(alpha: 0.5))
                      : null,
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _seleccionarFoto,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                      color: Colors.blueAccent,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.camera_alt,
                        color: Colors.white, size: 18),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _nombreController.text.isEmpty
                ? "USUARIO ARGOS"
                : _nombreController.text,
            style: TextStyle(
              color: UiTokens.textColor(context),
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          Text(
            "ESTADO: PROTEGIDO",
            style: TextStyle(
                color: UiTokens.emeraldGreen(context),
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumVersionCard(bool isDark) {
    return GlassBox(
      borderRadius: 20,
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              RotationTransition(
                turns: _radarController,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _isCheckingUpdate
                        ? Colors.blueAccent.withValues(alpha: 0.1)
                        : Colors.white.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _isCheckingUpdate ? Icons.radar : Icons.verified_user,
                    color: _isCheckingUpdate
                        ? Colors.blueAccent
                        : Colors.greenAccent,
                  ),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _isCheckingUpdate
                          ? " ESCANEANDO RED..."
                          : "SISTEMA AL DÍA",
                      style: TextStyle(
                        color: UiTokens.textColor(context),
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      "VERSIÓN INSTALADA: $_appVersion",
                      style: TextStyle(
                        color: UiTokens.secondaryTextColor(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (!_isCheckingUpdate)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      onPressed: _showChangelog, // v2.12.0: Restored
                      icon: const Icon(Icons.info_outline,
                          color: Colors.blueAccent, size: 18),
                      tooltip: "Novedades",
                    ),
                    IconButton(
                      onPressed: _buscarActualizacionManual,
                      icon: const Icon(Icons.refresh,
                          color: Colors.blueAccent, size: 20),
                    ),
                  ],
                ),
            ],
          ),
          if (_isCheckingUpdate) ...[
            const SizedBox(height: 15),
            const LinearProgressIndicator(
              backgroundColor: Colors.white12,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.blueAccent),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, bool isDark) {
    return Text(
      title,
      style: TextStyle(
        color: UiTokens.secondaryTextColor(context),
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
    bool readOnly = false, // Nuevo parámetro
  }) {
    final textColor = UiTokens.textColor(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: UiTokens.secondaryTextColor(context), fontSize: 11)),
        const SizedBox(height: 5),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          readOnly: readOnly, // Aplicar readOnly
          style: TextStyle(
            color: readOnly ? textColor.withValues(alpha: 0.5) : textColor,
            fontWeight: FontWeight.bold,
          ),
          decoration: InputDecoration(
            prefixIcon: Icon(icon, color: Colors.blueAccent, size: 20),
            suffixIcon: readOnly
                ? const Icon(Icons.lock_outline,
                    size: 16, color: Colors.blueGrey)
                : null,
            filled: true,
            fillColor: UiTokens.textColor(context)
                .withValues(alpha: 0.05), // v2.15.1 Consistent
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
