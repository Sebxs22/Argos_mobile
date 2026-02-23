import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/utils/ui_utils.dart';

class CircleMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialMembers;
  const CircleMapScreen({super.key, required this.initialMembers});

  @override
  State<CircleMapScreen> createState() => _CircleMapScreenState();
}

class _CircleMapScreenState extends State<CircleMapScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  Timer? _locationTimer;

  late Stream<List<Map<String, dynamic>>> _membersStream;
  List<Map<String, dynamic>> _currentMembers = [];
  bool _hasCentered = false;
  String? _focusedMemberId; // v2.5.0: Para "Seguir" a alguien

  @override
  void initState() {
    super.initState();
    _currentMembers = widget.initialMembers;

    // Aseguramos IDs limpios (v2.5.0 Fix)
    final List<String> ids = widget.initialMembers
        .map((m) =>
            (m['id'] ?? m['usuario_id'] ?? m['guardian_id']) as String? ?? "")
        .where((id) => id.isNotEmpty)
        .toList();

    _membersStream = _apiService.streamUbicacionesCirculo(ids);
    _startLocationTracking();
  }

  void _animatedMapMove(LatLng destLocation, double destZoom) {
    final latTween = Tween<double>(
        begin: _mapController.camera.center.latitude,
        end: destLocation.latitude);
    final lngTween = Tween<double>(
        begin: _mapController.camera.center.longitude,
        end: destLocation.longitude);
    final zoomTween =
        Tween<double>(begin: _mapController.camera.zoom, end: destZoom);

    final controller = AnimationController(
        duration: const Duration(milliseconds: 1000), vsync: this);
    final animation =
        CurvedAnimation(parent: controller, curve: Curves.fastOutSlowIn);

    controller.addListener(() {
      _mapController.move(
          LatLng(latTween.evaluate(animation), lngTween.evaluate(animation)),
          zoomTween.evaluate(animation));
    });

    animation.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        controller.dispose();
      } else if (status == AnimationStatus.dismissed) {
        controller.dispose();
      }
    });

    controller.forward();
  }

  void _startLocationTracking() {
    _updateMyLocation();
    _locationTimer = Timer.periodic(const Duration(seconds: 15), (timer) {
      _updateMyLocation();
    });
  }

  Future<void> _updateMyLocation() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );
      if (mounted) {
        await _apiService.actualizarUbicacion(pos.latitude, pos.longitude);
      }
    } catch (e) {
      debugPrint("Error rastreo mapa círculo: $e");
    }
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

            // LÓGICA DE SEGUIMIENTO (SNAP MAPS STYLE v2.5.0)
            if (_focusedMemberId != null) {
              final focused = _currentMembers.firstWhere(
                (m) => m['id'] == _focusedMemberId && m['latitud'] != null,
                orElse: () => {},
              );
              if (focused.isNotEmpty) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _mapController.move(
                    LatLng((focused['latitud'] as num).toDouble(),
                        (focused['longitud'] as num).toDouble()),
                    _mapController.camera.zoom,
                  );
                });
              }
            }

            // Centrar automáticamente la primera vez
            if (!_hasCentered &&
                _currentMembers.any((m) => m['latitud'] != null)) {
              _hasCentered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final firstWithLoc =
                    _currentMembers.firstWhere((m) => m['latitud'] != null);
                _animatedMapMove(
                    LatLng((firstWithLoc['latitud'] as num).toDouble(),
                        (firstWithLoc['longitud'] as num).toDouble()),
                    15.0);
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
                      final bool isFocused = _focusedMemberId == m['id'];
                      return Marker(
                        point: LatLng(
                          (m['latitud'] as num).toDouble(),
                          (m['longitud'] as num).toDouble(),
                        ),
                        width: isFocused ? 70 : 55,
                        height: isFocused ? 70 : 55,
                        rotate: true,
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              _focusedMemberId = isFocused ? null : m['id'];
                            });
                            if (!isFocused) {
                              _animatedMapMove(
                                LatLng(
                                  (m['latitud'] as num).toDouble(),
                                  (m['longitud'] as num).toDouble(),
                                ),
                                17.0,
                              );
                            }
                          },
                          child: _buildMemberMarker(m, isFocused: isFocused),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),

              // BOTÓN CENTRAR TODO (v2.5.0)
              Positioned(
                right: 20,
                bottom: 160,
                child: FloatingActionButton(
                  mini: true,
                  onPressed: () {
                    setState(() => _focusedMemberId = null);
                    if (_currentMembers.any((m) => m['latitud'] != null)) {
                      final first = _currentMembers
                          .firstWhere((m) => m['latitud'] != null);
                      _animatedMapMove(
                        LatLng((first['latitud'] as num).toDouble(),
                            (first['longitud'] as num).toDouble()),
                        14.0,
                      );
                    }
                  },
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  child: const Icon(Icons.group_work_rounded,
                      color: Colors.blueAccent),
                ),
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
                              final id = m['id'] ??
                                  m['usuario_id'] ??
                                  m['guardian_id'];
                              final hasLocation = m['latitud'] != null;
                              final isFocused = _focusedMemberId == id;

                              return Padding(
                                padding: const EdgeInsets.only(right: 15),
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (hasLocation) {
                                      setState(() {
                                        _focusedMemberId =
                                            isFocused ? null : id;
                                      });
                                      if (!isFocused) {
                                        _animatedMapMove(
                                          LatLng(
                                            (m['latitud'] as num).toDouble(),
                                            (m['longitud'] as num).toDouble(),
                                          ),
                                          17.0,
                                        );
                                      }
                                    } else {
                                      UiUtils.showWarning(
                                          "${m['nombre_completo'] ?? 'El miembro'} no ha compartido su ubicación.");
                                    }
                                  },
                                  child: Column(
                                    children: [
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 300),
                                        padding: const EdgeInsets.all(2),
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: isFocused
                                                ? Colors.blueAccent
                                                : Colors.transparent,
                                            width: 2,
                                          ),
                                        ),
                                        child: CircleAvatar(
                                          radius: 18,
                                          backgroundColor: hasLocation
                                              ? Colors.blue
                                                  .withValues(alpha: 0.2)
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
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        (m['nombre_completo'] as String? ?? "")
                                            .split(' ')[0],
                                        style: TextStyle(
                                            color: isFocused
                                                ? Colors.blueAccent
                                                : textColor,
                                            fontSize: 8,
                                            fontWeight: isFocused
                                                ? FontWeight.bold
                                                : FontWeight.normal),
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

  @override
  void dispose() {
    _locationTimer?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Widget _buildMemberMarker(Map<String, dynamic> member,
      {bool isFocused = false}) {
    final String name = member['nombre_completo'] ?? "Usuario";
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : "U";

    // Generar un color basado en el ID para que sea consistente
    final String id = member['id'] ?? "";
    final Color memberColor =
        Colors.primaries[id.hashCode % Colors.primaries.length];

    final String lastConnect = member['ultima_conexion'] ?? "";
    final String timeAgo = _apiService.calcularTiempoTranscurrido(lastConnect);

    return AnimatedScale(
      scale: isFocused ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Etiqueta de nombre y tiempo (Sutil)
          Positioned(
            top: -25,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isFocused ? Colors.blueAccent : Colors.black87,
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    name.split(' ')[0],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    timeAgo,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 8,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Avatar Circular
          Container(
            width: isFocused ? 50 : 40,
            height: isFocused ? 50 : 40,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                  color: isFocused ? Colors.blueAccent : memberColor, width: 2),
              boxShadow: [
                BoxShadow(
                  color: (isFocused ? Colors.blueAccent : memberColor)
                      .withValues(alpha: 0.4),
                  blurRadius: 10,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Center(
              child: Text(
                initial,
                style: TextStyle(
                  fontSize: isFocused ? 18 : 14,
                  fontWeight: FontWeight.bold,
                  color: isFocused ? Colors.blueAccent : memberColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
