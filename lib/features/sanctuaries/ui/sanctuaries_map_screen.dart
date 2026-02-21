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
  Timer? _autoRefreshTimer;

  // Lista de zonas de peligro de Supabase
  List<DangerZoneModel> _activeDangerZones = [];

  // Filtros activos (Todos por defecto)
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

    _radarController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // 1. Carga de datos de la nube
    _loadMapData();

    // 2. Actualización automática cada 5 segundos
    _startAutoRefresh();

    // 3. Obtener ubicación GPS
    _getCurrentLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _radarController.dispose();
    _autoRefreshTimer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _loadMapData();
      _getCurrentLocation();
    }
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _loadMapData();
    });
  }

  Future<void> _loadMapData() async {
    try {
      // ApiService ya gestiona la agrupación inteligente y el tiempo real
      List<DangerZoneModel> realAlerts = await _apiService.obtenerAlertas();
      if (mounted) {
        setState(() {
          _activeDangerZones = realAlerts;
        });
      }
    } catch (e) {
      debugPrint("Error recargando alertas: $e");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) return;

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
          ),
        );

        if (mounted) {
          setState(
            () =>
                _currentCenter = LatLng(position.latitude, position.longitude),
          );

          // Movemos el mapa con seguridad (evitando LateInitializationError)
          try {
            _mapController.move(_currentCenter, 16.0);
          } catch (e) {
            debugPrint(
              "MapController no listo, moviendo en el siguiente frame.",
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Error GPS: $e");
    } finally {
      // Siempre finalizamos la carga para que el radar desaparezca
      _finishLoading();
    }
  }

  void _finishLoading() {
    if (mounted && _isLoadingLocation) {
      setState(() => _isLoadingLocation = false);
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) setState(() => _showHud = true);
      });
    }
  }

  // --- LOGICA DE CLICKS EN EL MAPA ---
  void _handleMapTap(TapPosition tapPosition, LatLng point) {
    if (!_activeFilters.contains('Peligro')) return;

    const Distance distance = Distance();
    for (var zone in _activeDangerZones) {
      if (distance.as(LengthUnit.Meter, point, zone.center) <= zone.radius) {
        _showZoneDetails(zone);
        return;
      }
    }
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
                            const Icon(
                              Icons
                                  .warning_amber, // Simplificamos el acceso al icono si report.icon falla
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
                              report.timeAgo,
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
        padding: const EdgeInsets.only(bottom: 90.0),
        child: FloatingActionButton(
          heroTag: "btnCenter",
          mini: true,
          onPressed: _getCurrentLocation, // Centra y actualiza GPS
          backgroundColor: const Color(0xFFE53935),
          child: const Icon(Icons.my_location, color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          if (_isLoadingLocation) _buildLoadingRadar() else _buildMap(),
          _buildFilterBar(),
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
              // Mi Posición (No se agrupa o se agrupa con otros, depende de preferencia. Aquí lo incluimos)
              Marker(
                point: _currentCenter,
                width: 60,
                height: 60,
                child: _buildMyPositionMarker(),
              ),

              // Santuarios filtrables
              ...kSanctuariesDB
                  .where((s) => _activeFilters.contains(_getFilterName(s.type)))
                  .map(
                    (site) => Marker(
                      point: site.location,
                      width: 50,
                      height: 50,
                      child: _buildDynamicMarkerIcon(site),
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
      {'id': 'Salud', 'icon': Icons.local_hospital, 'color': Colors.blue},
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
                          ? baseColor.withValues(alpha: isDark ? 0.2 : 0.1)
                          : (isDark
                              ? Colors.black.withValues(alpha: 0.4)
                              : Colors.white.withValues(alpha: 0.8)),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isActive
                            ? baseColor
                            : (isDark ? Colors.white10 : Colors.black12),
                      ),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color: baseColor.withValues(alpha: 0.3),
                                blurRadius: 8,
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
