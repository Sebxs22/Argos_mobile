import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// --- UI Y LOGICA PROPIA ---
import '../../../core/ui/glass_box.dart';
import '../../../core/network/api_service.dart';
import '../../sanctuaries/data/mock_sanctuaries_data.dart';
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
        } else if (result.containsKey('error')) {
          debugPrint("Error en ruta: ${result['error']}");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Error al calcular ruta: ${result['error']}"),
            ),
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
      backgroundColor:
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
      // Botón para re-centrar el mapa
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 95.0),
        child: FloatingActionButton(
          heroTag: "btnCenterRoute",
          mini: true,
          onPressed: _initGPS,
          backgroundColor: const Color(0xFFE53935),
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          _buildMap(isDark),
          _buildTopInterface(isDark),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(color: Colors.redAccent),
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
        backgroundColor:
            isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
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
        // Dibujamos la Polyline (Ruta física)
        if (_routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points: _routePoints,
                strokeWidth: 5,
                color: _securityScore > 80
                    ? Colors.blueAccent
                    : Colors.orangeAccent,
              ),
            ],
          ),
        // Marcadores de posición
        MarkerLayer(
          markers: [
            if (_myLocation != null)
              Marker(
                point: _myLocation!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.person_pin_circle,
                  color: Colors.blue,
                  size: 35,
                ),
              ),
            if (_destination != null)
              Marker(
                point: _destination!,
                width: 40,
                height: 40,
                child: const Icon(
                  Icons.location_on,
                  color: Colors.redAccent,
                  size: 40,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildTopInterface(bool isDark) {
    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: GlassBox(
        borderRadius: 20,
        opacity: isDark ? 0.1 : 0.08,
        blur: 15,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 10),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _transportIcon(Icons.directions_walk, 'foot', isDark),
            _transportIcon(Icons.directions_car, 'car', isDark),
            _transportIcon(Icons.directions_bike, 'bicycle', isDark),
          ],
        ),
      ),
    );
  }

  Widget _transportIcon(IconData icon, String mode, bool isDark) {
    bool isSelected = _selectedMode == mode;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: isSelected
            ? Colors.redAccent.withValues(alpha: isDark ? 0.15 : 0.1)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(15),
      ),
      child: IconButton(
        icon: Icon(
          icon,
          color: isSelected
              ? Colors.redAccent
              : (isDark ? Colors.white54 : Colors.black45),
          size: 26,
        ),
        onPressed: () {
          setState(() {
            _selectedMode = mode;
            _routePoints = []; // Reset visual
            _eta = "--";
            _distance = "--";
            _securityScore = 0;
          });
          if (_destination != null) _obtenerRuta();
        },
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
        opacity: isDark ? 0.2 : 0.2, // Aumentamos opacidad en claro
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
                        color: isDark
                            ? Colors.white54
                            : Colors.black87, // Más oscuro en claro
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
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("🛡️ Argos vigilando. Modo Travesía activo."),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFE53935),
                minimumSize: const Size(double.infinity, 55),
                elevation: 10,
                shadowColor: Colors.redAccent.withValues(alpha: 0.3),
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
            color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
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
                        "${report.description} (${report.timeAgo})",
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
}
