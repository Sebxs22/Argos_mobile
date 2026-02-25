import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// --- UI Y LOGICA PROPIA ---
import '../../../core/ui/glass_box.dart';
import '../../../core/network/api_service.dart';
import '../../../core/ui/argos_notifications.dart'; // v2.14.1
import '../../sanctuaries/data/mock_sanctuaries_data.dart';
import '../../../core/utils/ui_tokens.dart'; // v2.14.9
import 'package:flutter_background_service/flutter_background_service.dart';

class RoutesScreen extends StatefulWidget {
  const RoutesScreen({super.key});

  @override
  State<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends State<RoutesScreen> {
  // --- CONTROLADORES ---
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  // --- ESTADO DE LA RUTA ---
  LatLng? _myLocation;
  LatLng? _destination;
  List<LatLng> _routePoints = [];
  List<DangerZoneModel> _alertsOnRoute = [];

  // Perfiles OSRM: foot (a pie), car (auto), bicycle (bici)
  String _selectedMode = 'foot';
  double _securityScore = 0;
  String _eta = "--";
  String _distance = "--";
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _initGPS();
  }

  // --- OBTENER UBICACIÓN INICIAL ---
  Future<void> _initGPS() async {
    try {
      Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() => _myLocation = LatLng(pos.latitude, pos.longitude));
        _mapController.move(_myLocation!, 16.0);
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
    }
  }

  // --- FORMATEADOR DE TIEMPO REAL ---
  String _formatearTiempo(double segundos) {
    if (segundos == 0) return "--";

    Duration duration = Duration(seconds: segundos.round());
    int horas = duration.inHours;
    int minutos = duration.inMinutes.remainder(60);

    if (horas > 0) {
      return "$horas h $minutos min";
    } else {
      return "$minutos min";
    }
  }

  // --- LÓGICA DE INTERACCIÓN CON EL MAPA ---
  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _destination = point;
      _routePoints = [];
      _alertsOnRoute = [];
    });
    _obtenerRuta();
  }

  Future<void> _obtenerRuta() async {
    if (_myLocation == null || _destination == null) return;

    setState(() => _isLoading = true);

    // Llamamos al API con el modo correcto (foot, car, o bicycle)
    final result = await _apiService.calcularRutaSegura(
      _myLocation!,
      _destination!,
      modo: _selectedMode,
    );

    if (mounted) {
      setState(() {
        _isLoading = false;
        if (result.containsKey('points')) {
          _routePoints = result['points'];
          _securityScore = result['score'];

          // Formateamos los datos recibidos de la nube
          double duracionEnSegundos = (result['duracion'] ?? 0).toDouble();
          _eta = _formatearTiempo(duracionEnSegundos);

          double met = (result['distancia'] ?? 0).toDouble();
          _distance = met > 1000
              ? "${(met / 1000).toStringAsFixed(1)} km"
              : "${met.round()} m";

          _escanearPeligrosEnTrayecto();

          // v2.14.0: EFECTO DE CÁMARA DIVINA (Auto-ajuste suave)
          _animatedMapMoveToRoute();
        } else if (result.containsKey('error')) {
          debugPrint("Error en ruta: ${result['error']}");
          ArgosNotifications.show(
            context,
            "Error al calcular ruta: ${result['error']}",
            type: ArgosNotificationType.error,
          );
        }
      });
    }
  }

  void _escanearPeligrosEnTrayecto() async {
    final todasLasAlertas = await _apiService.obtenerAlertas();
    const Distance distance = Distance();
    List<DangerZoneModel> detectadas = [];

    for (var zona in todasLasAlertas) {
      for (var punto in _routePoints) {
        // Escaneamos 120 metros a la redonda de cada punto de la ruta
        if (distance.as(LengthUnit.Meter, punto, zona.center) < 120) {
          if (!detectadas.contains(zona)) detectadas.add(zona);
          break;
        }
      }
    }

    setState(() => _alertsOnRoute = detectadas);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Scaffold(
      backgroundColor: UiTokens.background(context),
      // Botón para re-centrar el mapa
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 95.0),
        child: FloatingActionButton(
          heroTag: "btnCenterRoute",
          mini: true,
          onPressed: _initGPS,
          backgroundColor: UiTokens.argosRed,
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          _buildMap(isDark),
          _buildTopInterface(isDark),
          if (_isLoading)
            Center(
              child: GlassBox(
                borderRadius: 20,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const CircularProgressIndicator(color: Colors.redAccent),
                    const SizedBox(height: 15),
                    Text("TRAZANDO RUTA SEGURA...",
                        style: TextStyle(
                            color: textColor,
                            fontSize: 10,
                            letterSpacing: 1.5,
                            fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
          if (_routePoints.isNotEmpty) _buildBottomDetails(isDark, textColor),
        ],
      ),
    );
  }

  Widget _buildMap(bool isDark) {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _myLocation ?? const LatLng(-1.67, -78.64),
        initialZoom: 15.0,
        onTap: _onMapTap, // Captura el destino
        backgroundColor: UiTokens.background(context),
      ),
      children: [
        TileLayer(
          urlTemplate: isDark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          tileDisplay: const TileDisplay.fadeIn(
            duration: Duration(milliseconds: 500),
          ),
        ),
        // v2.14.0: CAPA DIVINA DE RUTAS (Glow + Segmentos)
        if (_routePoints.isNotEmpty) ...[
          // 1. CAPA DE RESPLANDOR (GLOW) - Fondo azul/cian difuso
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 12,
                color: Colors.blueAccent.withValues(alpha: 0.2),
                isDotted: false,
              ),
            ],
          ),
          // 2. CAPA DE RIESGO SEGMENTADA (El dibujo "Lindo y Divino")
          _buildSegmentedRouteLayer(),
        ],
        // Marcadores de posición
        MarkerLayer(
          markers: [
            if (_myLocation != null)
              Marker(
                point: _myLocation!,
                width: 60,
                height: 60,
                child: _buildLocationMarker(isDark, true),
              ),
            if (_destination != null)
              Marker(
                point: _destination!,
                width: 60,
                height: 60,
                child: _buildLocationMarker(isDark, false),
              ),
          ],
        ),
      ],
    );
  }

  // v2.14.0: Renderizado segmentado para detectar riesgos por tramos
  Widget _buildSegmentedRouteLayer() {
    List<Polyline> segments = [];
    const int step = 3; // Analizar cada 3 puntos para fluidez

    for (int i = 0; i < _routePoints.length - step; i += step) {
      final p1 = _routePoints[i];
      final p2 = _routePoints[i + step];

      bool isSegmentDangerous = false;
      const Distance distance = Distance();

      // Verificar si este tramo pasa cerca de una zona de riesgo
      for (var zona in _alertsOnRoute) {
        if (distance.as(LengthUnit.Meter, p1, zona.center) < zona.radius + 50) {
          isSegmentDangerous = true;
          break;
        }
      }

      segments.add(Polyline(
        points: [p1, p2],
        strokeWidth: 5,
        color: isSegmentDangerous ? Colors.orangeAccent : Colors.cyanAccent,
      ));
    }

    return PolylineLayer(polylines: segments);
  }

  // v2.14.0: Marcadores con aura premium
  Widget _buildLocationMarker(bool isDark, bool isMe) {
    final color = isMe ? Colors.blueAccent : Colors.redAccent;
    return Container(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.4),
            blurRadius: 15,
            spreadRadius: 5,
          ),
        ],
      ),
      child: Icon(
        isMe ? Icons.stars : Icons.location_on,
        color: color,
        size: isMe ? 35 : 45,
      ),
    );
  }

  Widget _buildTopInterface(bool isDark) {
    return Positioned(
      top: 100, // v2.13.0: Bajado para no tapar botón de volver
      left: 20,
      right: 20,
      child: GlassBox(
        borderRadius: 25,
        opacity: UiTokens.glassOpacity(context),
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 15),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _transportOption(Icons.directions_walk, 'foot', "A PIE", isDark),
            _transportOption(Icons.directions_car, 'car', "AUTO", isDark),
            _transportOption(Icons.directions_bike, 'bicycle', "BICI", isDark),
          ],
        ),
      ),
    );
  }

  Widget _transportOption(
      IconData icon, String mode, String label, bool isDark) {
    bool isSelected = _selectedMode == mode;
    final activeColor = Colors.redAccent;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedMode = mode;
          _routePoints = [];
          _eta = "--";
          _distance = "--";
          _securityScore = 0;
        });
        if (_destination != null) _obtenerRuta();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? activeColor.withValues(alpha: 0.15)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(
            color: isSelected ? activeColor : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected
                  ? activeColor
                  : UiTokens.secondaryTextColor(context),
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected
                    ? activeColor
                    : UiTokens.secondaryTextColor(context),
                fontSize: 9,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomDetails(bool isDark, Color textColor) {
    return Positioned(
      bottom: 110,
      left: 20,
      right: 20,
      child: GlassBox(
        borderRadius: 25,
        opacity: UiTokens.glassOpacity(context),
        blur: 20,
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "LLEGADA EN $_eta",
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    Text(
                      "Distancia: $_distance",
                      style: TextStyle(
                        color: UiTokens.secondaryTextColor(context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                _buildSecurityBadge(),
              ],
            ),
            const SizedBox(height: 18),
            // Botón dinámico de peligros
            if (_alertsOnRoute.isNotEmpty)
              GestureDetector(
                onTap: () => _verAlertasEnRuta(isDark, textColor),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 15),
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: isDark ? 0.1 : 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: !isDark
                        ? Border.all(color: Colors.red.withValues(alpha: 0.2))
                        : null,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        "${_alertsOnRoute.length} peligros detectados. Ver más.",
                        style: TextStyle(
                          color:
                              isDark ? Colors.redAccent : Colors.red.shade900,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ElevatedButton(
              onPressed: () {
                FlutterBackgroundService().startService();

                // v2.13.1: Feedback Premium en lugar de SnackBar
                showDialog(
                  context: context,
                  barrierColor: Colors.black.withValues(alpha: 0.8),
                  builder: (context) => Center(
                    child: GlassBox(
                      borderRadius: 25,
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                              color: Colors.redAccent.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.security,
                                color: Colors.redAccent, size: 40),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            "MODO TRAVESÍA ACTIVO",
                            style: TextStyle(
                              color: UiTokens.argosRed,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 1.2,
                            ),
                          ),
                          const SizedBox(height: 15),
                          Text(
                            "Argos rastrea tu ubicación en segundo plano y alertará a tu Círculo si detecta desviaciones o riesgos en la ruta.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: UiTokens.secondaryTextColor(context),
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 25),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () => Navigator.pop(context),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.redAccent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15)),
                              ),
                              child: const Text("ENTENDIDO"),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: UiTokens.argosRed,
                foregroundColor:
                    Colors.white, // Aseguramos color de texto blanco
                minimumSize: const Size(double.infinity, 55),
                elevation: 10,
                shadowColor: isDark
                    ? Colors.redAccent.withValues(alpha: 0.3)
                    : Colors.black.withValues(alpha: 0.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              child: const Text(
                "INICIAR RECORRIDO PROTEGIDO",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.8,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSecurityBadge() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    bool isSafe = _securityScore > 80;

    // Tonos más oscuros para modo claro
    final Color baseColor = isSafe
        ? (isDark ? Colors.greenAccent : Colors.green.shade800)
        : (isDark ? Colors.orangeAccent : Colors.orange.shade900);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: baseColor.withValues(alpha: isDark ? 0.2 : 0.15),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(
          color: baseColor,
          width: 1.5,
        ),
      ),
      child: Text(
        "${_securityScore.toInt()}%",
        style: TextStyle(
          color: baseColor,
          fontWeight: FontWeight.bold,
          fontSize: 14,
        ),
      ),
    );
  }

  void _verAlertasEnRuta(bool isDark, Color textColor) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => GlassBox(
        borderRadius: 25,
        opacity: isDark ? 0.3 : 0.1,
        child: Container(
          padding: const EdgeInsets.all(25),
          decoration: BoxDecoration(
            color: UiTokens.surface(context),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "RIESGOS EN EL CAMINO",
                style: TextStyle(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: ListView.builder(
                  itemCount: _alertsOnRoute.length,
                  itemBuilder: (context, i) {
                    final report = _alertsOnRoute[i].reports.first;
                    return ListTile(
                      leading: const Icon(
                        Icons.dangerous,
                        color: Colors.redAccent,
                      ),
                      title: Text(
                        report.title,
                        style: TextStyle(
                          color: textColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      subtitle: Text(
                        "${report.description} (${_apiService.calcularTiempoTranscurrido(report.timestamp.toIso8601String())})",
                        style: TextStyle(
                            color: isDark ? Colors.white54 : Colors.black54),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // v2.14.0: Función de movimiento suave de cámara (Animation Controller manual)
  void _animatedMapMoveToRoute() {
    if (_routePoints.isEmpty) return;

    // Calcular centro y zoom ideal para la ruta
    double minLat = _routePoints[0].latitude;
    double maxLat = _routePoints[0].latitude;
    double minLng = _routePoints[0].longitude;
    double maxLng = _routePoints[0].longitude;

    for (var p in _routePoints) {
      if (p.latitude < minLat) minLat = p.latitude;
      if (p.latitude > maxLat) maxLat = p.latitude;
      if (p.longitude < minLng) minLng = p.longitude;
      if (p.longitude > maxLng) maxLng = p.longitude;
    }

    final LatLng center = LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2);

    // Mover con animación sutil (vía move con fitBounds indirecto o move directo)
    // Para simplificar sin controladores pesados, usamos move al centro con un zoom calculado
    _mapController.move(center, 14.5);
  }
}
