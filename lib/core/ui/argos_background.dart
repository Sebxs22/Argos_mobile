import 'dart:ui';
import 'package:flutter/material.dart';

class ArgosBackground extends StatelessWidget {
  final Widget child;
  const ArgosBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Colores adaptativos para las auroras
    final Color redAurora = const Color(0xFFE53935);
    final Color blueAurora = const Color(0xFF2962FF);

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF030308) : const Color(0xFFF1F5F9),
      body: Stack(
        children: [
          // Auroras Background
          Positioned(
            top: -120,
            left: -120,
            child: Container(
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: redAurora.withValues(alpha: isDark ? 0.12 : 0.05),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            right: -80,
            child: Container(
              width: 350,
              height: 350,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blueAurora.withValues(alpha: isDark ? 0.08 : 0.03),
              ),
            ),
          ),
          // Blur Layer
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 60, sigmaY: 60),
            child: Container(color: Colors.transparent),
          ),
          // Content
          child,
        ],
      ),
    );
  }
}
