import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart'; // Geolocator
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Dotenv
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase
import '../../../core/network/api_service.dart';

// Variable para controlar el spam de alertas (Rate Limiting)
DateTime? _lastAlertTime;

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // 1. Inicializar Entorno y Supabase (Necesario en Background Isolate)
  await dotenv.load(fileName: ".env");
  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  final ApiService apiService = ApiService();
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Umbral de sensibilidad (ajústalo si es muy sensible o muy duro)
  double threshold = 35.0;

  // Escucha del sensor en SEGUNDO PLANO
  userAccelerometerEventStream().listen((UserAccelerometerEvent event) async {
    double acceleration = event.x.abs() + event.y.abs() + event.z.abs();

    if (acceleration > threshold) {
      // 1. VERIFICACIÓN DE TIEMPO (Anti-Spam)
      final now = DateTime.now();
      if (_lastAlertTime != null &&
          now.difference(_lastAlertTime!) < const Duration(seconds: 30)) {
        // Si pasaron menos de 30 segundos desde la última, ignoramos
        developer.log(
          "ARGOS: Movimiento detectado, pero esperando enfriamiento...",
        );
        return;
      }

      // 2. ACTUALIZAR TIMESTAMP
      _lastAlertTime = now;

      // 3. ACCIÓN INMEDIATA (Sin cuenta regresiva)
      developer.log("ARGOS BACKGROUND: ¡ALERTA CONFIRMADA! Enviando...");

      try {
        Position position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
          ),
        );

        // Enviar a la API con ubicación REAL
        await apiService.enviarAlertaEmergencia(
          position.latitude,
          position.longitude,
        );

        // Notificar a Guardianes
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          final res = await Supabase.instance.client
              .from('perfiles')
              .select('nombre_completo')
              .eq('id', user.id)
              .single();
          final nombre = res['nombre_completo'] ?? "Un usuario";
          await apiService.enviarNotificacionEmergencia(nombre);
        }
      } catch (e) {
        developer.log("Error obteniendo ubicación en background: $e");
        // Fallback: Enviar 0,0 o última conocida si fuera posible
        await apiService.enviarAlertaEmergencia(0.0, 0.0);
      }

      // Notificación discreta de confirmación
      // Notificación discreta de confirmación
      flutterLocalNotificationsPlugin.show(
        id: 888,
        title: 'ARGOS: ALERTA ENVIADA',
        body: 'Se notificó a tus contactos. Mantén la calma.',
        notificationDetails: const NotificationDetails(
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
        initialNotificationTitle: 'Modo Travesía Activo',
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
