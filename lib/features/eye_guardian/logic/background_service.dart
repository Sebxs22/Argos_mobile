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
bool _isProcessingAlert = false; // Bloqueo de concurrencia

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
  Timer.periodic(const Duration(minutes: 2), (timer) async {
    _handleProactiveLocation(apiService);
  });

  service.on('stopService').listen((event) {
    service.stopSelf();
  });

  service.on('onManualAlert').listen((event) async {
    developer.log("ARGOS BACKGROUND: Alerta MANUAL recibida.");
    _handlePanicAlert(apiService, service, notificationsPlugin);
  });

  // --- ESCUCHA DE RESOLUCIÓN (v2.15.5) ---
  service.on('onAlertResolved').listen((event) async {
    developer
        .log("ARGOS BACKGROUND: Alerta RESUELTA. Reseteando protectores...");
    _lastAlertTime = null;
    _isProcessingAlert = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload(); // Sincronizar con lo que la UI limpió
  });

  service.on('onAccompanimentChanged').listen((event) async {
    final active = (event?['active'] as bool?) ?? false;
    developer.log("ARGOS BACKGROUND: Modo Acompañamiento cambiado a: $active");
    // Forzamos un refresco inmediato
    _handleProactiveLocation(apiService);
  });
}

// --- PROTOCOLOS DE RESPUESTA ARGOS ---

Future<void> _handlePanicAlert(
  ApiService apiService,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
) async {
  // --- 1. BLOQUEO DE CONCURRENCIA (v2.15.1) ---
  if (_isProcessingAlert) {
    developer.log("ARGOS: SOS ignorado. Procesamiento en curso.");
    return;
  }
  _isProcessingAlert = true;

  try {
    // --- 1.1 VALIDACIÓN DE AUTENTICACION (v2.15.2 + v2.15.3 Retry) ---
    var user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      // Re-intento rápido para asegurar sync de sesión (v2.15.3)
      await Future.delayed(const Duration(milliseconds: 500));
      user = Supabase.instance.client.auth.currentUser;
    }

    if (user == null) {
      developer
          .log("ARGOS: SOS abortado. No hay sesión activa tras re-intento.");
      _isProcessingAlert = false;
      return;
    }

    final now = DateTime.now();

    // --- 2. BLOQUEO DE CARRERA (v2.14.4 + v2.15.5 5s) ---
    if (_lastAlertTime != null &&
        now.difference(_lastAlertTime!) < const Duration(seconds: 5)) {
      developer.log("ARGOS: SOS ignorado. Re-disparo muy rápido.");
      _isProcessingAlert = false;
      return;
    }

    // --- 3. BLOQUEO DE DUPLICADOS Y COOLDOWN ---
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.reload();

    final String? existingAlertaId = prefs.getString('pending_alert_id');
    if (existingAlertaId != null) {
      developer.log(
          "ARGOS: SOS ignorado. Alerta pendiente activa ($existingAlertaId). Re-invocando UI...");
      // v2.15.2: Recuperación Visual - Si ya existe, forzamos a la UI a mostrar la pantalla
      service.invoke('onShake', {
        "alertaId": existingAlertaId,
        "isRecovery": true,
      });
      _isProcessingAlert = false;
      return;
    }

    final int? lastSosMillis = prefs.getInt('last_sos_timestamp');
    if (lastSosMillis != null) {
      final lastSosTime = DateTime.fromMillisecondsSinceEpoch(lastSosMillis);
      final diff = now.difference(lastSosTime);
      if (diff < const Duration(minutes: 3)) {
        developer.log("ARGOS: SOS ignorado por Cooldown (${diff.inSeconds}s)");
        _isProcessingAlert = false;
        return;
      }
    }

    _lastAlertTime = now;
    developer.log("ARGOS: ¡SOS INICIADO! Ejecutando protocolos...");

    // VIBRACIÓN Y AVISO TÁCTIL (Solo una vez)
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

    Position? position;
    String? currentAlertaId;

    // 4. SOS FAST-TRACK (Ubicación rápida)
    try {
      position = await Geolocator.getLastKnownPosition();
      if (position != null) {
        final age = DateTime.now().difference(position.timestamp);
        developer.log("ARGOS: Lanzando SOS Fast-Track...");

        currentAlertaId = await _enviarSOSInicial(
            apiService, service, notifications, position);

        // Si es muy fresca, terminamos aquí (pero liberamos bloqueo!)
        if (age < const Duration(seconds: 8)) {
          _isProcessingAlert = false;
          return;
        }
      }
    } catch (e) {
      developer.log("Error Fast-Track: $e");
    }

    // 5. REFUERZO DE PRECISIÓN (Actualización silenciosa)
    try {
      position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 4),
        ),
      );

      developer.log("ARGOS: Actualizando con ALTA PRECISIÓN...");

      if (currentAlertaId == null) {
        await _enviarSOSInicial(apiService, service, notifications, position);
      } else {
        await apiService.actualizarAlertaUbicacion(
            currentAlertaId, position.latitude, position.longitude);
        await apiService.actualizarUbicacion(
            position.latitude, position.longitude);
      }
    } catch (e) {
      if (currentAlertaId == null) {
        developer.log("ARGOS: Alta precisión falló. Intento final medio...");
        position = await Geolocator.getCurrentPosition(
            locationSettings:
                const LocationSettings(accuracy: LocationAccuracy.medium));
        await _enviarSOSInicial(apiService, service, notifications, position);
      }
    }
  } catch (e) {
    developer.log("Error SOS Crítico: $e");
  } finally {
    _isProcessingAlert = false;
  }
}

