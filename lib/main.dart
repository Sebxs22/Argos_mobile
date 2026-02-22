import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // Import OneSignal
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:overlay_support/overlay_support.dart'; // Import OverlaySupport
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:flutter_background_service/flutter_background_service.dart'; // Background Service

// --- NUEVAS PANTALLAS Y SERVICIOS ---
import 'package:permission_handler/permission_handler.dart'; // Permissions
import 'features/eye_guardian/ui/eye_guardian_screen.dart';
import 'features/routes/ui/routes_screen.dart';
import 'features/sanctuaries/ui/sanctuaries_map_screen.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/eye_guardian/ui/alert_confirmation_screen.dart'; // AlertConfirmation
import 'core/network/auth_service.dart';
import 'core/ui/glass_box.dart';
import 'core/utils/connectivity_service.dart'; // Import connectivity service
import 'features/eye_guardian/logic/background_service.dart'; // Import REAL background service
import 'features/family_circle/ui/family_circle_screen.dart'; // Import Family Circle Screen
import 'core/network/version_service.dart'; // Import VersionService
import 'core/ui/argos_background.dart'; // Import ArgosBackground
import 'core/theme/theme_service.dart'; // Import ThemeService
import 'features/profile/ui/settings_screen.dart'; // Import SettingsScreen
import 'core/ui/connectivity_badge.dart'; // Import ConnectivityBadge
import 'core/network/api_service.dart'; // Import ApiService

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load environment variables
  await dotenv.load(fileName: ".env");

  // --- INICIALIZACIÓN DE LA NUBE ---
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
    ),
  );

  // Initialize connectivity monitoring
  ConnectivityService().initialize();

  // Initialize Background Service
  // Use the one from features/eye_guardian
  final backgroundServiceManager = BackgroundServiceManager();
  await backgroundServiceManager.initializeService();

  // Initialize OneSignal
  OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
  OneSignal.initialize(dotenv.env['ONESIGNAL_APP_ID']!);
  OneSignal.Notifications.requestPermission(true);

  // Initialize Theme Service
  await ThemeService().init();

  runApp(const ArgosApp());
}

class ArgosApp extends StatelessWidget {
  const ArgosApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Verificamos si hay una sesión activa en Supabase
    final session = Supabase.instance.client.auth.currentSession;

    return OverlaySupport.global(
      child: ValueListenableBuilder<ThemeMode>(
        valueListenable: ThemeService().themeNotifier,
        builder: (context, currentMode, _) {
          return MaterialApp(
            title: 'ARGOS',
            navigatorKey: navigatorKey,
            debugShowCheckedModeBanner: false,
            themeMode: currentMode,
            // MODO CLARO
            theme: ThemeData(
              brightness: Brightness.light,
              scaffoldBackgroundColor: const Color(0xFFF8FAFC),
              primaryColor: const Color(0xFFE53935),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            // MODO OSCURO
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF050511),
              primaryColor: const Color(0xFFE53935),
              useMaterial3: true,
              fontFamily: 'Roboto',
            ),
            home: InitialCheckWrapper(
              child:
                  session != null ? const MainNavigator() : const LoginScreen(),
            ),
          );
        },
      ),
    );
  }
}

class InitialCheckWrapper extends StatefulWidget {
  final Widget child;
  const InitialCheckWrapper({super.key, required this.child});

  @override
  State<InitialCheckWrapper> createState() => _InitialCheckWrapperState();
}

