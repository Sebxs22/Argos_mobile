import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// --- NUEVAS PANTALLAS Y SERVICIOS ---
import 'features/eye_guardian/ui/eye_guardian_screen.dart';
import 'features/routes/ui/routes_screen.dart';
import 'features/sanctuaries/ui/sanctuaries_map_screen.dart';
import 'features/auth/ui/login_screen.dart'; // Asegúrate de crear este archivo
import 'features/auth/ui/register_screen.dart';
import 'core/network/auth_service.dart';
import 'core/ui/glass_box.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // --- INICIALIZACIÓN DE LA NUBE ---
  await Supabase.initialize(
    url: 'https://qfmhruseaxfnudvgmhto.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InFmbWhydXNlYXhmbnVkdmdtaHRvIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzA0MTQyOTEsImV4cCI6MjA4NTk5MDI5MX0.APn0xT7r1kPM3j2ZYl3gRABiyX-1jWS9lzz9tsKO48s',
  );

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));

  runApp(const ArgosApp());
}

class ArgosApp extends StatelessWidget {
  const ArgosApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Verificamos si hay una sesión activa en Supabase
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      title: 'ARGOS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: const Color(0xFF050511),
        primaryColor: const Color(0xFFE53935),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      // LÓGICA DE ENTRADA: Si hay sesión va al Navigator, si no al Login
      home: session != null ? const MainNavigator() : const LoginScreen(),
    );
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
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.95),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text("Perfil de Usuario", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const CircleAvatar(backgroundColor: Colors.blue, child: Icon(Icons.person, color: Colors.white)),
              title: Text(_perfilData?['nombre_completo'] ?? "Cargando...", style: const TextStyle(color: Colors.white)),
              subtitle: Text("Código: ${_perfilData?['codigo_familia'] ?? '...'}", style: const TextStyle(color: Colors.white54, fontSize: 12)),
            ),
            const Divider(color: Colors.white10),
            ListTile(
              onTap: () {
                // Aquí podrías navegar a la pantalla de Círculo Familiar
                Navigator.pop(context);
              },
              leading: const Icon(Icons.group, color: Colors.greenAccent),
              title: const Text("Círculo Familiar", style: TextStyle(color: Colors.white70, fontSize: 14)),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cerrar", style: TextStyle(color: Colors.grey))),
          ElevatedButton.icon(
            onPressed: () async {
              await _auth.cerrarSesion();
              if (mounted) Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (c) => const LoginScreen()), (route) => false);
            },
            icon: const Icon(Icons.logout, size: 18),
            label: const Text("Cerrar Sesión"),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900, foregroundColor: Colors.white),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool isGuardianScreen = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF050511),
      extendBodyBehindAppBar: true,
      extendBody: true,
      appBar: isGuardianScreen ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 20.0, top: 10.0),
            child: GestureDetector(
              onTap: _showProfileMenu,
              child: Container(
                width: 40, height: 40,
                decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.05), border: Border.all(color: Colors.white12)),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
              ),
            ),
          )
        ],
      ) : null,

      body: Stack(
        children: [
          if (_selectedIndex != 1)
            RepaintBoundary(
              child: Stack(
                children: [
                  Positioned(top: -100, left: -100, child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFFE53935).withOpacity(0.25)))),
                  Positioned(bottom: -100, right: -100, child: Container(width: 350, height: 350, decoration: BoxDecoration(shape: BoxShape.circle, color: const Color(0xFF2962FF).withOpacity(0.15)))),
                  BackdropFilter(filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50), child: Container(color: Colors.transparent)),
                ],
              ),
            ),
          AnimatedPadding(
            duration: const Duration(milliseconds: 300),
            padding: EdgeInsets.only(top: isGuardianScreen ? 80 : 0),
            child: PageView(
              controller: _pageController,
              onPageChanged: _onPageChanged,
              physics: const BouncingScrollPhysics(),
              children: _pages,
            ),
          ),
        ],
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(25, 0, 25, 30),
        child: GlassBox(
          borderRadius: 40, blur: 15, opacity: 0.1,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildNavItem(0, Icons.remove_red_eye_outlined, Icons.remove_red_eye, "Guardián"),
              _buildNavItem(1, Icons.shield_outlined, Icons.shield, "Santuarios"),
              _buildNavItem(2, Icons.map_outlined, Icons.map, "Rutas"),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData iconOff, IconData iconOn, String label) {
    bool isSelected = _selectedIndex == index;
    return GestureDetector(
      onTap: () => _onItemTapped(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: isSelected ? BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(20)) : null,
        child: Row(
          children: [
            Icon(isSelected ? iconOn : iconOff, color: isSelected ? const Color(0xFFFF5252) : Colors.white60, size: 24),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
            ]
          ],
        ),
      ),
    );
  }
}