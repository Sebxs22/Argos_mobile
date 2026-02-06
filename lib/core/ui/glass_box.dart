import 'dart:ui';
import 'package:flutter/material.dart';

class GlassBox extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry? padding;
  final BoxBorder? border; // Agregamos opción de borde personalizado

  const GlassBox({
    super.key,
    required this.child,
    this.borderRadius = 25.0,
    this.blur = 20.0, // Bajamos un poco el blur default para ganar FPS
    this.opacity = 0.08,
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    // Usamos ClipRRect para recortar el efecto costoso solo al área necesaria
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        // Optimizamos el filtro
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(borderRadius),
            border: border ?? Border.all(
              color: Colors.white.withOpacity(0.2),
              width: 1.0,
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}