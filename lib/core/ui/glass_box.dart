import 'dart:ui';
import 'package:flutter/material.dart';
import '../utils/ui_tokens.dart'; // v2.14.9

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
    this.blur = 25.0, // v2.7.0: Blur más profundo para look premium
    this.opacity = 0.1, // v2.7.0: Opacidad base estandarizada
    this.padding,
    this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : Colors.black12)
                .withValues(alpha: 0.05),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding ?? const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  isDark
                      ? Colors.white.withValues(alpha: opacity)
                      : Colors.white.withValues(alpha: 0.1),
                  isDark
                      ? Colors.white.withValues(alpha: opacity * 0.5)
                      : Colors.white.withValues(alpha: 0.02),
                ],
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              border: border ??
                  Border.all(
                    color:
                        UiTokens.glassBorder(context), // v2.14.9: Centralizado
                    width: 0.8,
                  ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
