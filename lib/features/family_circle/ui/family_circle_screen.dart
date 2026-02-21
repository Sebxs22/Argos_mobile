import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/network/auth_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/utils/ui_utils.dart';

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
    final perfil = await _authService.obtenerMiPerfil();
    final guardianes = await _authService.obtenerMisGuardianes();
    final protegidos = await _authService.obtenerAQuienesProtejo();

    if (mounted) {
      setState(() {
        _miPerfil = perfil;
        _misGuardianes = guardianes;
        _misProtegidos = protegidos;
        _isLoading = false;
      });
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

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E293B),
        title: const Text(
          "Vincular Guardián",
          style: TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Ingresa el código de familiar de la persona que quieres que reciba tus alertas.",
              style: TextStyle(color: Colors.white70, fontSize: 13),
            ),
            const SizedBox(height: 15),
            TextField(
              onChanged: (v) => codigoInput = v.toUpperCase(),
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                hintText: "EJ: ARG-1234",
                hintStyle: const TextStyle(color: Colors.white30),
                filled: true,
                fillColor: Colors.black26,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          "Círculo de Confianza",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.blueAccent,
          labelColor: Colors.blueAccent,
          unselectedLabelColor: Colors.white54,
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
                    opacity: 0.05,
                    borderRadius: 20,
                    padding: const EdgeInsets.all(20),
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
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(width: 10),
                              const Icon(
                                Icons.copy,
                                color: Colors.white30,
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
                      ],
                    ),
                  ),
                ),

                // --- LISTAS ---
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [_buildGuardiansList(), _buildProtegesList()],
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _agregarGuardian,
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.person_add, color: Colors.white),
        label: const Text("Invitar", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildGuardiansList() {
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
        return _buildUserCard(user, isGuardian: true);
      },
    );
  }

  Widget _buildProtegesList() {
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
        return _buildUserCard(user, isGuardian: false);
      },
    );
  }

  Widget _buildUserCard(Map<String, dynamic> user, {required bool isGuardian}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
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
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  user['telefono'] ?? "Sin teléfono",
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
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
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.group_off, size: 50, color: Colors.white12),
            const SizedBox(height: 15),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white30, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
