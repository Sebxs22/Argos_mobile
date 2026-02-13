import 'dart:async';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../../core/network/api_service.dart';

// Variable para controlar el spam de alertas (Rate Limiting)
DateTime? _lastAlertTime;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();
  final ApiService apiService = ApiService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  // Umbral de sensibilidad (ajústalo si es muy sensible o muy duro)
  double threshold = 35.0;

  // Escucha del sensor en SEGUNDO PLANO
  userAccelerometerEvents.listen((UserAccelerometerEvent event) {
    double acceleration = event.x.abs() + event.y.abs() + event.z.abs();

    if (acceleration > threshold) {
      // 1. VERIFICACIÓN DE TIEMPO (Anti-Spam)
      final now = DateTime.now();
      if (_lastAlertTime != null &&
          now.difference(_lastAlertTime!) < const Duration(seconds: 30)) {
        // Si pasaron menos de 30 segundos desde la última, ignoramos
        print("ARGOS: Movimiento detectado, pero esperando enfriamiento...");
        return;
      }

      // 2. ACTUALIZAR TIMESTAMP
      _lastAlertTime = now;

      // 3. ACCIÓN INMEDIATA (Sin cuenta regresiva)
      print("ARGOS BACKGROUND: ¡ALERTA CONFIRMADA! Enviando...");

      // Enviar a la API
      apiService.enviarAlertaEmergencia(-1.67, -78.65);

      // Notificación discreta de confirmación
      flutterLocalNotificationsPlugin.show(
        888,
        'ARGOS: ALERTA ENVIADA',
        'Se notificó a tus contactos. Mantén la calma.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'argos_channel',
            'ARGOS Service',
            importance: Importance.max,
            priority: Priority.high,
            playSound: false, // Silencioso para no delatarte si te escondes
            enableVibration: true, // Solo vibración para confirmar
          ),
        ),
      );
    }
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });
}

class BackgroundServiceManager {
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'argos_channel',
      'ARGOS Service',
      description: 'Canal de seguridad silenciosa',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'argos_channel',
        initialNotificationTitle: '🛡️ Modo Travesía Activo',
        initialNotificationContent: 'Sacude el celular en caso de emergencia.',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  void start() => FlutterBackgroundService().startService();
  void stop() => FlutterBackgroundService().invoke("stopService");
}