import 'package:flutter/material.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/network/auth_service.dart';

class FamilyScreen extends StatefulWidget {
  const FamilyScreen({super.key});

  @override
  State<FamilyScreen> createState() => _FamilyScreenState();
}

class _FamilyScreenState extends State<FamilyScreen> {
  final _auth = AuthService();
  final _codeController = TextEditingController();
  Map<String, dynamic>? _miPerfil;
  List<dynamic> _familiares = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() async {
    final perfil = await _auth.obtenerMiPerfil();
    final familia = await _auth.obtenerMisFamiliares();
    setState(() {
      _miPerfil = perfil;
      _familiares = familia;
      _loading = false;
    });
  }

  void _agregarFamiliar() async {
    String codigo = _codeController.text.trim();
    final familiar = await _auth.buscarPorCodigo(codigo);

    if (familiar != null) {
      await _auth.vincularFamiliar(familiar['id']);
      _codeController.clear();
      _cargarDatos(); // Recargar lista
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${familiar['nombre_completo']} añadido al círculo.")));
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Código no válido"), backgroundColor: Colors.redAccent));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(backgroundColor: Colors.transparent, title: const Text("CÍRCULO DE CONFIANZA", style: TextStyle(fontSize: 14, letterSpacing: 2))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // TU CÓDIGO
            GlassBox(
              borderRadius: 20, opacity: 0.1,
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  const Text("TU CÓDIGO ARGOS", style: TextStyle(color: Colors.white54, fontSize: 10)),
                  const SizedBox(height: 10),
                  Text(_miPerfil?['codigo_familia'] ?? "---", style: const TextStyle(color: Colors.redAccent, fontSize: 32, fontWeight: FontWeight.bold, letterSpacing: 5)),
                  const Text("Comparte este código con tu familia", style: TextStyle(color: Colors.white38, fontSize: 10)),
                ],
              ),
            ),

            const SizedBox(height: 30),

            // AGREGAR FAMILIAR
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _codeController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Código (Ej: ARG-1234)",
                      hintStyle: const TextStyle(color: Colors.white24),
                      filled: true, fillColor: Colors.white.withOpacity(0.05),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                IconButton.filled(
                  onPressed: _agregarFamiliar,
                  icon: const Icon(Icons.add),
                  style: IconButton.styleFrom(backgroundColor: Colors.redAccent),
                )
              ],
            ),

            const SizedBox(height: 30),

            // LISTA DE FAMILIARES
            const Align(alignment: Alignment.centerLeft, child: Text(" PERSONAS QUE TE CUIDAN", style: TextStyle(color: Colors.white54, fontSize: 10))),
            const SizedBox(height: 10),
            ..._familiares.map((f) {
              final p = f['perfiles'];
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                child: GlassBox(
                  borderRadius: 15, opacity: 0.05,
                  padding: const EdgeInsets.all(15),
                  child: Row(
                    children: [
                      const CircleAvatar(backgroundColor: Colors.redAccent, child: Icon(Icons.person, color: Colors.white)),
                      const SizedBox(width: 15),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(p['nombre_completo'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text(p['telefono'] ?? "Sin teléfono", style: const TextStyle(color: Colors.white38, fontSize: 12)),
                        ],
                      ),
                      const Spacer(),
                      const Icon(Icons.verified_user, color: Colors.greenAccent, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}