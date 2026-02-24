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
import 'package:shared_preferences/shared_preferences.dart'; // Memoria persistente Isolate
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
  // Throttle reducido a 15s para mayor reactividad (v2.8.7)
  if (_lastAlertTime != null &&
      now.difference(_lastAlertTime!) < const Duration(seconds: 15)) {
    return;
  }

  // --- BLOQUEO DE DUPLICADOS Y COOLDOWN (v2.14.4) ---
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.reload(); // Sincronizar con el proceso principal

  // 1. Bloqueo por Alerta Activa (No enviar si ya hay una pendiente)
  final String? existingAlertaId = prefs.getString('pending_alert_id');
  if (existingAlertaId != null) {
    developer.log(
        "ARGOS: SOS ignorado. Ya existe una alerta pendiente ($existingAlertaId).");
    return;
  }

  // 2. Bloqueo por Cooldown (3 minutos)
  final int? lastSosMillis = prefs.getInt('last_sos_timestamp');
  if (lastSosMillis != null) {
    final lastSosTime = DateTime.fromMillisecondsSinceEpoch(lastSosMillis);
    final diff = now.difference(lastSosTime);
    if (diff < const Duration(minutes: 3)) {
      developer.log(
          "ARGOS: SOS ignorado por Cooldown. Faltan ${180 - diff.inSeconds}s.");
      return;
    }
  }

  _lastAlertTime = now;
  developer.log("ARGOS: ¡SOS DETECTADO! Ejecutando protocolos...");

  // VIBRACIÓN INMEDIATA (Confirmación táctil para el usuario)
  try {
    notifications.show(
      id: 999,
      title: '⚠️ ARRANCHÓN DETECTADO',
      body: 'Enviando alerta...',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'argos_urgent',
          'ARGOS Urgente',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 500, 200, 500]),
          playSound: false,
        ),
      ),
    );
  } catch (e) {
    developer.log("Error vibrando: $e");
  }

  try {
    // --- ESTRATEGIA DE UBICACIÓN RESILIENTE (v2.14.3: High-Precision Focus) ---
    Position? position;
    bool fastTrackSent = false;

    try {
      // 1. Intento Ultrarrápido: Última ubicación conocida
      position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        // Solo enviamos Fast-Track si la ubicación es "joven" (menos de 10 seg)
        // o si es la única que tenemos disponible al inicio.
        final age = DateTime.now().difference(position.timestamp);

        developer.log("ARGOS: SOS Fast-Track. Antigüedad: ${age.inSeconds}s");

        await _enviarYNotificarSOS(
            apiService, service, notifications, position);
        fastTrackSent = true;

        // Si la posición es MUY fresca (menos de 8 seg), ya es bastante precisa.
        if (age < const Duration(seconds: 8)) {
          developer.log("ARGOS: Ubicación Fast-Track suficientemente precisa.");
          return;
        }
      }
    } catch (e) {
      developer.log("Error obteniendo lastKnownPosition: $e");
    }

    try {
      // 2. Intento de Alta Precisión (Siempre intentamos mejorar la puntería)
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(
              seconds: 4), // Damos un poco más de tiempo para fijar satélites
        ),
      );

      developer.log("ARGOS: ¡Ubicación de ALTA PRECISIÓN obtenida!");

      // Si ya enviamos una Fast-Track, esta segunda señal ACTUALIZARÁ el mapa
      // Como enviamos el mismo alertaId o simplemente creamos el evento preciso.
      await _enviarYNotificarSOS(apiService, service, notifications, position);
    } catch (e) {
      developer.log("ARGOS: Alta precisión falló. Usando alternativa media...");
      if (!fastTrackSent) {
        // Solo si no enviamos nada antes, intentamos una media rápido
        position = await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.medium,
          ),
        );
        await _enviarYNotificarSOS(
            apiService, service, notifications, position);
      }
    }
  } catch (e) {
    developer.log("Error SOS Crítico: $e");
  }
}

// Función auxiliar para centralizar el envío (v2.14.2)
Future<void> _enviarYNotificarSOS(
  ApiService apiService,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
  Position position,
) async {
  try {
    final String? alertaId = await apiService.enviarAlertaEmergencia(
      position.latitude,
      position.longitude,
    );

    service.invoke('onShake', {
      "alertaId": alertaId,
      "lat": position.latitude,
      "lng": position.longitude,
    });

    if (alertaId != null) {
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_alert_id', alertaId);
      await prefs.setInt(
          'last_sos_timestamp', DateTime.now().millisecondsSinceEpoch);
    }

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

    await notifications.show(
      id: 888,
      title: 'ARGOS: SOS ENVIADO',
      body: 'Confirmado. Ayuda en camino.',
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          'argos_channel',
          'ARGOS',
          importance: Importance.max,
          priority: Priority.high,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 200, 100, 200, 100, 500]),
          playSound: false,
        ),
      ),
    );
  } catch (e) {
    developer.log("Error en _enviarYNotificarSOS: $e");
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
      'ARGOS: Protección Activa',
      description: 'Detección de peligro 24/7',
      importance: Importance.max, // PRIORIDAD MÁXIMA
      enableVibration: true,
      playSound: false,
      showBadge: true,
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
        initialNotificationTitle: '🔰 ARGOS: GUARDÍAN ACTIVO',
        initialNotificationContent: 'Vigilando en todo momento. (v2.3.0)',
        foregroundServiceNotificationId: 888,
        autoStartOnBoot: true, // AUTO-INICIO AL ENCENDER
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
