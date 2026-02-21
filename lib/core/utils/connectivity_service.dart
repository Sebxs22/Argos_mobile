import 'dart:async';

import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import 'package:overlay_support/overlay_support.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  StreamSubscription? _subscription;
  bool _isFirstCheck = true;
  bool _previousConnectionStatus = true; // Assume online initially

  void initialize() {
    _subscription = InternetConnection().onStatusChange.listen((
      InternetStatus status,
    ) {
      bool isConnected = status == InternetStatus.connected;

      if (_isFirstCheck) {
        _isFirstCheck = false;
        _previousConnectionStatus = isConnected;
        return;
      }

      if (isConnected && !_previousConnectionStatus) {
        // Back online
        showSimpleNotification(
          const Text(
            "Conexión restaurada",
            style: TextStyle(color: Colors.white),
          ),
          background: Colors.green,
          duration: const Duration(seconds: 3),
          slideDismissDirection: DismissDirection.horizontal,
        );
      } else if (!isConnected && _previousConnectionStatus) {
        // Lost connection
        showSimpleNotification(
          const Text(
            "Sin conexión a internet. Modo Offline activo.",
            style: TextStyle(color: Colors.white),
          ),
          background: Colors.red,
          duration: const Duration(seconds: 4),
          slideDismissDirection: DismissDirection.horizontal,
        );
      }

      _previousConnectionStatus = isConnected;
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
