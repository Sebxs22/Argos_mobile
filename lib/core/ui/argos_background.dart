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
          isDark ? const Color(0xFF050511) : const Color(0xFFF8FAFC),
      body: Stack(
        children: [
          // Auroras Background
          Positioned(
            top: -100,
            left: -100,
            child: Container(
              width: 400,
              height: 400,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: redAurora.withValues(alpha: isDark ? 0.15 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: blueAurora.withValues(alpha: isDark ? 0.1 : 0.05),
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
