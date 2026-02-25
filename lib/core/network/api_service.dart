import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // v2.13.1: Persistencia
import 'package:flutter_background_service/flutter_background_service.dart'; // v2.15.5
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

// --- IMPORTANTE: Asegúrate de que esta ruta sea correcta según tu proyecto ---
import '../../features/sanctuaries/data/mock_sanctuaries_data.dart';
import '../utils/ui_utils.dart'; // Import UiUtils

class ApiService {
  // v2.12.1: Cache global para evitar re-escaneos innecesarios  // v2.12.1: Cache Estático (v2.13.1: Ahora Persistente)
  static List<SanctuaryModel> cacheSantuarios = [];
  static LatLng? ultimaPosicionSantuarios;

  // v2.13.1: Guardar Caché en Disco
  Future<void> guardarCacheSantuarios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> jsonList = cacheSantuarios.map((s) {
        return {
          'name': s.name,
          'lat': s.location.latitude,
          'lng': s.location.longitude,
          'type': s.type.name,
          'address': s.address,
        };
      }).toList();

      await prefs.setString('argos_cache_santuarios', jsonEncode(jsonList));
      if (ultimaPosicionSantuarios != null) {
        await prefs.setDouble(
            'argos_cache_lat', ultimaPosicionSantuarios!.latitude);
        await prefs.setDouble(
            'argos_cache_lng', ultimaPosicionSantuarios!.longitude);
      }
      debugPrint("💾 ARGOS CACHE: Guardado exitoso en disco.");
    } catch (e) {
      debugPrint("❌ ARGOS CACHE: Error al guardar: $e");
    }
  }

  // v2.13.1: Cargar Caché desde Disco
  Future<void> cargarCacheSantuarios() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString('argos_cache_santuarios');
      if (jsonStr != null) {
        final List<dynamic> decoded = jsonDecode(jsonStr);
        cacheSantuarios = decoded.map((item) {
          return SanctuaryModel(
            item['name'],
            LatLng(item['lat'], item['lng']),
            SanctuaryType.values.firstWhere((e) => e.name == item['type'],
                orElse: () => SanctuaryType.other),
            address: item['address'],
          );
        }).toList();
      }

      final double? lat = prefs.getDouble('argos_cache_lat');
      final double? lng = prefs.getDouble('argos_cache_lng');
      if (lat != null && lng != null) {
        ultimaPosicionSantuarios = LatLng(lat, lng);
      }
      debugPrint(
          "📂 ARGOS CACHE: Cargados ${cacheSantuarios.length} puntos desde el disco.");
    } catch (e) {
      debugPrint("❌ ARGOS CACHE: Error al cargar: $e");
    }
  }

  // Usamos el cliente de Supabase ya inicializado en el main.dart
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<Map<String, dynamic>?> obtenerPerfilActual() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return null;
    return await _supabase.from('perfiles').select().eq('id', user.id).single();
  }

  // 1. ENVIAR ALERTA (POST DIRECTO A SUPABASE)
  // Se encarga de guardar el reporte de pánico en la nube.
  Future<String?> enviarAlertaEmergencia(double lat, double long) async {
    try {
      final response = await _supabase
          .from('alertas')
          .insert({
            'latitud': lat,
            'longitud': long,
            'tipo': 'emergencia',
            'mensaje': 'S.O.S. Ayuda solicitada desde dispositivo móvil',
            // Guardamos en UTC para evitar desfases de horario entre países
            'fecha': DateTime.now().toUtc().toIso8601String(),
          })
          .select('id')
          .single();

      final String idGenerado = response['id'].toString();
      debugPrint("ARGOS DATABASE: Alerta insertada con ID: $idGenerado");
      return idGenerado;
    } catch (e) {
      debugPrint("Error al enviar alerta (Background Safe): $e");
      return null;
    }
  }

  // 1.7. LUGRES SEGUROS Y GEOCERCAS (v2.14.6)

  // Obtener mis lugares seguros
  Future<List<Map<String, dynamic>>> obtenerMisLugaresSeguros() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return [];

      final res = await _supabase
          .from('lugares_seguros')
          .select()
          .eq('usuario_id', user.id);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint("Error obteniendo lugares seguros: $e");
      return [];
    }
  }

  // Registrar un nuevo lugar seguro
  Future<void> registrarLugarSeguro(
      String nombre, double lat, double long, double radio) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('lugares_seguros').insert({
        'usuario_id': user.id,
        'nombre': nombre,
        'latitud': lat,
        'longitud': long,
        'radio': radio,
      });
    } catch (e) {
      debugPrint("Error registrando lugar seguro: $e");
    }
  }

  // ELIMINAR LUGAR SEGURO
  Future<void> eliminarLugarSeguro(int id) async {
    try {
      await _supabase.from('lugares_seguros').delete().eq('id', id);
    } catch (e) {
      debugPrint("Error eliminando lugar seguro: $e");
    }
  }

  // NOTIFICAR TRANSICIÓN DE GEOCERCA (Llegada/Salida)
  Future<void> notificarTransicionGeocerca(
      String nombreLugar, bool entrando) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Obtener mis datos (para el nombre)
      final perfil = await _supabase
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', user.id)
          .single();
      final String nombreUsuario = perfil['nombre_completo'] ?? "Un miembro";

      // 2. Obtener IDs de mis guardianes para notificarles
      final resGuardianes = await _supabase
          .from('circulo_confianza')
          .select('perfiles(onesignal_id)')
          .eq('usuario_id', user.id);

      final List<String> targetIds = (resGuardianes as List)
          .map((e) => e['perfiles']['onesignal_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (targetIds.isEmpty) return;

      final String statusMsg = entrando ? "HA LLEGADO A" : "HA SALIDO DE";
      final String emoji = entrando ? "✅" : "⚠️";

      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic ${dotenv.env['ONESIGNAL_REST_API_KEY']}',
        },
        body: jsonEncode({
          'app_id': dotenv.env['ONESIGNAL_APP_ID'],
          'include_player_ids': targetIds,
          'contents': {'es': '$emoji $nombreUsuario $statusMsg $nombreLugar'},
          'headings': {'es': 'ARGOS: Círculo de Confianza'},
          'priority': 5,
        }),
      );

      debugPrint("ARGOS: Notificado $statusMsg $nombreLugar a guardianes.");
    } catch (e) {
      debugPrint("Error notificando geocerca: $e");
    }
  }

  // 1.5.2 NOTIFICAR NUEVO LUGAR SEGURO (v2.15.9)
  Future<void> notificarNuevoLugarSeguro(String nombreLugar) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // 1. Obtener mi nombre
      final perfil = await _supabase
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', user.id)
          .single();
      final String nombreUsuario = perfil['nombre_completo'] ?? "Un miembro";

      // 2. Obtener IDs de mis guardianes para notificarles
      final resGuardianes = await _supabase
          .from('circulo_confianza')
          .select('perfiles(onesignal_id)')
          .eq('usuario_id', user.id);

      final List<String> targetIds = (resGuardianes as List)
          .map((e) => e['perfiles']['onesignal_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (targetIds.isEmpty) return;

      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic ${dotenv.env['ONESIGNAL_REST_API_KEY']}',
        },
        body: jsonEncode({
          'app_id': dotenv.env['ONESIGNAL_APP_ID'],
          'include_player_ids': targetIds,
          'contents': {
            'es':
                '🏠 $nombreUsuario ha registrado un nuevo Lugar Seguro: $nombreLugar'
          },
          'headings': {'es': 'ARGOS: Nuevo Lugar Seguro'},
          'priority': 5,
        }),
      );

      debugPrint("ARGOS: Notificado nuevo lugar ($nombreLugar) a guardianes.");
    } catch (e) {
      debugPrint("Error notificando nuevo lugar: $e");
    }
  }

  // 1.6. ACTUALIZAR ESTADO DE ACOMPAÑAMIENTO (v2.14.5)
  Future<void> actualizarEstadoAcompanamiento(bool activo) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('perfiles').update({
        'is_accompaniment_active': activo,
      }).eq('id', user.id);
    } catch (e) {
      debugPrint("Error actualizando estado acompañamiento: $e");
    }
  }

  // 1.5. ACTUALIZAR UBICACIÓN DE ALERTA EXISTENTE (v2.14.4)
  Future<void> actualizarAlertaUbicacion(
      String alertaId, double lat, double long) async {
    try {
      final int idNum = int.tryParse(alertaId) ?? 0;
      if (idNum == 0) return;

      await _supabase.from('alertas').update({
        'latitud': lat,
        'longitud': long,
        'fecha': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', idNum);

      debugPrint(
          "ARGOS DATABASE: Alerta $idNum actualizada con alta precisión");
    } catch (e) {
      debugPrint("Error actualizando precisión de alerta: $e");
    }
  }

  // Método para clasificar el incidente
  Future<void> clasificarIncidente(String alertaId, String tipo) async {
    try {
      // 0. Parseo a int (BigInt friendly)
      final int idNum = int.tryParse(alertaId) ?? 0;
      if (idNum == 0) throw Exception("ID de alerta inválido");

      // 1. Definir un mensaje amigable según el tipo (Higiene v2.4.3)
      String nuevoMensaje;
      switch (tipo.toLowerCase()) {
        case 'robo':
          nuevoMensaje = "Incidente de Robo o Asalto reportado.";
          break;
        case 'acoso':
          nuevoMensaje = "Reporte de Acoso o Seguimiento.";
          break;
        case 'medica':
          nuevoMensaje = "Solicitud de Emergencia Médica.";
          break;
        case 'accidente':
          nuevoMensaje = "Aviso de Accidente Vial en la zona.";
          break;
        default:
          nuevoMensaje = "Situación de peligro reportada.";
      }

      debugPrint("ARGOS: Clasificando ID $idNum como $tipo...");

      // 2. Actualizar en Supabase (Usamos int numérico para BigInt)
      await _supabase
          .from('alertas')
          .update({'tipo': tipo, 'mensaje': nuevoMensaje}).eq('id', idNum);

      // --- LIMPIEZA DE CACHÉ Y BLOQUEO (v2.4.7) ---
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_danger_zones');
      await prefs.remove('pending_alert_id');
      await prefs
          .remove('last_sos_timestamp'); // Override: Permitir alerta inmediata

      // 3. Notificar al Isolate de Fondo para reset total (v2.15.5)
      FlutterBackgroundService().invoke('onAlertResolved');

      debugPrint(
          "ARGOS: Alerta $idNum clasificada. Memoria y Cooldown liberados.");
    } catch (e) {
      debugPrint("Error clasificando incidente: $e");
      throw Exception("Error al clasificar incidente");
    }
  }

  // Método para cancelar una alerta (En caso de falso positivo)
  Future<void> cancelarAlerta(String alertaId) async {
    try {
      final int idNum = int.tryParse(alertaId) ?? 0;
      if (idNum == 0) {
        debugPrint(
            "ARGOS ERROR: Intento de cancelar con ID inválido ($alertaId)");
        return;
      }

      debugPrint("ARGOS: Intentando borrar de Supabase ID: $idNum");

      // 1. Borrar de Supabase (Nube)
      // Usamos el ID como int, Dart int es 64-bit y mapea perfecto a BigInt
      await _supabase.from('alertas').delete().eq('id', idNum);

      // 2. Limpiar Caché Local e ID Pendiente (v2.4.7)
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('cached_danger_zones');
      await prefs.remove('pending_alert_id');
      await prefs
          .remove('last_sos_timestamp'); // Override: Permitir alerta inmediata

      // 3. Notificar al Isolate de Fondo para reset total (v2.15.5)
      FlutterBackgroundService().invoke('onAlertResolved');

      debugPrint(
          "ARGOS: Alerta $idNum borrada física y localmente. Memoria y Cooldown liberados.");
      UiUtils.showSuccess("Alerta cancelada. Mapa purgado.");
    } catch (e) {
      debugPrint("Error cancelando alerta: $e");
    }
  }

  // 2. OBTENER ALERTAS CON TIEMPO REAL, AGRUPAMIENTO Y CACHÉ
  // Escucha cambios en Supabase (INSERT, UPDATE, DELETE) para actualizar el mapa al instante.
  Stream<List<DangerZoneModel>> streamAlertas() {
    return _supabase
        .from('alertas')
        .stream(primaryKey: ['id'])
        .order('fecha', ascending: false)
        .map((data) {
          // Filtro de tiempo: Solo mostrar alertas de las últimas 48 horas (v2.4.4)
          final fortyEightHoursAgo =
              DateTime.now().toUtc().subtract(const Duration(hours: 48));

          final filteredData = data.where((item) {
            try {
              final fecha = DateTime.parse(item['fecha'] ?? "");
              return fecha.isAfter(fortyEightHoursAgo);
            } catch (_) {
              return false;
            }
          }).toList();

          // Guardar en caché para modo offline
          _saveAlertsToCache(filteredData);

          return _procesarAlertasEnZonas(filteredData);
        });
  }

  // Guardar en caché local de forma asíncrona (Fire & Forget)
  void _saveAlertsToCache(List<dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('cached_danger_zones', jsonEncode(data));
  }

  // Lógica de procesamiento de alertas (Clustering) extraída para reutilización
  List<DangerZoneModel> _procesarAlertasEnZonas(List<dynamic> data) {
    List<DangerZoneModel> zonasAgrupadas = [];
    const Distance distanceCalc = Distance();

    for (var item in data) {
      if (item['latitud'] == null || item['longitud'] == null) continue;

      LatLng puntoAlerta = LatLng(
        (item['latitud'] as num).toDouble(),
        (item['longitud'] as num).toDouble(),
      );
      String fechaStr = item['fecha'] ?? "";
      DateTime timestamp =
          DateTime.tryParse(fechaStr)?.toLocal() ?? DateTime.now();
      String tipo = item['tipo'] ?? "ALERTA";

      // MAPEO DINÁMICO DE ICONOS
      IconData iconMapping;
      switch (tipo.toLowerCase()) {
        case 'robo':
          iconMapping = Icons.gavel_rounded;
          break;
        case 'acoso':
          iconMapping = Icons.visibility_rounded;
          break;
        case 'medica':
          iconMapping = Icons.medical_services_rounded;
          break;
        case 'accidente':
          iconMapping = Icons.car_crash_rounded;
          break;
        default:
          iconMapping = Icons.warning_amber_rounded;
      }

      ReportModel nuevoReporte = ReportModel(
        tipo.replaceAll('_', ' ').toUpperCase(),
        timestamp,
        item['mensaje'] ?? "Alerta de seguridad",
        iconMapping,
      );

      // Algoritmo de Clustering: Si hay un reporte a menos de 100m, se agrupan.
      int indexZonaCercana = -1;
      for (int i = 0; i < zonasAgrupadas.length; i++) {
        if (distanceCalc.as(
              LengthUnit.Meter,
              puntoAlerta,
              zonasAgrupadas[i].center,
            ) <
            100) {
          indexZonaCercana = i;
          break;
        }
      }

      if (indexZonaCercana != -1) {
        var zonaExistente = zonasAgrupadas[indexZonaCercana];
        List<ReportModel> listaActualizada = List.from(zonaExistente.reports)
          ..add(nuevoReporte);

        zonasAgrupadas[indexZonaCercana] = DangerZoneModel(
          center: zonaExistente.center,
          radius: zonaExistente.radius,
          reports: listaActualizada,
        );
      } else {
        zonasAgrupadas.add(
          DangerZoneModel(
            center: puntoAlerta,
            radius: 150,
            reports: [nuevoReporte],
          ),
        );
      }
    }
    return zonasAgrupadas;
  }

  // Método legacy (Sincrónico) mantenido por compatibilidad pero que ahora usa la lógica centralizada
  Future<List<DangerZoneModel>> obtenerAlertas() async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'cached_danger_zones';

    try {
      final fortyEightHoursAgo = DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 48))
          .toIso8601String();

      final List<dynamic> remoteData = await _supabase
          .from('alertas')
          .select()
          .gte('fecha', fortyEightHoursAgo)
          .order('fecha', ascending: false);

      _saveAlertsToCache(remoteData);
      return _procesarAlertasEnZonas(remoteData);
    } catch (e) {
      if (prefs.containsKey(cacheKey)) {
        final data = jsonDecode(prefs.getString(cacheKey)!);
        return _procesarAlertasEnZonas(data);
      }
      return [];
    }
  }

  // 3. BUSCADOR DE DIRECCIONES (NOMINATIM OSM)
  // Busca calles reales. Prioriza Riobamba para mayor exactitud.
  Future<List<Map<String, dynamic>>> buscarDirecciones(String consulta) async {
    if (consulta.length < 3) return [];

    try {
      // Optimizamos la búsqueda añadiendo el contexto de la ciudad
      final String queryFinal = "$consulta, Riobamba, Ecuador";
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?q=${Uri.encodeComponent(queryFinal)}&format=json&limit=5&addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {
          'User-Agent': 'Argos_Security_App', // Requerido por OSM
        },
      );

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        return data
            .map(
              (item) => {
                'display_name': item['display_name'],
                'lat': double.parse(item['lat']),
                'lon': double.parse(item['lon']),
              },
            )
            .toList();
      }
    } catch (e) {
      debugPrint("Error en el autocompletado: $e");
    }
    return [];
  }

  // 4. VISIÓN DE ARGOS (Cálculo de Ruta Segura con perfiles OSRM correctos)
  Future<Map<String, dynamic>> calcularRutaSegura(
    LatLng origen,
    LatLng destino, {
    String modo = 'foot',
  }) async {
    try {
      final apiKey = dotenv.env['ORS_API_KEY'];
      if (apiKey == null || apiKey.isEmpty) {
        return {
          'error':
              'ORS_API_KEY NO CONFIGURADO EN EL .ENV. (Asegúrate de hacer un Hot Restart si acabas de agregarlo).'
        };
      }

      // CORRECCIÓN DE PERFILES ORS (v2.14.0)
      String perfilORS;
      switch (modo) {
        case 'car':
          perfilORS = 'driving-car';
          break;
        case 'foot':
          perfilORS = 'foot-walking';
          break;
        case 'bicycle':
          perfilORS = 'cycling-regular';
          break;
        default:
          perfilORS = 'foot-walking';
      }

      // URL de OpenRouteService (v2)
      // Formato: /v2/directions/{profile}?api_key={key}&start={lng,lat}&end={lng,lat}
      final url = Uri.parse(
        'https://api.openrouteservice.org/v2/directions/$perfilORS?api_key=$apiKey&start=${origen.longitude},${origen.latitude}&end=${destino.longitude},${destino.latitude}',
      );

      debugPrint("🚀 Consultando OpenRouteService ($perfilORS)...");
      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint("❌ ORS Error ${response.statusCode}: ${response.body}");
        return {
          'error': 'Error en servicio ORS (HTTP ${response.statusCode})',
        };
      }

      final data = jsonDecode(response.body);
      final List<dynamic> features = data['features'] ?? [];
      if (features.isEmpty) {
        return {'error': 'No se encontró una ruta válida'};
      }

      // Extraer geometría (GeoJSON line string)
      final List<dynamic> coordinates = features[0]['geometry']['coordinates'];
      List<LatLng> points = coordinates
          .map(
              (c) => LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()))
          .toList();

      // Extraer metadata
      final dynamic properties = features[0]['properties']['summary'];
      final double duracion = (properties['duration'] ?? 0).toDouble();
      final double distancia = (properties['distance'] ?? 0).toDouble();

      debugPrint(
        "⏱️ Duración ORS: $duracion seg | 📏 Distancia: $distancia m",
      );

      final alertas = await obtenerAlertas();
      int puntosDeRiesgo = 0;
      const Distance distance = Distance();

      for (var puntoRuta in points) {
        for (var zona in alertas) {
          if (distance.as(LengthUnit.Meter, puntoRuta, zona.center) <
              zona.radius) {
            puntosDeRiesgo++;
            break; // Una alerta por punto máximo
          }
        }
      }

      double score = 100 - (puntosDeRiesgo * 1.5);
      if (score < 0) score = 0;

      debugPrint(
        "✅ Ruta calculada (ORS) - Score: $score, Puntos de riesgo: $puntosDeRiesgo",
      );

      return {
        'points': points,
        'score': score,
        'duracion': duracion,
        'distancia': distancia,
      };
    } catch (e) {
      debugPrint("❌ Excepción en calcularRutaSegura (ORS): $e");
      return {'error': e.toString()};
    }
  }

  // 5. TRADUCTOR DE TIEMPO (RELATIVO)
  // Corrige el desfase de 5 horas y devuelve texto amigable.
  String calcularTiempoTranscurrido(String fechaIso) {
    try {
      if (fechaIso.isEmpty) return "Hace instantes";

      // Convertimos de UTC (Nube) a Hora Local (Ecuador)
      DateTime fechaAlerta = DateTime.parse(fechaIso).toLocal();
      DateTime ahora = DateTime.now();
      Duration diferencia = ahora.difference(fechaAlerta);

      if (diferencia.isNegative) return "Hace instantes";

      if (diferencia.inSeconds < 60) {
        return "Hace ${diferencia.inSeconds} seg";
      } else if (diferencia.inMinutes < 60) {
        int min = diferencia.inMinutes;
        return "Hace $min ${min == 1 ? 'minuto' : 'minutos'}";
      } else if (diferencia.inHours < 24) {
        int horas = diferencia.inHours;
        return "Hace $horas ${horas == 1 ? 'hora' : 'horas'}";
      } else {
        int dias = diferencia.inDays;
        return "Hace $dias ${dias == 1 ? 'día' : 'días'}";
      }
    } catch (e) {
      return "Hace instantes";
    }
  }

  // 5. EnvIar Notificacion
  Future<void> enviarNotificacionEmergencia(String nombreUsuario) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) {
        debugPrint("❌ API_SERVICE: No hay usuario autenticado para notificar.");
        return;
      }

      final List<String> targetIds = [];

      // A. Obtener IDs de OneSignal de mis guardianes
      final resG = await _supabase
          .from('circulo_confianza')
          .select('perfiles!guardian_id(onesignal_id)')
          .eq('usuario_id', user.id);

      // B. Obtener IDs de OneSignal de mis protegidos
      final resP = await _supabase
          .from('circulo_confianza')
          .select('perfiles!usuario_id(onesignal_id)')
          .eq('guardian_id', user.id);

      for (var row in (resG as List)) {
        final id = row['perfiles']?['onesignal_id'];
        if (id != null && id.toString().length > 5) {
          targetIds.add(id.toString());
        }
      }
      for (var row in (resP as List)) {
        final id = row['perfiles']?['onesignal_id'];
        if (id != null && id.toString().length > 5) {
          targetIds.add(id.toString());
        }
      }

      final uniqueIds = targetIds.toSet().toList();
      debugPrint(
          "🔍 ARGOS NOTIF: Destinatarios finales (${uniqueIds.length}): $uniqueIds");

      if (uniqueIds.isEmpty) {
        debugPrint(
            "⚠️ ARGOS NOTIF: Lista de destinatarios vacía. Nadie tiene onesignal_id.");
        return;
      }

      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      final restKey = dotenv.env['ONESIGNAL_REST_API_KEY'];

      if (appId == null || restKey == null) {
        debugPrint("❌ ARGOS NOTIF: Faltan llaves en .env (APP_ID o REST_KEY)");
        return;
      }

      // 2. Llamar a la API de OneSignal (REST)
      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_player_ids': uniqueIds,
          'contents': {
            'es':
                '🆘 ¡$nombreUsuario está en una EMERGENCIA! Abre la app para ver su ubicación.',
            'en': '🆘 $nombreUsuario is in an EMERGENCY! Check the app.',
          },
          'headings': {'es': 'ALERTA ARGOS', 'en': 'ARGOS EMERGENCY'},
          'priority': 10,
          'android_group': 'argos_emergency',
          'data': {
            'type': 'emergency_alert',
            'usuario_id': user.id, // ID de quien envía la alerta
          },
        }),
      );

      if (response.statusCode == 200) {
        debugPrint("🚀 ARGOS NOTIF: ÉXITO. Respuesta: ${response.body}");
      } else {
        debugPrint(
            "❌ ARGOS NOTIF: FALLO (Status ${response.statusCode}). Body: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ ARGOS NOTIF: ERROR CRÍTICO: $e");
    }
  }

  // 6. Notificar Clasificación (v2.8.3)
  Future<void> enviarNotificacionClasificacion(String tipo,
      {bool isCancelacion = false}) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      // Obtener mi nombre
      final myProfile = await _supabase
          .from('perfiles')
          .select('nombre_completo')
          .eq('id', user.id)
          .single();
      final nombreUsuario = myProfile['nombre_completo'] ?? "Un usuario";

      final List<String> targetIds = [];
      final resG = await _supabase
          .from('circulo_confianza')
          .select('perfiles!guardian_id(onesignal_id)')
          .eq('usuario_id', user.id);
      final resP = await _supabase
          .from('circulo_confianza')
          .select('perfiles!usuario_id(onesignal_id)')
          .eq('guardian_id', user.id);

      for (var row in [...(resG as List), ...(resP as List)]) {
        final id = row['perfiles']?['onesignal_id'];
        if (id != null && id.toString().length > 5) {
          targetIds.add(id.toString());
        }
      }

      final uniqueIds = targetIds.toSet().toList();
      if (uniqueIds.isEmpty) return;

      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      final restKey = dotenv.env['ONESIGNAL_REST_API_KEY'];
      if (appId == null || restKey == null) return;

      String message;
      if (isCancelacion) {
        message = "✅ $nombreUsuario: Alerta cancelada (Falsa Alarma).";
      } else {
        message =
            "🛡️ $nombreUsuario clasificó el incidente como: ${tipo.toUpperCase()}.";
      }

      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'include_player_ids': uniqueIds,
          'contents': {'es': message, 'en': message},
          'headings': {'es': 'RESOLUCIÓN ARGOS', 'en': 'ARGOS RESOLUTION'},
          'priority': 10,
          'android_group': 'argos_closure',
        }),
      );
      debugPrint("🚀 ARGOS NOTIF CLASIFICA: ENVIADA ($message)");
    } catch (e) {
      debugPrint("❌ Error enviando notif clasificación: $e");
    }
  }

  // 7. Notificar Nueva Versión (v2.8.5 - BroadCast Global)
  Future<void> notificarNuevaVersion(String version) async {
    try {
      final appId = dotenv.env['ONESIGNAL_APP_ID'];
      final restKey = dotenv.env['ONESIGNAL_REST_API_KEY'];
      if (appId == null || restKey == null) return;

      final response = await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic $restKey',
        },
        body: jsonEncode({
          'app_id': appId,
          'included_segments': ['Total Subscriptions'], // Envío global
          'contents': {
            'es':
                '🚀 ¡Nueva versión de ARGOS disponible (v$version)! Toca aquí para actualizar y mantenerte protegido.',
            'en':
                '🚀 New ARGOS version available (v$version)! Tap here to update and stay protected.',
          },
          'headings': {
            'es': 'ACTUALIZACIÓN DISPONIBLE',
            'en': 'UPDATE AVAILABLE'
          },
          'priority': 10,
          'android_group': 'argos_updates',
          'data': {
            'type': 'app_update', // Gatilla Deep Link en main.dart
          },
        }),
      );

      debugPrint("🚀 ARGOS BROADCAST UPDATE: ${response.statusCode}");
    } catch (e) {
      debugPrint("❌ Error en broadcast de actualización: $e");
    }
  }

  // 8. ACTUALIZAR MI UBICACIÓN EN TIEMPO REAL
  Future<void> actualizarUbicacion(double lat, double lng) async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      await _supabase.from('perfiles').update({
        'latitud': lat,
        'longitud': lng,
        'ultima_conexion': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', user.id);
    } catch (e) {
      debugPrint("Error actualizando ubicación: $e");
    }
  }

  // 7. STREAM DE UBICACIONES DEL CÍRCULO
  // Optimizado para escalabilidad: Solo escucha cambios en los IDs proporcionados
  Stream<List<Map<String, dynamic>>> streamUbicacionesCirculo(
      List<String> ids) {
    if (ids.isEmpty) return Stream.value([]);

    // Filtramos por IDs en el stream de Supabase (más eficiente)
    return _supabase
        .from('perfiles')
        .stream(primaryKey: ['id'])
        .order('nombre_completo')
        .map((data) {
          // Aunque el stream trae todo el canal, el map filtra rápidamente
          // Usamos un Set para búsquedas O(1)
          final idSet = ids.toSet();
          return data.where((p) => idSet.contains(p['id'])).toList();
        });
  }

  // Método auxiliar para obtener IDs de guardianes y protegidos en una sola lista
  Future<List<String>> obtenerTodosLosIdsDelCirculo() async {
    final user = _supabase.auth.currentUser;
    if (user == null) return [];

    try {
      // Obtener guardianes
      final resGuardianes = await _supabase
          .from('circulo_confianza')
          .select('guardian_id')
          .eq('usuario_id', user.id);

      // Obtener protegidos
      final resProtegidos = await _supabase
          .from('circulo_confianza')
          .select('usuario_id')
          .eq('guardian_id', user.id);

      final List<String> ids = [];
      for (var row in (resGuardianes as List)) {
        if (row['guardian_id'] != null) ids.add(row['guardian_id']);
      }
      for (var row in (resProtegidos as List)) {
        if (row['usuario_id'] != null) ids.add(row['usuario_id']);
      }

      return ids.toSet().toList(); // Eliminar duplicados si los hay
    } catch (e) {
      debugPrint("Error obteniendo IDs del círculo: $e");
      return [];
    }
  }

  // 8. ENVIAR NOTIFICACIÓN COMUNITARIA POR PROXIMIDAD (Geofencing)
  Future<void> enviarNotificacionComunitaria(
    double lat,
    double lng,
    String mensaje,
  ) async {
    try {
      // Definimos un radio aproximado de 1km (aprox 0.009 grados)
      const double delta = 0.009;

      final res = await _supabase
          .from('perfiles')
          .select('onesignal_id')
          .gte('latitud', lat - delta)
          .lte('latitud', lat + delta)
          .gte('longitud', lng - delta)
          .lte('longitud', lng + delta);

      final List<String> targetIds = (res as List)
          .map((e) => e['onesignal_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (targetIds.isEmpty) return;

      await http.post(
        Uri.parse('https://onesignal.com/api/v1/notifications'),
        headers: {
          'Content-Type': 'application/json; charset=utf-8',
          'Authorization': 'Basic ${dotenv.env['ONESIGNAL_REST_API_KEY']}',
        },
        body: jsonEncode({
          'app_id': dotenv.env['ONESIGNAL_APP_ID'],
          'include_player_ids': targetIds,
          'contents': {'es': '⚠️ PELIGRO CERCA: $mensaje'},
          'headings': {'es': 'ALERTA COMUNITARIA ARGOS'},
          'priority': 5,
        }),
      );
    } catch (e) {
      debugPrint("Error en enviarNotificacionComunitaria: $e");
    }
  }

  // 8. OBTENER SANTUARIOS REALES (OVERPASS API - OSM)
  // Busca Police, Hospital, Pharmacy, etc., en un radio alrededor de la posición.
  Future<List<SanctuaryModel>> obtenerSantuariosReales(LatLng position) async {
    try {
      final double lat = position.latitude;
      final double lng = position.longitude;
      const double radius = 3000; // 3km de búsqueda

      // Query Overpass: Buscamos amenities de seguridad, salud y conveniencia (v2.9.3)
      final String query = """
      [out:json][timeout:30];
      (
        nwr["amenity"~"police|hospital|doctors|pharmacy|clinic|school|university|college|place_of_worship|fire_station"](around:$radius,$lat,$lng);
        nwr["healthcare"~"hospital|clinic|doctors"](around:$radius,$lat,$lng);
        nwr["shop"~"supermarket|convenience"](around:$radius,$lat,$lng);
        nwr["leisure"~"park"](around:$radius,$lat,$lng);
      );
      out center;
      """;

      final url = Uri.parse('https://overpass-api.de/api/interpreter');
      debugPrint("📡 ARGOS SCAN: Solicitando Santuarios Reales a Overpass...");

      final response = await http.post(
        url,
        body: {'data': query},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List<dynamic> elements = data['elements'] ?? [];
        List<SanctuaryModel> realSanctuaries = [];

        for (var e in elements) {
          final tags = e['tags'] ?? {};
          final String name = tags['name'] ??
              tags['operator'] ??
              tags['brand'] ??
              "Lugar de Refugio";

          double? eLat =
              e['lat']?.toDouble() ?? e['center']?['lat']?.toDouble();
          double? eLng =
              e['lon']?.toDouble() ?? e['center']?['lon']?.toDouble();

          if (eLat == null || eLng == null) continue;

          // v2.11.0: Construir dirección amigable
          final street = tags['addr:street'] ?? "";
          final houseNumber = tags['addr:housenumber'] ?? "";
          final city = tags['addr:city'] ?? "";
          String? address;
          if (street.isNotEmpty) {
            address = "$street $houseNumber".trim();
            if (city.isNotEmpty) address += ", $city";
          }

          // Mapeo dinámico a iconos de ARGOS
          final SanctuaryType type = _mapOsmToArgosType(tags);

          realSanctuaries.add(SanctuaryModel(
            name,
            LatLng(eLat, eLng),
            type,
            address: address,
          ));
        }

        debugPrint(
            "✅ ARGOS SCAN: Se encontraron ${realSanctuaries.length} santuarios reales.");

        // Actualizar Caché Global
        cacheSantuarios = realSanctuaries;
        ultimaPosicionSantuarios = position;

        // v2.13.1: Persistir en disco
        guardarCacheSantuarios();

        return realSanctuaries;
      } else {
        debugPrint(
            "❌ ARGOS SCAN: Error en Overpass (Status ${response.statusCode})");
      }
    } catch (e) {
      debugPrint("❌ ARGOS SCAN: Excepción: $e");
    }
    return [];
  }

  SanctuaryType _mapOsmToArgosType(Map<String, dynamic> tags) {
    final amenity = tags['amenity']?.toString();
    final shop = tags['shop']?.toString();
    final leisure = tags['leisure']?.toString();

    if (amenity == 'police') {
      return SanctuaryType.police;
    }
    if (amenity == 'hospital' || amenity == 'doctors' || amenity == 'clinic') {
      return SanctuaryType.health;
    }
    if (amenity == 'pharmacy') {
      return SanctuaryType.pharmacy;
    }
    if (amenity == 'school' ||
        amenity == 'university' ||
        amenity == 'college') {
      return SanctuaryType.education;
    }
    if (shop == 'supermarket' || shop == 'convenience') {
      return SanctuaryType.store;
    }
    if (leisure == 'park') {
      return SanctuaryType.park;
    }
    if (amenity == 'place_of_worship') {
      return SanctuaryType.church;
    }

    return SanctuaryType.store; // Default
  }

  // 8. STREAM DE ALERTAS RECIENTES DEL CÍRCULO (v2.6.0)
  // Escucha alertas de miembros específicos ocurridas en la última hora
  Stream<List<Map<String, dynamic>>> streamAlertasRecientesCirculo(
      List<String> ids) {
    if (ids.isEmpty) return Stream.value([]);

    final oneHourAgo = DateTime.now()
        .toUtc()
        .subtract(const Duration(hours: 1))
        .toIso8601String();

    return _supabase
        .from('alertas')
        .stream(primaryKey: ['id'])
        .order('fecha', ascending: false)
        .map((data) {
          final idSet = ids.toSet();
          return data.where((a) {
            final String? userId = a['usuario_id'];
            final String? fecha = a['fecha'];
            if (userId == null || fecha == null) return false;

            // Filtro por ID de miembro y por tiempo (1 hora)
            return idSet.contains(userId) && fecha.compareTo(oneHourAgo) >= 0;
          }).toList();
        });
  }
}
