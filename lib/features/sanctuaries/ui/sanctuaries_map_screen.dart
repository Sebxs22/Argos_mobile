import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';

// --- UI COMPONENTS ---
import '../../../core/ui/glass_box.dart';

// --- DATA & NETWORKING ---
import '../data/mock_sanctuaries_data.dart';
import '../../../core/network/api_service.dart';

class SanctuariesMapScreen extends StatefulWidget {
  const SanctuariesMapScreen({super.key});

  @override
  State<SanctuariesMapScreen> createState() => _SanctuariesMapScreenState();
}

class _SanctuariesMapScreenState extends State<SanctuariesMapScreen>
    with AutomaticKeepAliveClientMixin, TickerProviderStateMixin, WidgetsBindingObserver {
  // ^ Agregamos WidgetsBindingObserver para detectar cuando entras a la app

  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  LatLng _currentCenter = const LatLng(-1.67098, -78.64712);

  bool _isLoadingLocation = true;
  bool _showHud = false;
  late AnimationController _radarController;
  Timer? _autoRefreshTimer;

  List<DangerZoneModel> _activeDangerZones = [];

  @override
  void initState() {
    super.initState();
    // Registramos el observador para saber si la app se minimiza o abre
    WidgetsBinding.instance.addObserver(this);

    _radarController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat();

    // 1. CARGA INICIAL
    _loadMapData();

    // 2. POLLING (Actualización silenciosa cada 5s)
    _startAutoRefresh();

    // 3. GPS ALTA PRECISIÓN
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this); // Dejamos de observar
    _radarController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  // --- DETECTOR DE ENTRADA A LA APP ---
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la app pasa de "Segundo Plano" a "Visible" (Resumed)
    if (state == AppLifecycleState.resumed) {
      print("MAPA: Regresaste a la app. Actualizando datos...");
      _loadMapData(); // ¡Actualización Inmediata!
      _getCurrentLocation(); // Refinamos GPS también
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadMapData();
    });
  }

  Future<void> _loadMapData() async {
    try {
      List<DangerZoneModel> realAlerts = await _apiService.obtenerAlertas();
      if (mounted) {
        setState(() {
          _activeDangerZones = realAlerts;
        });
      }
    } catch (e) {
      // Fallo silencioso
    }
  }

  Future<void> _getCurrentLocation() async {
    // Solo esperamos la primera vez para la animación
    if (_isLoadingLocation) await Future.delayed(const Duration(milliseconds: 1000));

    bool enabled = await Geolocator.isLocationServiceEnabled();
    if (enabled) {
      try {
        LocationPermission permission = await Geolocator.checkPermission();
        if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();

        if (permission == LocationPermission.whileInUse || permission == LocationPermission.always) {
          Position position = await Geolocator.getCurrentPosition(
              desiredAccuracy: LocationAccuracy.bestForNavigation // Precisión Militar (<5m)
          );

          if (mounted) {
            setState(() => _currentCenter = LatLng(position.latitude, position.longitude));
            if (_isLoadingLocation) {
              _mapController.move(_currentCenter, 16.0);
            }
          }
        }
      } catch (e) { print("Error GPS: $e"); }
    }
    _finishLoading();
  }

  void _finishLoading() {
    if (mounted) {
      setState(() => _isLoadingLocation = false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showHud = true);
      });
    }
  }

  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    const Distance distance = Distance();
    for (var zone in _activeDangerZones) {
      if (distance.as(LengthUnit.Meter, point, zone.center) <= zone.radius) {
        _showZoneDetails(zone);
        return;
      }
    }
  }

  void _showZoneDetails(DangerZoneModel zone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassBox(
          borderRadius: 30, opacity: 0.1, blur: 20,
          child: Container(
            padding: const EdgeInsets.all(20), height: 400,
            decoration: BoxDecoration(
                color: const Color(0xFF1E293B).withOpacity(0.95),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                border: Border.all(color: Colors.red.withOpacity(0.3))
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 30),
                  const SizedBox(width: 10),
                  const Text("ALERTA ZONA DE RIESGO", style: TextStyle(color: Color(0xFFFFCDD2), fontWeight: FontWeight.bold, fontSize: 18)),
                  const Spacer(),
                  IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close, color: Colors.white54))
                ]),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                Text("${zone.reports.length} reportes activos:", style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 10),
                Expanded(
                    child: ListView.builder(
                        itemCount: zone.reports.length,
                        itemBuilder: (context, index) {
                          final report = zone.reports[index];
                          return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(15),
                                  border: Border.all(color: Colors.white10)
                              ),
                              child: Row(children: [
                                Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(color: Colors.red.withOpacity(0.2), shape: BoxShape.circle),
                                    child: Icon(report.icon, color: Colors.redAccent, size: 20)
                                ),
                                const SizedBox(width: 15),
                                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Text(report.title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                  Text(report.description, style: const TextStyle(color: Colors.white60, fontSize: 12))
                                ])),
                                Text(report.timeAgo, style: const TextStyle(color: Colors.white38, fontSize: 10))
                              ])
                          );
                        }
                    )
                )
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: const Color(0xFF262626),

      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 80.0),
        child: FloatingActionButton(
          heroTag: "btnGps",
          mini: true,
          onPressed: () => _mapController.move(_currentCenter, 16.0),
          backgroundColor: const Color(0xFFE53935),
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),

      body: Stack(
        children: [
          if (_isLoadingLocation) _buildLoadingRadar() else _buildMap(),
        ],
      ),
    );
  }

  Widget _buildLoadingRadar() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          RotationTransition(
            turns: _radarController,
            child: Container(
              width: 100, height: 100,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 1),
                  gradient: SweepGradient(center: Alignment.center, colors: [Colors.transparent, Colors.blueAccent.withOpacity(0.5)])
              ),
              child: const Icon(Icons.satellite_alt, color: Colors.blue, size: 30),
            ),
          ),
          const SizedBox(height: 20),
          const Text("SINTONIZANDO RED ARGOS...", style: TextStyle(color: Colors.blueAccent, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentCenter,
            initialZoom: 15.0,
            minZoom: 10.0,
            maxZoom: 18.0,
            backgroundColor: const Color(0xFF262626),
            onTap: _handleMapTap,
          ),
          children: [
            TileLayer(
                urlTemplate: 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png',
                userAgentPackageName: 'com.argos.mobile_app',
                subdomains: const ['a', 'b', 'c', 'd'],
                tileDisplay: const TileDisplay.fadeIn(duration: Duration(milliseconds: 600))
            ),

            CircleLayer(
              circles: _activeDangerZones.map((zone) {
                return CircleMarker(
                  point: zone.center,
                  radius: zone.radius,
                  useRadiusInMeter: true,
                  color: Colors.red.withOpacity(0.15),
                  borderColor: Colors.red.withOpacity(0.4),
                  borderStrokeWidth: 1,
                );
              }).toList(),
            ),

            MarkerLayer(
              markers: [
                Marker(point: _currentCenter, width: 50, height: 50, child: _buildMyPositionMarker()),
                ...kSanctuariesDB.map((site) => Marker(
                    point: site.location,
                    width: 60,
                    height: 60,
                    child: _buildDynamicMarkerIcon(site)
                )),
              ],
            ),
          ],
        ),

        // --- LEYENDA (HUD) SUPERIOR COMPLETA Y DESLIZABLE ---
        Align(
          alignment: Alignment.topCenter,
          child: Padding(
            padding: const EdgeInsets.only(top: 60),
            child: AnimatedOpacity(
                opacity: _showHud ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 800),
                child: GlassBox(
                    borderRadius: 20,
                    opacity: 0.1,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    // Usamos SingleChildScrollView para que quepan todos
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const BouncingScrollPhysics(),
                      child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildLegendItem(Icons.warning, Colors.red, "Peligro"),
                            const SizedBox(width: 12),
                            _buildLegendItem(Icons.local_police, Colors.greenAccent, "UPC"),
                            const SizedBox(width: 12),
                            _buildLegendItem(Icons.local_pharmacy, Colors.pinkAccent, "Farmacia"),
                            const SizedBox(width: 12),
                            _buildLegendItem(Icons.local_hospital, Colors.blue, "Salud"),
                            const SizedBox(width: 12),
                            _buildLegendItem(Icons.school, Colors.orange, "Edu"),
                            const SizedBox(width: 12),
                            _buildLegendItem(Icons.store, Colors.purpleAccent, "Tienda"),
                            const SizedBox(width: 12),
                            _buildLegendItem(Icons.park, Colors.tealAccent, "Parque"),
                            const SizedBox(width: 12),
                            _buildLegendItem(Icons.church, Colors.amber, "Iglesia"),
                          ]
                      ),
                    )
                )
            ),
          ),
        ),
      ],
    );
  }

  // --- WIDGETS AUXILIARES ---

  Widget _buildDynamicMarkerIcon(SanctuaryModel site) {
    IconData icon; Color color;
    switch (site.type) {
      case SanctuaryType.police: icon = Icons.local_police; color = Colors.greenAccent; break;
      case SanctuaryType.health: icon = Icons.local_hospital; color = Colors.blue; break;
      case SanctuaryType.education: icon = Icons.school; color = Colors.orange; break;
      case SanctuaryType.store: icon = Icons.store; color = Colors.purpleAccent; break;
      case SanctuaryType.park: icon = Icons.park; color = Colors.tealAccent; break;
      case SanctuaryType.pharmacy: icon = Icons.local_pharmacy; color = Colors.pinkAccent; break;
      case SanctuaryType.church: icon = Icons.church; color = Colors.amber; break;
    }
    return Column(children: [
      Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
              color: const Color(0xFF262626).withOpacity(0.9),
              shape: BoxShape.circle,
              border: Border.all(color: color)
          ),
          child: Icon(icon, color: color, size: 14)
      )
    ]);
  }

  Widget _buildLegendItem(IconData icon, Color color, String text) {
    return Row(children: [
      Icon(icon, color: color, size: 14),
      const SizedBox(width: 4),
      Text(text, style: const TextStyle(color: Colors.white70, fontSize: 11, fontWeight: FontWeight.bold))
    ]);
  }

  Widget _buildMyPositionMarker() {
    return Stack(
        alignment: Alignment.center,
        children: [
          Container(width: 50, height: 50, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue.withOpacity(0.15))),
          Container(width: 14, height: 14, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.blue, border: Border.all(color: Colors.white, width: 2), boxShadow: [BoxShadow(color: Colors.blue.withOpacity(0.6), blurRadius: 8)]))
        ]
    );
  }
}