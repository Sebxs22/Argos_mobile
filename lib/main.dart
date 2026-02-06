import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'features/eye_guardian/ui/eye_guardian_screen.dart';
// IMPORTANTE: Asegúrate de importar tu nueva pantalla de mapa
import 'features/sanctuaries/ui/sanctuaries_map_screen.dart';
import 'core/ui/glass_box.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Barra de estado 100% transparente
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
      home: const MainNavigator(),
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

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // LISTA DE PÁGINAS
  final List<Widget> _pages = const [
    EyeGuardianScreen(), // Índice 0
    SanctuariesMapScreen(), // Índice 1 (Tu nuevo mapa táctico)
    Center(child: Text("Rutas (En construcción)", style: TextStyle(color: Colors.white))), // Índice 2
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      // CAMBIO: Usamos jumpToPage en lugar de animateToPage
      // Esto hace el cambio instantáneo sin pasar por las pantallas del medio
      _pageController.jumpToPage(index);
    });
  }

  void _onPageChanged(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  void _showProfileMenu() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A).withOpacity(0.9),
        title: const Text("Perfil de Usuario", style: TextStyle(color: Colors.white)),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(Icons.person, color: Colors.blue),
              title: Text("Luis Shagñay", style: TextStyle(color: Colors.white)),
              subtitle: Text("Plan Gratuito", style: TextStyle(color: Colors.grey)),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cerrar", style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Cerrando sesión...")),
              );
            },
            icon: const Icon(Icons.logout),
            label: const Text("Cerrar Sesión"),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade900,
              foregroundColor: Colors.white,
            ),
          )
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Variable para saber si estamos en el Guardián (índice 0)
    bool isGuardianScreen = _selectedIndex == 0;

    return Scaffold(
      backgroundColor: const Color(0xFF050511),
      extendBodyBehindAppBar: true,
      extendBody: true,

      // APP BAR CONDICIONAL: Solo aparece en la pantalla 0 (Guardián)
      appBar: isGuardianScreen ? AppBar(
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
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.05),
                  border: Border.all(color: Colors.white12),
                ),
                child: const Icon(Icons.person_outline, color: Colors.white, size: 20),
              ),
            ),
          )
        ],
      ) : null, // Si no es el Guardián, no mostramos AppBar

      body: Stack(
        children: [
          // --- CAPA 1: FONDO AURORA ---
          // Solo mostramos la Aurora si NO estamos en el Mapa (índice 1)
          // Esto ahorra batería y recursos gráficos
          if (_selectedIndex != 1)
            RepaintBoundary(
              child: Stack(
                children: [
                  Positioned(
                    top: -100, left: -100,
                    child: Container(
                      width: 350, height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFE53935).withOpacity(0.25),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: -100, right: -100,
                    child: Container(
                      width: 350, height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFF2962FF).withOpacity(0.15),
                      ),
                    ),
                  ),
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 50, sigmaY: 50),
                    child: Container(color: Colors.transparent),
                  ),
                ],
              ),
            ),

          // --- CAPA 2: CONTENIDO PRINCIPAL ---
          // Usamos AnimatedContainer para ajustar el padding superior suavemente
          // Si hay AppBar (Guardián), bajamos 80px. Si no (Mapa), subimos a 0px.
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

      // --- CAPA 3: BARRA INFERIOR FLOTANTE ---
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.fromLTRB(25, 0, 25, 30),
        child: GlassBox(
          borderRadius: 40,
          blur: 15,
          opacity: 0.1,
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
        decoration: isSelected
            ? BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20))
            : null,
        child: Row(
          children: [
            Icon(
              isSelected ? iconOn : iconOff,
              color: isSelected ? const Color(0xFFFF5252) : Colors.white60,
              size: 24,
            ),
            if (isSelected) ...[
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              ),
            ]
          ],
        ),
      ),
    );
  }
}