// Nueva función: Solo para el PRIMER contacto (v2.14.4)
Future<String?> _enviarSOSInicial(
  ApiService apiService,
  ServiceInstance service,
  FlutterLocalNotificationsPlugin notifications,
  Position position,
) async {
  try {
    // 1. Insertar en DB
    final String? alertaId = await apiService.enviarAlertaEmergencia(
      position.latitude,
      position.longitude,
    );

    if (alertaId != null) {
      // 2. Guardar en Memoria para Cooldown y Clasificación
      final SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('pending_alert_id', alertaId);
      await prefs.setInt(
          'last_sos_timestamp', DateTime.now().millisecondsSinceEpoch);

      // 3. Notificar a la UI Local
      service.invoke('onShake', {
        "alertaId": alertaId,
        "lat": position.latitude,
        "lng": position.longitude,
      });

      // 4. Enviar PUSH a OneSignal (Solo una vez!)
      final user = Supabase.instance.client.auth.currentUser;
      if (user != null) {
        final res = await Supabase.instance.client
            .from('perfiles')
            .select('nombre_completo')
            .eq('id', user.id)
            .single();
        await apiService.enviarNotificacionEmergencia(
            res['nombre_completo'] ?? "Un usuario");
      }

      // 5. Mostrar confirmación en celular local
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
    }
    return alertaId;
  } catch (e) {
    developer.log("Error en _enviarSOSInicial: $e");
    return null;
  }
}

Future<void> _handleProactiveLocation(ApiService apiService) async {
  final now = DateTime.now();
  final SharedPreferences prefs = await SharedPreferences.getInstance();
  await prefs.reload();

  // v2.15.7: Frecuencia TIEMPO REAL (5s vs 30s)
  final bool isAccompaniment =
      prefs.getBool('is_accompaniment_active') ?? false;
  final int cooldownSecs = isAccompaniment ? 5 : 30;

  if (_lastProactiveTime != null &&
      now.difference(_lastProactiveTime!) < Duration(seconds: cooldownSecs)) {
    return;
  }
  _lastProactiveTime = now;

  try {
    Position position = await Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(
        accuracy:
            isAccompaniment ? LocationAccuracy.high : LocationAccuracy.medium,
        timeLimit: const Duration(seconds: 5),
      ),
    );
    await apiService.actualizarUbicacion(position.latitude, position.longitude);

    // v2.14.6: PROCESAR GEOCERCAS (Automático)
    await _checkGeofences(apiService, position);

    developer.log(
        "ARGOS: Ubicación proactiva (${isAccompaniment ? 'TIEMPO REAL 5s' : 'NORMAL 30s'}).");
  } catch (e) {
    developer.log("Error rastreo: $e");
  }
}

