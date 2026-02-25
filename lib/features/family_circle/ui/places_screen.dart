import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/network/api_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_background.dart';
import '../../../core/utils/ui_utils.dart';
import '../../../core/utils/ui_tokens.dart'; // v2.14.9

class PlacesScreen extends StatefulWidget {
  const PlacesScreen({super.key});

  @override
  State<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends State<PlacesScreen> {
  final ApiService _apiService = ApiService();
  List<Map<String, dynamic>> _places = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
  }

  Future<void> _loadPlaces() async {
    setState(() => _isLoading = true);
    final places = await _apiService.obtenerMisLugaresSeguros();
    if (mounted) {
      setState(() {
        _places = places;
        _isLoading = false;
      });
    }
  }

  Future<void> _addPlace() async {
    String name = "";
    double radius = 200.0;

    final textColor = UiTokens.textColor(context);

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: UiTokens.surface(context),
        shape: UiTokens.dialogShape,
        title: Text("Nuevo Lugar Seguro", style: TextStyle(color: textColor)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              "Se registrará tu ubicación actual con un radio de protección automático de 200m.",
              style: TextStyle(color: Colors.grey, fontSize: 12),
            ),
            const SizedBox(height: 15),
            TextField(
              onChanged: (v) => name = v,
              autofocus: true,
              style: TextStyle(color: textColor),
              decoration: InputDecoration(
                labelText: "Nombre (Ej: Casa, Oficina)",
                labelStyle: const TextStyle(color: Colors.blueAccent),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
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
              if (name.isEmpty) return;
              Navigator.pop(context);

              UiUtils.showWarning("Analizando ubicación...");
              try {
                Position pos = await Geolocator.getCurrentPosition(
                  locationSettings:
                      const LocationSettings(accuracy: LocationAccuracy.high),
                );

                await _apiService.registrarLugarSeguro(
                    name, pos.latitude, pos.longitude, radius);

                // v2.15.9: Notificar al círculo instantáneamente
                await _apiService.notificarNuevoLugarSeguro(name);

                UiUtils.showSuccess(
                    "Lugar '$name' guardado y Círculo notificado.");
                _loadPlaces();
              } catch (e) {
                UiUtils.showError("No se pudo obtener la ubicación GPS.");
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            child: const Text("Guardar", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = UiTokens.textColor(context);

    return ArgosBackground(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text("Mis Lugares Seguros",
              style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: textColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _places.isEmpty
                ? _buildEmptyState()
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _places.length,
                    itemBuilder: (context, index) {
                      final p = _places[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        child: GlassBox(
                          opacity: UiTokens.glassOpacity(context),
                          border:
                              Border.all(color: UiTokens.glassBorder(context)),
                          child: ListTile(
                            leading: const CircleAvatar(
                              backgroundColor: Colors.blueAccent,
                              child: Icon(Icons.home, color: Colors.white),
                            ),
                            title: Text(p['nombre'] ?? "Lugar",
                                style: TextStyle(
                                    color: textColor,
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text("Radio: ${p['radio']}m",
                                style: TextStyle(
                                    color:
                                        UiTokens.secondaryTextColor(context))),
                            trailing: IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    backgroundColor: UiTokens.surface(context),
                                    shape: UiTokens.dialogShape,
                                    title: Text("Eliminar",
                                        style: TextStyle(color: textColor)),
                                    content: Text(
                                        "¿Estás seguro de eliminar este lugar?",
                                        style: TextStyle(
                                            color: UiTokens.secondaryTextColor(
                                                context))),
                                    actions: [
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, false),
                                          child: const Text("No")),
                                      TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context, true),
                                          child: const Text("Sí")),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  await _apiService
                                      .eliminarLugarSeguro(p['id']);
                                  _loadPlaces();
                                }
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addPlace,
          backgroundColor: Colors.blueAccent,
          icon: const Icon(Icons.add_location_alt, color: Colors.white),
          label:
              const Text("Agregar Aquí", style: TextStyle(color: Colors.white)),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.map_outlined,
              size: 80, color: UiTokens.glacialBlue.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text("Aún no tienes lugares registrados",
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: UiTokens.secondaryTextColor(context))),
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              "Registra tu casa o trabajo para avisar a tu círculo automáticamente cuando llegues o salgas.",
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: UiTokens.secondaryTextColor(context), fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
