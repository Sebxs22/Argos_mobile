import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_service.dart';
import '../../../core/ui/glass_box.dart';

class CircleMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialMembers;
  const CircleMapScreen({super.key, required this.initialMembers});

  @override
  State<CircleMapScreen> createState() => _CircleMapScreenState();
}

class _CircleMapScreenState extends State<CircleMapScreen> {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  late Stream<List<Map<String, dynamic>>> _membersStream;
  List<Map<String, dynamic>> _currentMembers = [];
  bool _hasCentered = false;

  @override
  void initState() {
    super.initState();
    _currentMembers = widget.initialMembers;

    // Obtener IDs para el stream
    final List<String> ids = widget.initialMembers
        .map((m) => m['id'] as String? ?? "")
        .where((id) => id.isNotEmpty)
        .toList();

    _membersStream = _apiService.streamUbicacionesCirculo(ids);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          "Mapa del Círculo",
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      extendBodyBehindAppBar: true,
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _membersStream,
        builder: (context, snapshot) {
          if (snapshot.hasData) {
            _currentMembers = snapshot.data!;
            // Centrar automáticamente la primera vez que recibimos datos reales
            if (!_hasCentered &&
                _currentMembers.any((m) => m['latitud'] != null)) {
              _hasCentered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final firstWithLoc =
                    _currentMembers.firstWhere((m) => m['latitud'] != null);
                _mapController.move(
                    LatLng((firstWithLoc['latitud'] as num).toDouble(),
                        (firstWithLoc['longitud'] as num).toDouble()),
                    14.0);
              });
            }
          }

          return Stack(
            children: [
              FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: _getInitialCenter(),
                  initialZoom: 13.0,
                ),
                children: [
                  TileLayer(
                    urlTemplate: isDark
                        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
                    subdomains: const ['a', 'b', 'c', 'd'],
                  ),
                  MarkerLayer(
                    markers: _currentMembers
                        .where((m) =>
                            m['latitud'] != null && m['longitud'] != null)
                        .map((m) {
                      return Marker(
                        point: LatLng(
                          (m['latitud'] as num).toDouble(),
                          (m['longitud'] as num).toDouble(),
                        ),
                        width: 45,
                        height: 45,
                        child: _buildMemberMarker(m),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // PANEL INFERIOR CON RESUMEN
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: GlassBox(
                    borderRadius: 25,
                    opacity: isDark ? 0.1 : 0.05,
                    blur: 15,
                    padding: const EdgeInsets.all(15),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          "MIEMBROS ACTIVOS",
                          style: TextStyle(
                            color: Colors.blueAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                        const SizedBox(height: 10),
                        SizedBox(
                          height: 60,
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: _currentMembers.length,
                            itemBuilder: (context, index) {
                              final m = _currentMembers[index];
                              final hasLocation = m['latitud'] != null;
                              return Padding(
                                padding: const EdgeInsets.only(right: 15),
                                child: GestureDetector(
                                  onTap: () {
                                    if (hasLocation) {
                                      _mapController.move(
                                        LatLng(
                                          (m['latitud'] as num).toDouble(),
                                          (m['longitud'] as num).toDouble(),
                                        ),
                                        16,
                                      );
                                    }
                                  },
                                  child: Column(
                                    children: [
                                      CircleAvatar(
                                        radius: 20,
                                        backgroundColor: hasLocation
                                            ? Colors.blue.withValues(alpha: 0.2)
                                            : Colors.grey
                                                .withValues(alpha: 0.2),
                                        child: Text(
                                          (m['nombre_completo'] as String? ??
                                                  "U")[0]
                                              .toUpperCase(),
                                          style: TextStyle(
                                            color: hasLocation
                                                ? Colors.blue
                                                : Colors.grey,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (m['nombre_completo'] as String? ?? "")
                                            .split(' ')[0],
                                        style: TextStyle(
                                            color: textColor, fontSize: 8),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  LatLng _getInitialCenter() {
    for (var m in _currentMembers) {
      if (m['latitud'] != null && m['longitud'] != null) {
        return LatLng(
          (m['latitud'] as num).toDouble(),
          (m['longitud'] as num).toDouble(),
        );
      }
    }
    return const LatLng(-1.67098, -78.64712); // Default Riobamba
  }

  Widget _buildMemberMarker(Map<String, dynamic> member) {
    final String name = member['nombre_completo'] ?? "Usuario";
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : "U";

    // Generar un color basado en el ID para que sea consistente
    final String id = member['id'] ?? "";
    final Color memberColor =
        Colors.primaries[id.hashCode % Colors.primaries.length];

    return Stack(
      alignment: Alignment.center,
      children: [
        // Etiqueta de nombre (Sutil)
        Positioned(
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              name.split(' ')[0], // Solo el primer nombre
              style: const TextStyle(
                color: Colors.white,
                fontSize: 8,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        // Avatar Circular
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 33,
          height: 33,
          decoration: BoxDecoration(
            color: memberColor.withValues(alpha: 0.2),
            shape: BoxShape.circle,
            border: Border.all(color: memberColor, width: 2),
            boxShadow: [
              BoxShadow(
                color: memberColor.withValues(alpha: 0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Center(
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: memberColor,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
