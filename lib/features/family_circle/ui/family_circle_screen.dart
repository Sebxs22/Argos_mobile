import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_service.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart'; // Import v2.8.0
import '../../../core/utils/ui_utils.dart';
import 'circle_map_screen.dart';

class FamilyCircleScreen extends StatefulWidget {
  const FamilyCircleScreen({super.key});

  @override
  State<FamilyCircleScreen> createState() => _FamilyCircleScreenState();
}

class _FamilyCircleScreenState extends State<FamilyCircleScreen>
    with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();

  Map<String, dynamic>? _miPerfil;
  List<Map<String, dynamic>> _misGuardianes = [];
  List<Map<String, dynamic>> _misProtegidos = [];
  bool _isLoading = true;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() => _isLoading = true);

    try {
      // 1. CARGA EN PARALELO (v2.5.2: Carga inmediata sin esperar GPS)
      final results = await Future.wait([
        _authService.obtenerMiPerfil(),
        _authService.obtenerMisGuardianes(),
        _authService.obtenerAQuienesProtejo(),
      ]);

      // 2. REPORTE EN SEGUNDO PLANO (v2.5.2: No bloquea la UI)
      Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      ).then((pos) {
        ApiService().actualizarUbicacion(pos.latitude, pos.longitude);
      }).catchError((e) {
        debugPrint("Error GPS fondo: $e");
        return null;
      });

      if (mounted) {
        setState(() {
          _miPerfil = results[0] as Map<String, dynamic>?;
          _misGuardianes = results[1] as List<Map<String, dynamic>>;
          _misProtegidos = results[2] as List<Map<String, dynamic>>;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error cargando círculo: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _compartirCodigo() async {
    if (_miPerfil == null) return;
    final codigo = _miPerfil!['codigo_familia'] ?? 'SIN-CODIGO';
    await SharePlus.instance.share(
      ShareParams(
        text:
            '🔒 Únete a mi círculo de seguridad en Argos.\n\nMi código es: *$codigo*\n\nDescarga la app y vincúlame para protegernos mutuamente.',
      ),
    );
  }

  void _copiarCodigo() {
    if (_miPerfil == null) return;
    final codigo = _miPerfil!['codigo_familia'] ?? 'SIN-CODIGO';
    Clipboard.setData(ClipboardData(text: codigo));
    UiUtils.showSuccess('Código copiado al portapapeles');
  }

  Future<void> _agregarGuardian() async {
    String codigoInput = "";

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Vincular Guardián",
          style: TextStyle(color: textColor),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              "Ingresa el código de familiar de la persona que quieres que reciba tus alertas.",
              style: TextStyle(color: secondaryTextColor, fontSize: 13),
            ),
            const SizedBox(height: 15),
            TextField(
              onChanged: (v) => codigoInput = v.toUpperCase(),
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "EJ: ARG-1234",
                hintStyle:
                    TextStyle(color: isDark ? Colors.white30 : Colors.black26),
                filled: true,
                fillColor: isDark
                    ? Colors.black26
                    : Colors.black.withValues(alpha: 0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (codigoInput.isEmpty) return;
              Navigator.pop(context);

              // 1. Buscar usuario
              UiUtils.showWarning("Buscando usuario...");
              final usuario = await _authService.buscarPorCodigo(codigoInput);

              if (usuario != null) {
                // 2. Vincular
                try {
                  await _authService.vincularFamiliar(
                    usuario['usuario_id'] ?? usuario['id'],
                  ); // Adjust based on column name
                  UiUtils.showSuccess(
                    "¡Vinculado con ${usuario['nombre_completo']}!",
                  );
                  _cargarDatos();
                } catch (e) {
                  UiUtils.showError("Error al vincular. ¿Ya está en tu lista?");
                }
              } else {
                UiUtils.showError("Código no encontrado.");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text(
              "Vincular",
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;

    return ArgosBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Círculo de Confianza",
          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: secondaryTextColor,
          tabs: const [
            Tab(text: "MIS GUARDIANES"),
            Tab(text: "A QUIENES PROTEJO"),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // --- MI CODIGO ---
                Container(
                  margin: const EdgeInsets.all(20),
                  child: GlassBox(
                    borderRadius: 20,
                    child: Column(
                      children: [
                        const Text(
                          "TU CÓDIGO DE FAMILIA",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        GestureDetector(
                          onTap: _copiarCodigo,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _miPerfil?['codigo_familia'] ?? "...",
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Icon(
                                Icons.copy,
                                color: isDark ? Colors.white30 : Colors.black26,
                                size: 18,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 15),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _compartirCodigo,
                            icon: const Icon(Icons.share, size: 16),
                            label: const Text("Compartir Código"),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2563EB),
                              foregroundColor: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        if (_misProtegidos.isNotEmpty ||
                            _misGuardianes.isNotEmpty)
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                // v2.5.3: Deduplicación proactiva (Evita dobles en mapa)
                                final Map<String, Map<String, dynamic>> dedup =
                                    {};

                                for (var m in _misGuardianes) {
                                  final id = (m['id'] ??
                                      m['usuario_id'] ??
                                      m['guardian_id']) as String;
                                  dedup[id] = m;
                                }
                                for (var m in _misProtegidos) {
                                  final id = (m['id'] ??
                                      m['usuario_id'] ??
                                      m['guardian_id']) as String;
                                  dedup[id] = {
                                    ...(dedup[id] ?? {}),
                                    ...m,
                                  };
                                }

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => CircleMapScreen(
                                      initialMembers: dedup.values.toList(),
                                    ),
                                  ),
                                );
                              },
                              icon: const Icon(Icons.map_rounded, size: 16),
                              label: const Text("Ver Mapa en Tiempo Real"),
                              style: OutlinedButton.styleFrom(
                                side: BorderSide(
                                    color: Colors.blueAccent
                                        .withValues(alpha: 0.5)),
                                foregroundColor: Colors.blueAccent,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // --- LISTAS ---
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildGuardiansList(isDark),
                      _buildProtegesList(isDark)
                    ],
                  ),
                ),
              ],
            ),
      ),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 100.0), // v2.8.0 avoid nav bar
        child: FloatingActionButton.extended(
          onPressed: _agregarGuardian,
          backgroundColor: Colors.blueAccent,
          icon: const Icon(Icons.person_add, color: Colors.white),
          label: const Text("AGREGAR AL CÍRCULO",
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
      ),
    ),
  );
}

  Widget _buildGuardiansList(bool isDark) {
    if (_misGuardianes.isEmpty) {
      return _buildEmptyState(
        "No tienes guardianes.",
        "Agrega familiares para que reciban tus alertas de emergencia.",
      );
    }
    return ListView.builder(
      itemCount: _misGuardianes.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        final user = _misGuardianes[index];
        return _buildUserCard(user, isGuardian: true, isDark: isDark);
      },
    );
  }

  Widget _buildProtegesList(bool isDark) {
    if (_misProtegidos.isEmpty) {
      return _buildEmptyState(
        "No proteges a nadie.",
        "Cuando alguien te agregue como guardián, aparecerá aquí.",
      );
    }
    return ListView.builder(
      itemCount: _misProtegidos.length,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemBuilder: (context, index) {
        final user = _misProtegidos[index];
        return _buildUserCard(user, isGuardian: false, isDark: isDark);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user,
      {required bool isGuardian, required bool isDark}) {
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white54 : Colors.black45;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isDark ? Colors.white10 : Colors.black12),
        boxShadow: !isDark
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                )
              ]
            : [],
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: isGuardian
                ? Colors.green.withValues(alpha: 0.2)
                : Colors.amber.withValues(alpha: 0.2),
            child: Icon(
              isGuardian ? Icons.shield : Icons.health_and_safety,
              color: isGuardian ? Colors.greenAccent : Colors.amber,
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user['nombre_completo'] ?? "Usuario",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['telefono'] ?? "Sin teléfono",
                  style: TextStyle(color: secondaryTextColor, fontSize: 12),
                ),
              ],
            ),
          ),
          if (isGuardian)
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: () {
                //
              },
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final secondaryTextColor = isDark ? Colors.white30 : Colors.black38;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.group_off,
                size: 50, color: isDark ? Colors.white12 : Colors.black12),
            const SizedBox(height: 15),
            Text(
              title,
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(color: secondaryTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
