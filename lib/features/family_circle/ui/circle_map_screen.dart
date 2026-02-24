import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/network/api_service.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/ui/argos_notifications.dart'; // v2.14.1

class CircleMapScreen extends StatefulWidget {
  final List<Map<String, dynamic>> initialMembers;
  final LatLng? focusLocation;
  final String? alertMemberId;

  const CircleMapScreen({
    super.key,
    required this.initialMembers,
    this.focusLocation,
    this.alertMemberId,
  });

  @override
  State<CircleMapScreen> createState() => _CircleMapScreenState();
}

class _CircleMapScreenState extends State<CircleMapScreen>
    with TickerProviderStateMixin {
  final ApiService _apiService = ApiService();
  final MapController _mapController = MapController();

  Timer? _locationTimer;

  late Stream<List<Map<String, dynamic>>> _membersStream;
  late Stream<List<Map<String, dynamic>>> _alertsStream; // v2.6.0

  List<Map<String, dynamic>> _currentMembers = [];
  List<Map<String, dynamic>> _activeAlerts = []; // v2.6.0
  List<Map<String, dynamic>> _safePlaces = []; // v2.14.6

  bool _hasCentered = false;
  String? _focusedMemberId;

  late AnimationController _pulseController; // v2.6.0: Efecto alerta

  @override
  void initState() {
    super.initState();
    _currentMembers = widget.initialMembers;
    _focusedMemberId = widget.alertMemberId;

    // Configurar pulso de alerta
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    // Aseguramos IDs limpios
    final List<String> ids = widget.initialMembers
        .map((m) =>
            (m['id'] ?? m['usuario_id'] ?? m['guardian_id']) as String? ?? "")
        .where((id) => id.isNotEmpty)
        .toList();

    _membersStream = _apiService.streamUbicacionesCirculo(ids);
    _alertsStream = _apiService.streamAlertasRecientesCirculo(ids);

    _loadSafePlaces(); // v2.14.6
    _startLocationTracking();

    // LÓGICA DE FOCO INICIAL
    if (widget.focusLocation != null) {
      _hasCentered = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _animatedMapMove(widget.focusLocation!, 16.0);
      });
    }
  }

  @override
  void dispose() {
    _locationTimer?.cancel();
    _pulseController.dispose();
    _mapController.dispose();
    super.dispose();
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

  Future<void> _loadSafePlaces() async {
    try {
      final places = await _apiService.obtenerMisLugaresSeguros();
      if (mounted) {
        setState(() => _safePlaces = places);
      }
    } catch (e) {
      debugPrint("Error cargando geocercas en mapa: $e");
    }
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
            final List<Map<String, dynamic>> updatedData = snapshot.data!;
            for (var update in updatedData) {
              final index = _currentMembers.indexWhere((m) {
                final mId = (m['id'] ?? m['usuario_id'] ?? m['guardian_id']);
                return mId == update['id'];
              });
              if (index != -1) {
                _currentMembers[index] = {..._currentMembers[index], ...update};
              }
            }

            // Seguimiento dinámico (v2.7.1: Prioridad a alerta)
            if (_focusedMemberId != null) {
              final focused = _currentMembers.firstWhere(
                (m) =>
                    (m['id'] ?? m['usuario_id'] ?? m['guardian_id']) ==
                        _focusedMemberId &&
                    m['latitud'] != null,
                orElse: () => {},
              );
              if (focused.isNotEmpty && !_hasCentered) {
                _hasCentered = true; // Evitar saltos constantes
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _animatedMapMove(
                    LatLng((focused['latitud'] as num).toDouble(),
                        (focused['longitud'] as num).toDouble()),
                    16.0,
                  );
                });
              }
            }

            // Centro inicial
            if (!_hasCentered &&
                _currentMembers.any((m) => m['latitud'] != null)) {
              _hasCentered = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                final first =
                    _currentMembers.firstWhere((m) => m['latitud'] != null);
                _animatedMapMove(
                    LatLng((first['latitud'] as num).toDouble(),
                        (first['longitud'] as num).toDouble()),
                    15.0);
              });
            }
          }

          return StreamBuilder<List<Map<String, dynamic>>>(
            stream: _alertsStream,
            builder: (context, alertSnapshot) {
              if (alertSnapshot.hasData) {
                _activeAlerts = alertSnapshot.data!;
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
                      // CAPA DE GEOCERCAS (v2.14.6)
                      CircleLayer(
                        circles: _safePlaces.map((p) {
                          return CircleMarker(
                            point: LatLng((p['latitud'] as num).toDouble(),
                                (p['longitud'] as num).toDouble()),
                            radius: (p['radio'] as num).toDouble(),
                            useRadiusInMeter: true,
                            color: Colors.blueAccent.withValues(alpha: 0.1),
                            borderColor:
                                Colors.blueAccent.withValues(alpha: 0.3),
                            borderStrokeWidth: 1,
                          );
                        }).toList(),
                      ),
                      // CAPA DE ALERTAS (v2.6.0)
                      MarkerLayer(
                        markers: _activeAlerts.map((a) {
                          return Marker(
                            point: LatLng(
                              (a['latitud'] as num).toDouble(),
                              (a['longitud'] as num).toDouble(),
                            ),
                            width: 80,
                            height: 80,
                            child: _buildAlertMarker(a),
                          );
                        }).toList(),
                      ),
                      // CAPA DE MIEMBROS
                      MarkerLayer(
                        markers: _currentMembers
                            .where((m) =>
                                m['latitud'] != null && m['longitud'] != null)
                            .map((m) {
                          final String id =
                              (m['id'] ?? m['usuario_id'] ?? m['guardian_id']);
                          final bool isFocused = _focusedMemberId == id;
                          return Marker(
                            point: LatLng(
                              (m['latitud'] as num).toDouble(),
                              (m['longitud'] as num).toDouble(),
                            ),
                            width: isFocused ? 75 : 60,
                            height: isFocused ? 75 : 60,
                            rotate: true,
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _focusedMemberId = isFocused ? null : id;
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
                              child:
                                  _buildMemberMarker(m, isFocused: isFocused),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),

                  // BOTÓN CENTRAR (v2.8.0: Más alto para evitar el panel de miembros)
                  Positioned(
                    right: 20,
                    bottom: 220,
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
                              15.0);
                        }
                      },
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location,
                          color: Colors.blueAccent),
                    ),
                  ),

                  // PANEL DE MIEMBROS
                  Positioned(
                    bottom: 20,
                    left: 20,
                    right: 20,
                    child: GlassBox(
                      child: Container(
                        height: 120,
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  "Miembros de tu Círculo",
                                  style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12),
                                ),
                                if (_activeAlerts.isNotEmpty)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Text(
                                      "¡EMERGENCIA!",
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold),
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Expanded(
                              child: ListView.builder(
                                scrollDirection: Axis.horizontal,
                                itemCount: _currentMembers.length,
                                itemBuilder: (context, index) {
                                  final m = _currentMembers[index];
                                  final id = (m['id'] ??
                                      m['usuario_id'] ??
                                      m['guardian_id']);
                                  final bool isFocused = _focusedMemberId == id;
                                  final bool hasLocation = m['latitud'] != null;

                                  return GestureDetector(
                                    onTap: () {
                                      if (hasLocation) {
                                        setState(() => _focusedMemberId = id);
                                        _animatedMapMove(
                                          LatLng(
                                              (m['latitud'] as num).toDouble(),
                                              (m['longitud'] as num)
                                                  .toDouble()),
                                          17.0,
                                        );
                                      } else {
                                        ArgosNotifications.show(
                                          context,
                                          "${m['nombre_completo']} no está compartiendo ubicación",
                                          type: ArgosNotificationType.warning,
                                        );
                                      }
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.only(right: 15),
                                      child: Column(
                                        children: [
                                          CircleAvatar(
                                            radius: 20,
                                            backgroundColor: isFocused
                                                ? Colors.blueAccent
                                                : (hasLocation
                                                    ? Colors.blue
                                                        .withValues(alpha: 0.1)
                                                    : Colors.grey.withValues(
                                                        alpha: 0.1)),
                                            backgroundImage: m['avatar_url'] !=
                                                    null
                                                ? NetworkImage(m['avatar_url'])
                                                : null,
                                            child: m['avatar_url'] == null
                                                ? Text(
                                                    (m['nombre_completo'] ??
                                                            "U")[0]
                                                        .toUpperCase(),
                                                    style: TextStyle(
                                                        color: hasLocation
                                                            ? (isFocused
                                                                ? Colors.white
                                                                : Colors.blue)
                                                            : Colors.grey,
                                                        fontWeight:
                                                            FontWeight.bold),
                                                  )
                                                : null,
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            (m['nombre_completo'] as String? ??
                                                    "")
                                                .split(' ')[0],
                                            style: TextStyle(
                                                color: isFocused
                                                    ? Colors.blueAccent
                                                    : textColor,
                                                fontSize: 9),
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
    return const LatLng(-1.67098, -78.64712); // Riobamba
  }

  Widget _buildAlertMarker(Map<String, dynamic> alert) {
    final String userId = alert['usuario_id'] ?? "";
    final member = _currentMembers.firstWhere(
      (m) => (m['id'] ?? m['usuario_id'] ?? m['guardian_id']) == userId,
      orElse: () => {},
    );
    final String name = member['nombre_completo'] ?? "Alerta";
    final String fechaStr = alert['fecha'] ?? "";
    final String timeAgo = _apiService.calcularTiempoTranscurrido(fechaStr);

    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 40 + (40 * _pulseController.value),
              height: 40 + (40 * _pulseController.value),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    Colors.red.withValues(alpha: 1.0 - _pulseController.value),
              ),
            ),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: const [
                      BoxShadow(color: Colors.black45, blurRadius: 4)
                    ],
                  ),
                  child: Column(
                    children: [
                      Text("ORIGEN ALERTA",
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 7,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1)),
                      Text(name.split(' ')[0],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                      Text(timeAgo,
                          style: const TextStyle(
                              color: Colors.white, fontSize: 8)),
                    ],
                  ),
                ),
                const Icon(Icons.warning_rounded, color: Colors.red, size: 30),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildMemberMarker(Map<String, dynamic> member,
      {bool isFocused = false}) {
    final String name = member['nombre_completo'] ?? "Usuario";
    final String initial = name.isNotEmpty ? name[0].toUpperCase() : "U";
    final String id = member['id'] ?? "";
    final Color memberColor =
        Colors.primaries[id.hashCode % Colors.primaries.length];
    final String lastConnect = member['ultima_conexion'] ?? "";
    final String timeAgo = _apiService.calcularTiempoTranscurrido(lastConnect);

    final bool isMoving = member['is_accompaniment_active'] ?? false;

    return AnimatedScale(
      scale: isFocused ? 1.2 : 1.0,
      duration: const Duration(milliseconds: 300),
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -25,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isFocused
                    ? Colors.blueAccent
                    : (isMoving ? Colors.green : Colors.black87),
                borderRadius: BorderRadius.circular(15),
                boxShadow: const [
                  BoxShadow(
                      color: Colors.black26,
                      blurRadius: 4,
                      offset: Offset(0, 2))
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (isMoving)
                        const Padding(
                          padding: EdgeInsets.only(right: 4.0),
                          child: Icon(Icons.directions_run,
                              color: Colors.white, size: 10),
                        ),
                      Text(name.split(' ')[0],
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                  Text(isMoving ? "EN CAMINO" : timeAgo,
                      style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.8),
                          fontSize: 8,
                          fontWeight:
                              isMoving ? FontWeight.bold : FontWeight.normal)),
                ],
              ),
            ),
          ),
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
                    spreadRadius: 2)
              ],
            ),
            child: ClipOval(
              child: member['avatar_url'] != null
                  ? Image.network(
                      member['avatar_url'],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Text(initial,
                            style: TextStyle(
                                fontSize: isFocused ? 18 : 14,
                                fontWeight: FontWeight.bold,
                                color: isFocused
                                    ? Colors.blueAccent
                                    : memberColor)),
                      ),
                    )
                  : Center(
                      child: Text(initial,
                          style: TextStyle(
                              fontSize: isFocused ? 18 : 14,
                              fontWeight: FontWeight.bold,
                              color:
                                  isFocused ? Colors.blueAccent : memberColor)),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
