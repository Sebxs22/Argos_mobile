import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_map_marker_cluster/flutter_map_marker_cluster.dart'; // Import Clustering

// --- COMPONENTES Y LOGICA ---
import '../../../core/ui/glass_box.dart';
import '../data/mock_sanctuaries_data.dart';
import '../../../core/network/api_service.dart';
import '../../family_circle/ui/family_circle_screen.dart'; // Import

class SanctuariesMapScreen extends StatefulWidget {
  const SanctuariesMapScreen({super.key});

  @override
  State<SanctuariesMapScreen> createState() => _SanctuariesMapScreenState();
}

class _SanctuariesMapScreenState extends State<SanctuariesMapScreen>
    with
        AutomaticKeepAliveClientMixin,
        TickerProviderStateMixin,
        WidgetsBindingObserver {
  final MapController _mapController = MapController();
  final ApiService _apiService = ApiService();

  // Coordenada inicial (Riobamba)
  LatLng _currentCenter = const LatLng(-1.67098, -78.64712);

  bool _isLoadingLocation = true;
  bool _showHud = false;
  late AnimationController _radarController;

  // Lista de zonas de peligro de Supabase (Refrescada por el Stream)
  List<DangerZoneModel> _activeDangerZones = [];

  // Lista dinámica de Santuarios (v2.8.8)
  List<SanctuaryModel> _dynamicSanctuaries = [];
  StreamSubscription? _alertsSubscription;
  StreamSubscription<Position>? _positionStream; // v2.9.3: Escaneo inteligente
  bool _isScanningSanctuaries = false;
  LatLng? _lastScannedPosition; // v2.10.0: Evitar re-escaneos innecesarios
  Timer? _refreshTimer;

  final Set<String> _activeFilters = {
    'Peligro',
    'Policía',
    'Salud',
    'Farmacia',
    'Educación',
    'Tienda',
    'Parque',
    'Iglesia',
  };

  @override
  void initState() {
    super.initState();
    // Registrar observador para detectar cuando el usuario vuelve a la app
    WidgetsBinding.instance.addObserver(this);

    // v2.12.1: Cargar desde Caché si existe
    if (ApiService.cacheSantuarios.isNotEmpty) {
      _dynamicSanctuaries = ApiService.cacheSantuarios;
      _lastScannedPosition = ApiService.ultimaPosicionSantuarios;
    }

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // 4. Suscribirse a datos en Tiempo Real (v2.4.5)
    _subscribeToAlerts();

    // 4.1 Suscribirse a movimiento para escaneo dinámico (v2.9.3)
    _initMovementScan();

    // 5. CARGA INICIAL (v2.4.6 Fix): Disparar localización al entrar
    _getCurrentLocation();

    // 6. TIMER DE REFRESCO (v2.4.9): Actualizar "hace x min" en tiempo real cada 30s
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (mounted) setState(() {});
    });
  }

  void _subscribeToAlerts() {
    _alertsSubscription = _apiService.streamAlertas().listen((zones) {
      if (mounted) {
        setState(() {
          _activeDangerZones = zones;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarController.dispose();
    _alertsSubscription?.cancel();
    _positionStream?.cancel();
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMapData();
      _getCurrentLocation();
    }
  }

  // El método _loadMapData ya no es necesario para el refresco periódico.
  // Pero se mantiene vacío o se elimina si no hay otras referencias.
  Future<void> _loadMapData() async {}

  void _initMovementScan() {
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 500, // Re-escanear cada 500 metros
      ),
    ).listen((Position pos) {
      if (mounted) {
        debugPrint("🚀 ARGOS SCAN: Se detectó movimiento, re-escaneando...");
        _scanRealSanctuaries(LatLng(pos.latitude, pos.longitude));
      }
    });
  }

  Future<void> _getCurrentLocation() async {
    try {
      // 1. Verificar disponibilidad de servicios
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        _finishLoading();
        return;
      }

      // 2. Revisar/Pedir Permisos
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        _finishLoading();
        return;
      }

      // 3. ESTRATEGIA DE CARGA RÁPIDA (v2.4.5): Usar última ubicación conocida primero
      final Position? lastPosition = await Geolocator.getLastKnownPosition();
      if (lastPosition != null && mounted) {
        _updateMapPosition(lastPosition);
        _finishLoading();

        // v2.9.3: Escaneo inicial
        _scanRealSanctuaries(
            LatLng(lastPosition.latitude, lastPosition.longitude));
      }

      // 4. Obtener ubicación precisa
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 5),
        ),
      );

      if (mounted) {
        _updateMapPosition(position);
        _scanRealSanctuaries(LatLng(position.latitude, position.longitude));
      }
    } catch (e) {
      debugPrint("Error GPS (Optimizado): $e");
    } finally {
      _finishLoading();
    }
  }

  Future<void> _scanRealSanctuaries(LatLng pos) async {
    // 1. Evitar escaneos simultáneos
    if (_isScanningSanctuaries) return;

    // 2. Lógica de Redundancia (v2.10.0)
    // Si ya escaneamos en esta posición (o muy cerca, < 100m manual, < 500m auto), ignoramos.
    if (_lastScannedPosition != null) {
      const Distance distance = Distance();
      final double meters =
          distance.as(LengthUnit.Meter, pos, _lastScannedPosition!);
      // Si la distancia es mínima, no gastamos recursos
      if (meters < 100) {
        debugPrint(
            "ℹ️ ARGOS SCAN: Posición similar detectada (${meters.toStringAsFixed(0)}m), saltando escaneo.");
        return;
      }
    }

    setState(() => _isScanningSanctuaries = true);
    // NOTA: v2.10.0 - Ya NO limpiamos _dynamicSanctuaries aquí para que los puntos no desaparezcan

    try {
      final results = await _apiService.obtenerSantuariosReales(pos);
      if (mounted) {
        setState(() {
          _dynamicSanctuaries = results;
          _isScanningSanctuaries = false;
          _lastScannedPosition = pos; // Guardar última posición exitosa
        });
      }
    } catch (e) {
      debugPrint("Error escaneando santuarios: $e");
      if (mounted) setState(() => _isScanningSanctuaries = false);
    }
  }

  void _updateMapPosition(Position position) {
    setState(() {
      _currentCenter = LatLng(position.latitude, position.longitude);
    });
    try {
      // v2.8.7: Zoom más agresivo (17.0) para "acercar a mi ubicación"
      _mapController.move(_currentCenter, 17.0);
    } catch (_) {}
  }

  void _finishLoading() {
    if (mounted && _isLoadingLocation) {
      setState(() => _isLoadingLocation = false);
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) setState(() => _showHud = true);
      });
    }
  }

  // --- LOGICA DE CLICKS EN EL MAPA ---
  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    // 1. Prioridad a Zonas de Peligro
    if (_activeFilters.contains('Peligro')) {
      const Distance distance = Distance();
      for (var zone in _activeDangerZones) {
        if (distance.as(LengthUnit.Meter, point, zone.center) <= zone.radius) {
          _showZoneDetails(zone);
          return;
        }
      }
    }

    // 2. Si no tocó peligro, verificar Santuarios (Cercanía de 30m)
    // El toque directo ya es manejado por el GestureDetector en el marcador (v2.12.1)
  }

  void _showSanctuaryDetails(SanctuaryModel site) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final panelColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return GlassBox(
          borderRadius: 25,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: panelColor.withValues(alpha: 0.9),
              borderRadius:
                  const BorderRadius.vertical(top: Radius.circular(25)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    _buildDynamicMarkerIcon(site),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            site.name.toUpperCase(),
                            style: TextStyle(
                              color: isDark ? Colors.white : Colors.black87,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            site.address?.isNotEmpty == true
                                ? site.address!
                                : "DIRECCIÓN: UBICACIÓN DETECTADA POR ARGOS",
                            style: TextStyle(
                              color: isDark ? Colors.white70 : Colors.black54,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      // v2.12.1: Zoom e Ir al punto
                      _mapController.move(site.location, 17.5);
                    },
                    icon: const Icon(Icons.near_me_outlined),
                    label: const Text("IR AL PUNTO / ACERCAR"),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showZoneDetails(DangerZoneModel zone) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white70 : Colors.black54;
    final panelColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return GlassBox(
          borderRadius: 30,
          opacity: isDark ? 0.1 : 0.05,
          blur: 20,
          child: Container(
            padding: const EdgeInsets.all(20),
            height: MediaQuery.of(context).size.height * 0.5,
            decoration: BoxDecoration(
              color: panelColor.withValues(alpha: 0.95),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(30),
              ),
              border: Border.all(
                  color: Colors.red.withValues(alpha: isDark ? 0.3 : 0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.redAccent,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "HISTORIAL DE RIESGO",
                      style: TextStyle(
                        color: isDark
                            ? const Color(0xFFFFCDD2)
                            : Colors.red.shade900,
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close,
                          color: isDark ? Colors.white54 : Colors.black54),
                    ),
                  ],
                ),
                Divider(color: isDark ? Colors.white24 : Colors.black12),
                const SizedBox(height: 10),
                Text(
                  "${zone.reports.length} reportes registrados aquí:",
                  style: TextStyle(color: secondaryTextColor),
                ),
                const SizedBox(height: 10),
                Expanded(
                  child: ListView.builder(
                    itemCount: zone.reports.length,
                    physics: const BouncingScrollPhysics(),
                    itemBuilder: (context, index) {
                      final report = zone.reports[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white.withValues(alpha: 0.05)
                              : Colors.black.withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(
                              color: isDark ? Colors.white10 : Colors.black12),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              report.icon,
                              color: Colors.redAccent,
                              size: 20,
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    report.title,
                                    style: TextStyle(
                                      color: textColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  Text(
                                    report.description,
                                    style: TextStyle(
                                      color: secondaryTextColor,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              _apiService.calcularTiempoTranscurrido(
                                  report.timestamp.toIso8601String()),
                              style: TextStyle(
                                color: isDark ? Colors.white38 : Colors.black38,
                                fontSize: 10,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    super.build(context);
    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF1A1A1A) : const Color(0xFFF8FAFC),
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(
            bottom: 110.0), // v2.7.0: Más alto para evitar el nav bar
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FloatingActionButton(
              heroTag: "btnFamily",
              mini: true,
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (c) => const FamilyCircleScreen()),
              ),
              backgroundColor: Colors.blueAccent,
              child: const Icon(Icons.group_add, color: Colors.white, size: 20),
            ),
            const SizedBox(height: 10),
            FloatingActionButton(
              heroTag: "btnCenter",
              mini: true,
              onPressed: _getCurrentLocation, // Centra y actualiza GPS
              backgroundColor: const Color(0xFFE53935),
              child: const Icon(Icons.my_location, color: Colors.white),
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          if (_isLoadingLocation) _buildLoadingRadar() else _buildMap(),
          _buildFilterBar(),

          // Indicador de escaneo dinámico (v2.8.8)
          if (_isScanningSanctuaries)
            Positioned(
              top: 115,
              right: 20,
              child: _buildScanningIndicator(),
            ),
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
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.blueAccent.withValues(alpha: 0.3),
                  width: 1,
                ),
                gradient: SweepGradient(
                  center: Alignment.center,
                  colors: [
                    Colors.transparent,
                    Colors.blueAccent.withValues(alpha: 0.5),
                  ],
                ),
              ),
              child: const Icon(
                Icons.satellite_alt,
                color: Colors.blue,
                size: 30,
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            "SINTONIZANDO RED ARGOS...",
            style: TextStyle(
              color: Colors.blueAccent,
              fontSize: 10,
              letterSpacing: 2,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMap() {
    return FlutterMap(
      mapController: _mapController,
      options: MapOptions(
        initialCenter: _currentCenter,
        initialZoom: 15.0,
        minZoom: 10.0,
        maxZoom: 18.0,
        backgroundColor: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF1A1A1A)
            : const Color(0xFFF8FAFC),
        onTap: _handleMapTap,
      ),
      children: [
        TileLayer(
          urlTemplate: Theme.of(context).brightness == Brightness.dark
              ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
              : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png',
          userAgentPackageName: 'com.argos.mobile_app',
          subdomains: const ['a', 'b', 'c', 'd'],
          tileDisplay: const TileDisplay.fadeIn(
            duration: Duration(milliseconds: 600),
          ),
        ),

        // Capa de Zonas de Peligro (Nube)
        if (_activeFilters.contains('Peligro'))
          CircleLayer(
            circles: _activeDangerZones.map((zone) {
              return CircleMarker(
                point: zone.center,
                radius: zone.radius,
                useRadiusInMeter: true,
                color: Colors.red.withValues(alpha: 0.15),
                borderColor: Colors.red.withValues(alpha: 0.5),
                borderStrokeWidth: 1.5,
              );
            }).toList(),
          ),

        // Capa de Marcadores con Clustering (Optimización)
        MarkerClusterLayerWidget(
          options: MarkerClusterLayerOptions(
            maxClusterRadius: 120,
            size: const Size(40, 40),
            alignment: Alignment.center,
            padding: const EdgeInsets.all(50),
            maxZoom: 15,
            markers: [
              // Santuarios dinámicos filtrables (v2.8.8)
              ..._dynamicSanctuaries
                  .where((s) => _activeFilters.contains(_getFilterName(s.type)))
                  .map(
                    (site) => Marker(
                      point: site.location,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showSanctuaryDetails(site),
                        child: _buildDynamicMarkerIcon(site),
                      ),
                    ),
                  ),

              // Santuarios Legacy (Opcional: Si quieres mantener los fijos de Riobamba como respaldo)
              ...kSanctuariesDB
                  .where((s) => !_dynamicSanctuaries
                      .any((ds) => ds.name == s.name)) // Evitar duplicados
                  .where((s) => _activeFilters.contains(_getFilterName(s.type)))
                  .map(
                    (site) => Marker(
                      point: site.location,
                      width: 50,
                      height: 50,
                      child: GestureDetector(
                        onTap: () => _showSanctuaryDetails(site),
                        child: _buildDynamicMarkerIcon(site),
                      ),
                    ),
                  ),
            ],
            builder: (context, markers) {
              return Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  color: Colors.blue,
                ),
                child: Center(
                  child: Text(
                    markers.length.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              );
            },
          ),
        ),

        // 🟢 MI POSICIÓN (Fuera del cluster v2.6.1)
        MarkerLayer(
          markers: [
            Marker(
              point: _currentCenter,
              width: 60,
              height: 60,
              child: _buildMyPositionMarker(),
            ),
          ],
        ),
      ],
    );
  }

  // --- BARRA DE FILTROS EN CAPSULAS ---
  Widget _buildFilterBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final filters = [
      {'id': 'Peligro', 'icon': Icons.warning, 'color': Colors.red},
      {
        'id': 'Policía',
        'icon': Icons.local_police,
        'color': Colors.greenAccent,
      },
      {
        'id': 'Salud',
        'icon': Icons.local_hospital,
        'color': Colors.blue,
      },
      {
        'id': 'Farmacia',
        'icon': Icons.local_pharmacy,
        'color': Colors.pinkAccent,
      },
      {'id': 'Tienda', 'icon': Icons.store, 'color': Colors.purpleAccent},
      {'id': 'Educación', 'icon': Icons.school, 'color': Colors.orange},
      {
        'id': 'Parque',
        'icon': Icons.park,
        'color': Colors.tealAccent,
      }, // Icono árbol
      {'id': 'Iglesia', 'icon': Icons.church, 'color': Colors.amber},
    ];

    return Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: AnimatedOpacity(
          opacity: _showHud ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 800),
          child: SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filters.length,
              itemBuilder: (context, index) {
                final item = filters[index];
                final String id = item['id'] as String;
                final bool isActive = _activeFilters.contains(id);
                final Color baseColor = item['color'] as Color;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      if (isActive) {
                        _activeFilters.remove(id);
                      } else {
                        _activeFilters.add(id);
                      }
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    margin: const EdgeInsets.only(right: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isActive
                          ? baseColor.withValues(alpha: isDark ? 0.2 : 0.15)
                          : (isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.9)),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isActive
                            ? baseColor
                            : (isDark ? Colors.white10 : Colors.black12),
                        width: isActive ? 1.5 : 1,
                      ),
                      boxShadow: isActive || !isDark
                          ? [
                              BoxShadow(
                                color: isActive
                                    ? baseColor.withValues(alpha: 0.3)
                                    : Colors.black.withValues(alpha: 0.05),
                                blurRadius: isActive ? 8 : 4,
                                spreadRadius: isActive ? 1 : 0,
                              ),
                            ]
                          : [],
                    ),
                    child: Row(
                      children: [
                        Icon(
                          item['icon'] as IconData,
                          size: 16,
                          color: isActive
                              ? baseColor
                              : (isDark ? Colors.white54 : Colors.black45),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          id,
                          style: TextStyle(
                            color: isActive
                                ? (isDark ? Colors.white : baseColor)
                                : (isDark ? Colors.white54 : Colors.black45),
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScanningIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.blueAccent.withValues(alpha: 0.3),
            blurRadius: 10,
          )
        ],
      ),
      child: const Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              color: Colors.white,
              strokeWidth: 2,
            ),
          ),
          SizedBox(width: 8),
          Text(
            "ESCANEANDO...",
            style: TextStyle(
              color: Colors.white,
              fontSize: 9,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGETS AUXILIARES ---

  String _getFilterName(SanctuaryType type) {
    switch (type) {
      case SanctuaryType.police:
        return 'Policía';
      case SanctuaryType.health:
        return 'Salud';
      case SanctuaryType.pharmacy:
        return 'Farmacia';
      case SanctuaryType.education:
        return 'Educación';
      case SanctuaryType.store:
        return 'Tienda';
      case SanctuaryType.park:
        return 'Parque';
      case SanctuaryType.church:
        return 'Iglesia';
    }
  }

  Widget _buildDynamicMarkerIcon(SanctuaryModel site) {
    IconData icon;
    Color color;
    switch (site.type) {
      case SanctuaryType.police:
        icon = Icons.local_police;
        color = Colors.greenAccent;
        break;
      case SanctuaryType.health:
        icon = Icons.local_hospital;
        color = Colors.blue;
        break;
      case SanctuaryType.education:
        icon = Icons.school;
        color = Colors.orange;
        break;
      case SanctuaryType.store:
        icon = Icons.store;
        color = Colors.purpleAccent;
        break;
      case SanctuaryType.park:
        icon = Icons.park;
        color = Colors.tealAccent;
        break;
      case SanctuaryType.pharmacy:
        icon = Icons.local_pharmacy;
        color = Colors.pinkAccent;
        break;
      case SanctuaryType.church:
        icon = Icons.church;
        color = Colors.amber;
        break;
    }
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF262626).withValues(alpha: 0.9)
            : Colors.white.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 1.5),
      ),
      child: Icon(icon, color: color, size: 16),
    );
  }

  Widget _buildMyPositionMarker() {
    return Center(
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: Colors.blue,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2),
          boxShadow: [
            BoxShadow(
              color: Colors.blue.withValues(alpha: 0.5),
              blurRadius: 6,
              spreadRadius: 2,
            ),
          ],
        ),
      ),
    );
  }
}
