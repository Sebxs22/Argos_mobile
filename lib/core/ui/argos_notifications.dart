import 'dart:async';
import 'package:flutter/material.dart';
import 'glass_box.dart';

enum ArgosNotificationType { info, success, warning, error }

class ArgosNotifications {
  static OverlayEntry? _currentEntry;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    ArgosNotificationType type = ArgosNotificationType.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    // 1. Limpiar notificacion previa si existe (v2.14.1: Evita sobreposición)
    _hide();

    final overlay = Overlay.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    IconData icon;
    Color color;

    switch (type) {
      case ArgosNotificationType.success:
        icon = Icons.check_circle_rounded;
        color = Colors.greenAccent;
        break;
      case ArgosNotificationType.warning:
        icon = Icons.warning_amber_rounded;
        color = Colors.orangeAccent;
        break;
      case ArgosNotificationType.error:
        icon = Icons.error_outline_rounded;
        color = Colors.redAccent;
        break;
      case ArgosNotificationType.info:
        icon = Icons.info_outline_rounded;
        color = Colors.blueAccent;
    }

    _currentEntry = OverlayEntry(
      builder: (context) => _NotificationWidget(
        message: message,
        icon: icon,
        color: color,
        isDark: isDark,
        onDismiss: _hide,
      ),
    );

    overlay.insert(_currentEntry!);

    _timer = Timer(duration, () {
      _hide();
    });
  }

  static void _hide() {
    _timer?.cancel();
    _currentEntry?.remove();
    _currentEntry = null;
  }
}

class _NotificationWidget extends StatefulWidget {
  final String message;
  final IconData icon;
  final Color color;
  final bool isDark;
  final VoidCallback onDismiss;

  const _NotificationWidget({
    required this.message,
    required this.icon,
    required this.color,
    required this.isDark,
    required this.onDismiss,
  });

  @override
  State<_NotificationWidget> createState() => _NotificationWidgetState();
}

class _NotificationWidgetState extends State<_NotificationWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _offsetAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    _offsetAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _opacityAnimation = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 60,
      left: 20,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: FadeTransition(
          opacity: _opacityAnimation,
          child: SlideTransition(
            position: _offsetAnimation,
            child: GestureDetector(
              onTap: widget.onDismiss,
              child: GlassBox(
                borderRadius: 20,
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                opacity: widget.isDark ? 0.2 : 0.4,
                blur: 15,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(widget.icon, color: widget.color, size: 20),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        widget.message,
                        style: TextStyle(
                          color: widget.isDark ? Colors.white : Colors.black87,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
