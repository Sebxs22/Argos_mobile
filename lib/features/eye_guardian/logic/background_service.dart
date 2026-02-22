import 'dart:async';
import 'dart:developer' as developer;
import 'dart:ui';
import 'package:flutter/material.dart';
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
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  // Umbral de sensibilidad de PÁNICO (25.0 para capturar arranchones/tirones violentos)
  double threshold = 25.0;

  // Escucha del sensor en SEGUNDO PLANO - PROTECCIÓN 24/7
  userAccelerometerEventStream().listen((UserAccelerometerEvent event) async {
    // Magnitud de la aceleración (Suma de cuadrados para eficiencia)
    double acceleration =
        (event.x * event.x + event.y * event.y + event.z * event.z);

    // --- LÓGICA DE DETECCIÓN INTELIGENTE v2.0.5 ---
    if (acceleration > (threshold * threshold)) {
      // SOS: ALERTA DE PÁNICO (Detección de Arranchón)
      _handlePanicAlert(apiService, service, flutterLocalNotificationsPlugin);
    } else if (acceleration > (12.0 * 12.0)) {
      // MOVIMIENTO: Reporte proactivo silencioso para rastreo preciso
      _handleProactiveLocation(apiService);
    }
  });

  // --- REPORTE DE VIDA (Corazón de seguridad) ---
  // Se mantiene como seguro, pero el rastreo es mayormente reactivo.
  Timer.periodic(const Duration(minutes: 5), (timer) async {
    _handleProactiveLocation(apiService);
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('onManualAlert').listen((event) async {
    developer.log("ARGOS BACKGROUND: Alerta MANUAL recibida.");
    _handlePanicAlert(apiService, service, flutterLocalNotificationsPlugin);
  });
}

// --- PROTOCOLOS DE RESPUESTA ARGOS ---

Future<void> _handlePanicAlert(
  ApiService apiService,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
) async {
  final now = DateTime.now();
  // Anti-spam de 30 segundos
  if (_lastAlertTime != null &&
      now.difference(_lastAlertTime!) < const Duration(seconds: 30)) {
    return;
  }
  _lastAlertTime = now;
  developer.log("ARGOS: ¡SOS DETECTADO! Ejecutando protocolos...");

  try {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    // 1. Enviar Alerta a la Nube
    final String? alertaId = await apiService.enviarAlertaEmergencia(
      position.latitude,
      position.longitude,
    );

    // 2. Notificar a la UI (Reacción visual)
    service.invoke('onShake', {
      "alertaId": alertaId,
      "lat": position.latitude,
      "lng": position.longitude,
    });

    // 3. Notificar a Guardianes vía Push
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

    // 4. Notificación Local Crítica (Confirmación al usuario)
    notifications.show(
        888,
        'ARGOS: SOS ENVIADO',
        'Tus contactos han sido notificados de inmediato.',
        const NotificationDetails(
            android: AndroidNotificationDetails('argos_channel', 'ARGOS',
                importance: Importance.max,
                priority: Priority.high,
                enableVibration: true,
                playSound: false)));
  } catch (e) {
    developer.log("Error critico en SOS: $e");
  }
}

Future<void> _handleProactiveLocation(ApiService apiService) async {
  final now = DateTime.now();
  // Rate limiting de 30 segundos para el rastreo por movimiento
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
    developer.log("Error en rastreo proactivo: $e");
  }
}

class BackgroundServiceManager {
  Future<void> initializeService() async {
    final service = FlutterBackgroundService();

    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'argos_channel',
      'ARGOS Service',
      description: 'Protección 24/7 y detección de pánico',
      importance: Importance.low,
    );

    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
        FlutterLocalNotificationsPlugin();

    if (Theme.of(null == null
                ? (WidgetsBinding.instance.platformDispatcher
                                .platformBrightness ==
                            Brightness.dark
                        ? ThemeData.dark()
                        : ThemeData.light())
                    .focusColor as dynamic
                : null)
            .brightness ==
        Brightness.dark) {
      // Dummy check to use Theme if needed, but in manager it's fine
    }

    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: true,
        isForegroundMode: true,
        notificationChannelId: 'argos_channel',
        initialNotificationTitle: 'ARGOS: Sensor Maestro Activo',
        initialNotificationContent:
            'Protección permanente contra arranchones activa.',
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
