import 'dart:async';
import 'dart:developer' as developer;
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'package:geolocator/geolocator.dart'; // Geolocator
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Dotenv
import 'package:supabase_flutter/supabase_flutter.dart'; // Supabase
import '../../../core/network/api_service.dart';

// Variables de control de tráfico (Anti-Spam)
DateTime? _lastAlertTime;
DateTime? _lastProactiveTime;

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
  final FlutterLocalNotificationsPlugin notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Umbral de sensibilidad MILIMÉTRICA (15.0 para capturar tirones rápidos)
  double threshold = 15.0;

  // Escucha del sensor en SEGUNDO PLANO - PROTECCIÓN 24/7
  userAccelerometerEventStream().listen((UserAccelerometerEvent event) async {
    // Magnitud de la aceleración (Suma de cuadrados para eficiencia)
    double acceleration =
        (event.x * event.x + event.y * event.y + event.z * event.z);

    // --- LÓGICA DE DETECCIÓN INTELIGENTE v2.0.5 ---
    if (acceleration > (threshold * threshold)) {
      // SOS: ALERTA DE PÁNICO (Detección de Arranchón)
      _handlePanicAlert(apiService, service, notificationsPlugin);
    } else if (acceleration > (12.0 * 12.0)) {
      // MOVIMIENTO: Reporte proactivo silencioso para rastreo preciso
      _handleProactiveLocation(apiService);
    }
  });

  // --- REPORTE DE VIDA (Corazón de seguridad) ---
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    _handleProactiveLocation(apiService);
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('onManualAlert').listen((event) async {
    developer.log("ARGOS BACKGROUND: Alerta MANUAL recibida.");
    _handlePanicAlert(apiService, service, notificationsPlugin);
  });
}

// --- PROTOCOLOS DE RESPUESTA ARGOS ---

Future<void> _handlePanicAlert(
  ApiService apiService,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
) async {
  final now = DateTime.now();
  if (_lastAlertTime != null &&
      now.difference(_lastAlertTime!) < const Duration(seconds: 30)) {
    return;
  }
  _lastAlertTime = now;
  developer.log("ARGOS: ¡SOS DETECTADO! Ejecutando protocolos...");

  // VIBRACIÓN INMEDIATA (Confirmación táctil para el usuario)
  try {
    // Usamos el canal de notificación para forzar la vibración inmediata
    // ya que flutter_vibrate puede ser inestable en Isolates de fondo.
    notifications.show(
      id: 999,
      title: '⚠️ ARRANCHÓN DETECTADO',
      body: 'Enviando alerta...',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'argos_urgent', 'ARGOS Urgente',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern:
              Int64List.fromList([0, 500, 200, 500]), // Vibración doble fuerte
          playSound: false,
        ),
      ),
    );
  } catch (e) {
    developer.log("Error vibrando: $e");
  }

  try {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final String? alertaId = await apiService.enviarAlertaEmergencia(
      position.latitude,
      position.longitude,
    );

    service.invoke('onShake', {
      "alertaId": alertaId,
      "lat": position.latitude,
      "lng": position.longitude,
    });

    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      final res = await Supabase.instance.client
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', user.id)
          .single();
      await apiService
          .enviarNotificacionEmergencia(res['nombre_completo'] ?? "Un usuario");
    }

    // Notificación Local (Compatibilidad confirmada para v20+)
    await notifications.show(
      id: 888,
      title: 'ARGOS: SOS ENVIADO',
      body: 'Confirmado. Ayuda en camino.',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'argos_channel',
          'ARGOS',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          playSound: false,
        ),
      ),
    );
  } catch (e) {
    developer.log("Error SOS: $e");
  }
}

Future<void> _handleProactiveLocation(ApiService apiService) async {
  final now = DateTime.now();
  if (_lastProactiveTime != null &&
      now.difference(_lastProactiveTime!) < const Duration(seconds: 30)) {
    return;
  }
  _lastProactiveTime = now;

  try {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings:
          const LocationSettings(accuracy: LocationAccuracy.medium),
    );
    await apiService.actualizarUbicacion(position.latitude, position.longitude);
    developer.log("ARGOS: Ubicación actualizada proactivamente.");
  } catch (e) {
    developer.log("Error rastreo: $e");
  }
}

class BackgroundServiceManager {
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'argos_channel',
      'ARGOS Service',
      description: 'Protección 24/7',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin notifications =
        FlutterLocalNotificationsPlugin();

    await notifications
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'argos_channel',
        initialNotificationTitle: 'ARGOS: Protegiéndote',
        initialNotificationContent: 'Sacude el celular ante un peligro.',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: true,
        onForeground: onStart,
      ),
    );
  }

  void start() => FlutterBackgroundService().startService();
  void stop() => FlutterBackgroundService().invoke("stopService");
}