class _InitialCheckWrapperState extends State<InitialCheckWrapper> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Verificar Versión
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService().checkForUpdates(context);
    });

    // 2. Pedir Permisos Críticos (Efecto Life360)
    await _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    // Solicitar Ubicación (Siempre) + Notificaciones
    Map<Permission, PermissionStatus> statuses = await [
      Permission.locationAlways,
      Permission.notification,
    ].request();

    // Si nos niegan el "Always", pedimos al menos el "WhileInUse"
    if (statuses[Permission.locationAlways]?.isDenied ?? true) {
      await Permission.location.request();
    }

    // IGNORAR OPTIMIZACIONES DE BATERÍA (Android Crítico)
    if (await Permission.ignoreBatteryOptimizations.isDenied) {
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

class MainNavigator extends StatefulWidget {
  const MainNavigator({super.key});

  @override
  State<MainNavigator> createState() => _MainNavigatorState();
}

class _MainNavigatorState extends State<MainNavigator> {
  int _selectedIndex = 0;
  late PageController _pageController;
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _perfilData;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _cargarPerfil();
    _listenToBackgroundGlobal();
    _startLocationServices(); // Iniciar servicios de rastreo
  }

  void _listenToBackgroundGlobal() {
    FlutterBackgroundService().on('onShake').listen((event) {
      final String? alertaId = event?['alertaId'];

      // Navegación Global Usando navigatorKey (Omnipresencial)
      navigatorKey.currentState?.push(
        MaterialPageRoute(
          builder: (context) => AlertConfirmationScreen(alertaId: alertaId),
        ),
      );
    });
  }

  Future<void> _startLocationServices() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        // Enviar ubicación de inmediato al inicio para evitar el mensaje de "No compartido"
        Position pos = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.medium));
        final ApiService api = ApiService();
        await api.actualizarUbicacion(pos.latitude, pos.longitude);

        // Iniciar servicio de fondo
        BackgroundServiceManager().start();
      }
    } catch (e) {
      debugPrint("Error iniciando servicios de ubicación: $e");
    }
  }

  Future<void> _cargarPerfil() async {
    final data = await _auth.obtenerMiPerfil();
    if (mounted) setState(() => _perfilData = data);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  final List<Widget> _pages = const [
    EyeGuardianScreen(),
    SanctuariesMapScreen(),
    RoutesScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      _pageController.jumpToPage(index);
    });
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showProfileMenu() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final secondaryTextColor = isDark ? Colors.white54 : Colors.black54;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: isDark
            ? const Color(0xFF0F172A).withValues(alpha: 0.95)
            : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          "Perfil de Usuario",
          style: TextStyle(
            color: textColor,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(
                backgroundColor: Colors.blue,
                child: Icon(Icons.person, color: Colors.white),
              ),
              title: Text(
                _perfilData?['nombre_completo'] ?? "Cargando...",
                style: TextStyle(color: textColor),
              ),
              subtitle: Text(
                "Código: ${_perfilData?['codigo_familia'] ?? '...'}",
                style: TextStyle(color: secondaryTextColor, fontSize: 12),
              ),
            ),
            Divider(color: isDark ? Colors.white10 : Colors.black12),
            ListTile(
              onTap: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const SettingsScreen()),
                );
              },
              leading: const Icon(Icons.settings, color: Colors.blueAccent),
              title: Text(
                "Configuración y Perfil",
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.7), fontSize: 14),
              ),
            ),
            ListTile(
              onTap: () {
                Navigator.pop(dialogContext);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (c) => const FamilyCircleScreen()),
                );
              },
              leading: const Icon(Icons.group, color: Colors.greenAccent),
              title: Text(
                "Círculo Familiar",
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.7), fontSize: 14),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Cerrar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              await _auth.cerrarSesion();
              if (mounted) {
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (c) => const LoginScreen()),
                  (route) => false,
                );
              }
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text("Cerrar Sesión"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isGuardianScreen = _selectedIndex == 0;

    return ArgosBackground(
      child: Stack(
        children: [
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBodyBehindAppBar: true,
            extendBody: true,
            appBar: isGuardianScreen
                ? AppBar(
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 20.0, top: 10.0),
                        child: GestureDetector(
                          onTap: _showProfileMenu,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.05),
                              border: Border.all(
                                color: Theme.of(context).brightness ==
                                        Brightness.dark
                                    ? Colors.white12
                                    : Colors.black12,
                              ),
                            ),
                            child: Icon(
                              Icons.person_outline,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black87,
                              size: 20,
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : null,
            body: AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              padding: EdgeInsets.only(top: isGuardianScreen ? 80 : 0),
              child: PageView(
                controller: _pageController,
                onPageChanged: _onPageChanged,
                physics: const BouncingScrollPhysics(),
                children: _pages,
              ),
            ),
            bottomNavigationBar: Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 30),
              child: GlassBox(
                borderRadius: 40,
                blur: 15,
                opacity: Theme.of(context).brightness == Brightness.dark
                    ? 0.1
                    : 0.05,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildNavItem(
                      0,
                      Icons.remove_red_eye_outlined,
                      Icons.remove_red_eye,
                      "Guardián",
                    ),
                    _buildNavItem(
                      1,
                      Icons.shield_outlined,
                      Icons.shield,
                      "Santuarios",
                    ),
                    _buildNavItem(2, Icons.map_outlined, Icons.map, "Rutas"),
                  ],
                ),
              ),
            ),
          ),
          // Indicador de conectividad sutil en la parte superior
          const ConnectivityBadge(),
        ],
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData iconOff,
    IconData iconOn,
    String label,
  ) {
    bool isSelected = _selectedIndex == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected
            ? BoxDecoration(
                color: isDark
                    ? Colors.white.withValues(alpha: 0.1)
                    : Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
              )
            : null,
        child: Row(
          children: [
            Icon(
              isSelected ? iconOn : iconOff,
              color: isSelected
                  ? const Color(0xFFFF5252)
                  : (isDark ? Colors.white60 : Colors.black45),
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: isDark ? Colors.white : Colors.black87,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
