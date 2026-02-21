import 'dart:async';
import 'package:flutter/material.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
import './ui_utils.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();

  factory ConnectivityService() {
    return _instance;
  }

  ConnectivityService._internal();

  StreamSubscription? _subscription;
  bool _isFirstCheck = true;
  bool _previousConnectionStatus = true;

  // Notificador para que la UI reaccione sutilmente
  final ValueNotifier<bool> isConnectedNotifier = ValueNotifier<bool>(true);

  void initialize() {
    _subscription = InternetConnection().onStatusChange.listen((
      InternetStatus status,
    ) {
      bool isConnected = status == InternetStatus.connected;
      isConnectedNotifier.value = isConnected;

      if (_isFirstCheck) {
        _isFirstCheck = false;
        _previousConnectionStatus = isConnected;
        return;
      }

      if (isConnected && !_previousConnectionStatus) {
        // Solo mostramos notificación sutil cuando regresa la conexión
        UiUtils.showSuccess("Conexión restaurada");
      }
      // El modo offline ya no muestra notificación intrusiva,
      // se encarga el ConnectivityBadge sutilmente.

      _previousConnectionStatus = isConnected;
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
