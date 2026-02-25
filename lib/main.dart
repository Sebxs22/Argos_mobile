import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart'; // Import OneSignal
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv
import 'package:overlay_support/overlay_support.dart'; // Import OverlaySupport
import 'package:geolocator/geolocator.dart'; // Import Geolocator
import 'package:flutter_background_service/flutter_background_service.dart'; // Background Service
import 'package:shared_preferences/shared_preferences.dart'; // Persistencia Local

// --- NUEVAS PANTALLAS Y SERVICIOS ---
import 'package:permission_handler/permission_handler.dart'; // Permissions
import 'features/eye_guardian/ui/eye_guardian_screen.dart';
import 'features/routes/ui/routes_screen.dart';
import 'features/sanctuaries/ui/sanctuaries_map_screen.dart';
import 'features/auth/ui/login_screen.dart';
import 'features/auth/ui/permission_explanation_screen.dart'; // Import v2.6.5
import 'features/eye_guardian/ui/alert_confirmation_screen.dart'; // AlertConfirmation
import 'core/network/auth_service.dart';
import 'core/ui/glass_box.dart';
import 'core/utils/connectivity_service.dart'; // Import connectivity service
import 'features/eye_guardian/logic/background_service.dart'; // Import REAL background service
import 'features/family_circle/ui/family_circle_screen.dart'; // Import Family Circle Screen
import 'features/family_circle/ui/circle_map_screen.dart'; // Import v2.7.1 Deep Linking
import 'core/network/version_service.dart'; // Import VersionService
import 'core/ui/argos_background.dart'; // Import ArgosBackground
import 'core/theme/theme_service.dart'; // Import ThemeService
import 'features/profile/ui/settings_screen.dart'; // Import SettingsScreen
import 'core/ui/connectivity_badge.dart'; // Import ConnectivityBadge
import 'core/network/api_service.dart'; // Import ApiService
import 'core/utils/ui_tokens.dart'; // v2.15.1

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
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
            ),
            // MODO OSCURO
            darkTheme: ThemeData(
              brightness: Brightness.dark,
              scaffoldBackgroundColor: const Color(0xFF050511),
              primaryColor: const Color(0xFFE53935),
              useMaterial3: true,
              fontFamily: 'Roboto',
              pageTransitionsTheme: const PageTransitionsTheme(
                builders: {
                  TargetPlatform.android: CupertinoPageTransitionsBuilder(),
                  TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
                },
              ),
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
  bool _needsPermissions = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // 1. Verificar Versión (v2.9.1)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      VersionService().checkForUpdates(context);
      VersionService().listenForUpdates(context);
    });

    // 2. Otros Checks (v2.8.2)
    // El check de batería ahora es manual en la pantalla de permisos.

    // 3. Verificar Permisos Críticos (v2.6.5)
    await _checkPermissionsStatus();
  }

  Future<void> _checkPermissionsStatus() async {
    final locationStatus = await Permission.locationAlways.status;
    final notificationStatus = await Permission.notification.status;

    if (!locationStatus.isGranted || !notificationStatus.isGranted) {
      if (mounted) setState(() => _needsPermissions = true);
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const ArgosBackground(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: Center(
            child: CircularProgressIndicator(
              color: Colors.white24,
              strokeWidth: 2,
            ),
          ),
        ),
      );
    }

    if (_needsPermissions) {
      return PermissionExplanationScreen(
        onPermissionsGranted: () {
          setState(() => _needsPermissions = false);
        },
      );
    }

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
  StreamSubscription? _onShakeSubscription; // v2.15.3
  bool _alertBeingShown = false; // v2.15.3: Flag de navegación atómico

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _auth
        .actualizarPushToken(); // Sincronización v2.6.3 (Cada vez que se abre la app)
    _cargarPerfil(); // Cargar datos del perfil
    _listenToBackgroundGlobal();
    _startLocationServices(); // Iniciar servicios de rastreo
    _checkForPendingAlerts(); // Memoria SOS (v2.3.0)
    _setupNotificationListeners(); // v2.7.1 Deep Linking
  }

  void _setupNotificationListeners() {
    OneSignal.Notifications.addClickListener((event) async {
      final data = event.notification.additionalData;
      if (data == null) return;

      final type = data['type'];
      final targetUserId = data['usuario_id'];

      if (type == 'emergency_alert' && targetUserId != null) {
        debugPrint(
            "🚀 ARGOS DEEP-LINK: Notificación de emergencia de $targetUserId");

        // 1. Obtener miembros del círculo antes de navegar
        try {
          final resG = await _auth.obtenerMisGuardianes();
          final resP = await _auth.obtenerAQuienesProtejo();
          final List<Map<String, dynamic>> rawMembers = [...resG, ...resP];

          // v2.8.3: Limpiar duplicados por ID (usuario_id o guardian_id)
          final Map<String, Map<String, dynamic>> uniqueMap = {};
          for (var m in rawMembers) {
            final id =
                (m['id'] ?? m['usuario_id'] ?? m['guardian_id'])?.toString();
            if (id != null) {
              uniqueMap[id] = m;
            }
          }
          final List<Map<String, dynamic>> members = uniqueMap.values.toList();

          if (members.isEmpty) {
            debugPrint("⚠️ ARGOS DEEP-LINK: No se encontraron miembros.");
            return;
          }

          // 2. Navegar al Mapa (v2.7.1)
          navigatorKey.currentState?.push(
            MaterialPageRoute(
              builder: (context) => CircleMapScreen(
                initialMembers: members,
                alertMemberId: targetUserId.toString(),
              ),
            ),
          );
        } catch (e) {
          debugPrint("❌ ARGOS DEEP-LINK Error: $e");
        }
      } else if (type == 'app_update') {
        // v2.8.5: Deep link directo a la actualización
        debugPrint(
            "🚀 ARGOS DEEP-LINK: Notificación de actualización detectada.");
        final context = navigatorKey.currentContext;
        if (context != null) {
          VersionService().checkForUpdates(context, manual: true);
        }
      }
    });
  }

  Future<void> _checkForPendingAlerts() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? alertaId = prefs.getString('pending_alert_id');

    if (alertaId != null && mounted) {
      debugPrint(
          "ARGOS: Detectada alerta pendiente de clasificación: $alertaId");

      // YA NO BORRAMOS AQUÍ (v2.4.7 Fix): Solo se borra al clasificar o cancelar con éxito

      // Pequeño delay para asegurar que el Navigator esté listo
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AlertConfirmationScreen(alertaId: alertaId),
            ),
          );
        }
      });
    }
  }

  void _listenToBackgroundGlobal() {
    _onShakeSubscription?.cancel();
    _onShakeSubscription =
        FlutterBackgroundService().on('onShake').listen((event) {
      final String? alertaId = event?['alertaId'];

      if (!_alertBeingShown) {
        _alertBeingShown = true;
        navigatorKey.currentState
            ?.push(
          PageRouteBuilder(
            settings: const RouteSettings(name: 'AlertConfirmationScreen'),
            pageBuilder: (context, animation, secondaryAnimation) =>
                AlertConfirmationScreen(alertaId: alertaId),
            transitionDuration: const Duration(milliseconds: 500),
            reverseTransitionDuration: const Duration(milliseconds: 400),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
              const begin = 0.5;
              const end = 1.0;
              const curve = Curves.elasticOut;

              var tween =
                  Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
              var scaleAnimation = animation.drive(tween);

              return FadeTransition(
                opacity: animation,
                child: ScaleTransition(
                  scale: scaleAnimation,
                  child: child,
                ),
              );
            },
          ),
        )
            .then((_) {
          _alertBeingShown = false;
        });
      }
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
    _onShakeSubscription?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  final List<Widget> _pages = const [
    EyeGuardianScreen(),
    SanctuariesMapScreen(),
    RoutesScreen(),
  ];

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    // v2.8.4: Navegación silenciosa (Haptic removed)
    setState(() {
      _selectedIndex = index;
      _pageController.animateToPage(
        index,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOutCubic,
      );
    });
  }

  void _onPageChanged(int index) {
    setState(() => _selectedIndex = index);
  }

  void _showProfileMenu() {
    final textColor = UiTokens.textColor(context);
    final secondaryTextColor = UiTokens.secondaryTextColor(context);

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: UiTokens.surface(context),
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
            // Avatar Destacado (v2.12.2 "Bonito")
            Center(
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Colors.blueAccent,
                      Colors.blueAccent.withValues(alpha: 0.3)
                    ],
                  ),
                ),
                child: CircleAvatar(
                  radius: 40,
                  backgroundColor:
                      UiTokens.surface(context).withValues(alpha: 0.5),
                  backgroundImage: _perfilData?['avatar_url'] != null
                      ? NetworkImage(_perfilData!['avatar_url'])
                      : null,
                  child: _perfilData?['avatar_url'] == null
                      ? Icon(Icons.person,
                          size: 40,
                          color: secondaryTextColor.withValues(alpha: 0.5))
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 15),
            Text(
              _perfilData?['nombre_completo'] ?? "Cargando...",
              style: TextStyle(
                  color: textColor, fontWeight: FontWeight.bold, fontSize: 18),
              textAlign: TextAlign.center,
            ),
            Text(
              "ID: ${_perfilData?['codigo_familia'] ?? '...'}",
              style: TextStyle(
                  color: secondaryTextColor, fontSize: 12, letterSpacing: 1.2),
            ),
            const SizedBox(height: 20),
            Divider(color: secondaryTextColor.withValues(alpha: 0.2)),
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
              // v2.15.2: Detener Guardián antes de salir
              BackgroundServiceManager().stop();

              // v2.15.3: Limpiar memoria de SOS para no ver alertas de otros usuarios
              final prefs = await SharedPreferences.getInstance();
              await prefs.remove('pending_alert_id');

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
          ),

          // --- BARRA DE NAVEGACIÓN FLOTANTE (v2.7.0 Premium) ---
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(25, 0, 25, 35),
              child: GlassBox(
                borderRadius: 40,
                // v2.7.0: Usa los nuevos defaults de blur y borde
                padding: const EdgeInsets.symmetric(
                    horizontal: 15, vertical: 12), // v2.8.7: Más espacioso
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNavItem(
                      0,
                      Icons.remove_red_eye_outlined,
                      Icons.remove_red_eye,
                      "Guardián",
                    ),
                    const SizedBox(width: 8),
                    _buildNavItem(
                      1,
                      Icons.shield_outlined,
                      Icons.shield,
                      "Santuarios",
                    ),
                    const SizedBox(width: 8),
                    _buildNavItem(
                      2,
                      Icons.map_outlined,
                      Icons.map,
                      "Rutas",
                    ),
                    const SizedBox(width: 8),
                    // BOTÓN PERFIL INTEGRADO (v2.7.0)
                    _buildProfileNavItem(),
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

  Widget _buildProfileNavItem() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: () {
        HapticFeedback.lightImpact(); // v2.7.0
        _showProfileMenu();
      },
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          shape: BoxShape.circle,
          border: Border.all(
            color: isDark ? Colors.white24 : Colors.black12,
            width: 1,
          ),
        ),
        child: CircleAvatar(
          radius: 14,
          backgroundColor: Colors.transparent,
          backgroundImage: _perfilData?['avatar_url'] != null
              ? NetworkImage(_perfilData!['avatar_url'])
              : null,
          child: _perfilData?['avatar_url'] == null
              ? Icon(
                  Icons.person_outline,
                  color: isDark ? Colors.white70 : Colors.black54,
                  size: 20,
                )
              : null,
        ),
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
              size: 28, // v2.8.7: Iconos más grandes para accesibilidad
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