// LÓGICA DE GEOCERCAS INTELIGENTES (v2.14.6)
Future<void> _checkGeofences(ApiService apiService, Position currentPos) async {
  try {
    final SharedPreferences prefs = await SharedPreferences.getInstance();

    // 1. OBTENER LUGARES (Caché local de 10 min para ahorrar datos)
    final int lastFetch = prefs.getInt('geofence_last_fetch') ?? 0;
    final int nowMillis = DateTime.now().millisecondsSinceEpoch;
    List<Map<String, dynamic>> places = [];

    if (nowMillis - lastFetch > 600000) {
      // 10 minutos
      developer.log("ARGOS: Refrescando base de datos de lugares seguros...");
      final remotePlaces = await apiService.obtenerMisLugaresSeguros();
      // Guardamos en un formato persistente simple
      // (Nota: En un caso real usaríamos jsonEncode, aquí lo manejamos directo si es posible)
      // Por ahora, para el prototipo, lo consultamos si ha pasado el tiempo.
      // Si falla la red, usamos lo que tengamos (pero Prefs no guarda listas de mapas fácil)
      // Simplificación: Lo consultamos siempre por ahora para asegurar precisión.
      places = remotePlaces;
      await prefs.setInt('geofence_last_fetch', nowMillis);
    } else {
      // En una versión más robusta, cargaríamos de JSON en Prefs.
      // Por brevedad, fetch directo (Optimizaremos si el usuario lo pide).
      places = await apiService.obtenerMisLugaresSeguros();
    }

    for (var p in places) {
      final String id = p['id'].toString();
      final String name = p['nombre'] ?? "Lugar";
      final double lat = (p['latitud'] as num).toDouble();
      final double lon = (p['longitud'] as num).toDouble();
      final double radius = (p['radio'] as num).toDouble();

      final double distance = Geolocator.distanceBetween(
        currentPos.latitude,
        currentPos.longitude,
        lat,
        lon,
      );

      final bool isInsideNow = distance <= radius;
      final String stateKey = 'geofence_state_$id';
      final String counterKey = 'geofence_counter_$id';
      final String? prevState = prefs.getString(stateKey);
      final int count = prefs.getInt(counterKey) ?? 0;

      // LÓGICA DE TRANSICIÓN (Sólo notificar cambios confirmados)
      if (prevState == null) {
        await prefs.setString(stateKey, isInsideNow ? 'inside' : 'outside');
        await prefs.setInt(counterKey, 0);
        continue;
      }

      if (isInsideNow && prevState == 'outside') {
        // POSIBLE ENTRADA (v2.14.6: Noise Filter - requiere 2 lecturas)
        final int newCount = count + 1;
        if (newCount >= 2) {
          await apiService.notificarTransicionGeocerca(name, true);
          await prefs.setString(stateKey, 'inside');
          await prefs.setInt(counterKey, 0);
          developer.log("ARGOS GEOFENCE: Entró a $name (Confirmado)");
        } else {
          await prefs.setInt(counterKey, newCount);
          developer.log("ARGOS GEOFENCE: Posible entrada a $name (Pendiente)");
        }
      } else if (!isInsideNow && prevState == 'inside') {
        // POSIBLE SALIDA
        final int newCount = count + 1;
        if (newCount >= 2) {
          await apiService.notificarTransicionGeocerca(name, false);
          await prefs.setString(stateKey, 'outside');
          await prefs.setInt(counterKey, 0);
          developer.log("ARGOS GEOFENCE: Salió de $name (Confirmado)");
        } else {
          await prefs.setInt(counterKey, newCount);
          developer.log("ARGOS GEOFENCE: Posible salida de $name (Pendiente)");
        }
      } else {
        // El estado actual coincide con el previo (Resetear ruido)
        if (count > 0) await prefs.setInt(counterKey, 0);
      }
    }
  } catch (e) {
    developer.log("Error en checkGeofences: $e");
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
