import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import SharedPreferences
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Import dotenv

// --- IMPORTANTE: Asegúrate de que esta ruta sea correcta según tu proyecto ---
import '../../features/sanctuaries/data/mock_sanctuaries_data.dart';
import '../utils/ui_utils.dart'; // Import UiUtils

class ApiService {
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

      return response['id'] as String;
    } catch (e) {
      UiUtils.showError("Error al enviar alerta: $e");
      return null;
    }
  }

  // Método para clasificar el incidente
  Future<void> clasificarIncidente(String alertaId, String tipo) async {
    try {
      await _supabase.from('alertas').update({'tipo': tipo}).eq('id', alertaId);
    } catch (e) {
      debugPrint("Error clasificando incidente: $e");
      throw Exception("Error al clasificar incidente");
    }
  }

  // Método para cancelar una alerta (En caso de falso positivo)
  Future<void> cancelarAlerta(String alertaId) async {
    try {
      await _supabase.from('alertas').delete().eq('id', alertaId);
      UiUtils.showSuccess("Alerta cancelada correctamente");
    } catch (e) {
      debugPrint("Error cancelando alerta: $e");
    }
  }

  // 2. OBTENER ALERTAS CON AGRUPAMIENTO INTELIGENTE Y CACHÉ
  // Trae los datos de la nube y une reportes cercanos en una sola "Zona de Riesgo".
  Future<List<DangerZoneModel>> obtenerAlertas() async {
    final prefs = await SharedPreferences.getInstance();
    const String cacheKey = 'cached_danger_zones';

    List<dynamic> data = [];

    // Intentar obtener de RED
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

      data = remoteData;
      // Guardar en caché
      prefs.setString(cacheKey, jsonEncode(remoteData));
    } catch (e) {
      debugPrint("⚠️ Sin conexión a Supabase. Usando caché local.");
      // Fallback a CACHÉ
      if (prefs.containsKey(cacheKey)) {
        data = jsonDecode(prefs.getString(cacheKey)!);
        UiUtils.showWarning("Modo Offline: Mostrando alertas guardadas");
      } else {
        return [];
      }
    }

    try {
      List<DangerZoneModel> zonasAgrupadas = [];
      const Distance distanceCalc = Distance();

      for (var item in data) {
        if (item['latitud'] == null || item['longitud'] == null) continue;

        LatLng puntoAlerta = LatLng(item['latitud'], item['longitud']);
        String fechaStr = item['fecha'] ?? "";
        String tiempoTexto = _calcularTiempoTranscurrido(fechaStr);
        String tipo = item['tipo'] ?? "ALERTA";

        ReportModel nuevoReporte = ReportModel(
          tipo.toUpperCase(),
          tiempoTexto,
          item['mensaje'] ?? "Alerta de seguridad",
          Icons.warning_amber_rounded,
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
          // Agregar al historial de la zona existente
          var zonaExistente = zonasAgrupadas[indexZonaCercana];
          List<ReportModel> listaActualizada = List.from(zonaExistente.reports)
            ..add(nuevoReporte);

          zonasAgrupadas[indexZonaCercana] = DangerZoneModel(
            center: zonaExistente.center,
            radius: zonaExistente.radius,
            reports: listaActualizada,
          );
        } else {
          // Crear una zona nueva
          zonasAgrupadas.add(
            DangerZoneModel(
              center: puntoAlerta,
              radius: 150, // Radio visual en metros
              reports: [nuevoReporte],
            ),
          );
        }
      }
      return zonasAgrupadas;
    } catch (e) {
      debugPrint("Error procesando alertas: $e");
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
      // CONVERSIÓN A PERFILES CORRECTOS DE OSRM
      String perfilOSRM;
      switch (modo) {
        case 'car':
          perfilOSRM = 'driving';
          break;
        case 'foot':
          perfilOSRM = 'foot-walking';
          break;
        case 'bicycle':
          perfilOSRM = 'cycling';
          break;
        default:
          perfilOSRM = 'foot-walking';
      }

      final url = Uri.parse(
        'https://router.project-osrm.org/route/v1/$perfilOSRM/${origen.longitude},${origen.latitude};${destino.longitude},${destino.latitude}?overview=full&geometries=geojson',
      );

      debugPrint("🚀 Consultando OSRM con perfil: $perfilOSRM");
      debugPrint("📍 URL: $url");

      final response = await http.get(url);

      if (response.statusCode != 200) {
        debugPrint("❌ Error HTTP ${response.statusCode}: ${response.body}");
        return {
          'error': 'Error en servicio de mapas (HTTP ${response.statusCode})',
        };
      }

      final data = jsonDecode(response.body);

      if (data['routes'] == null || data['routes'].isEmpty) {
        debugPrint("❌ No se encontraron rutas en la respuesta");
        return {'error': 'No se encontró una ruta válida'};
      }

      final List<dynamic> coordinates =
          data['routes'][0]['geometry']['coordinates'];
      List<LatLng> points = coordinates.map((c) => LatLng(c[1], c[0])).toList();

      final double duracion = (data['routes'][0]['duration'] ?? 0).toDouble();
      final double distancia = (data['routes'][0]['distance'] ?? 0).toDouble();

      debugPrint(
        "⏱️ Duración: $duracion segundos (${(duracion / 60).toStringAsFixed(1)} min)",
      );
      debugPrint(
        "📏 Distancia: $distancia metros (${(distancia / 1000).toStringAsFixed(2)} km)",
      );

      final alertas = await obtenerAlertas();
      int puntosDeRiesgo = 0;
      const Distance distance = Distance();

      for (var puntoRuta in points) {
        for (var zona in alertas) {
          if (distance.as(LengthUnit.Meter, puntoRuta, zona.center) <
              zona.radius) {
            puntosDeRiesgo++;
          }
        }
      }

      double score = 100 - (puntosDeRiesgo * 1.5);
      if (score < 0) score = 0;

      debugPrint(
        "✅ Ruta calculada - Score: $score, Puntos de riesgo: $puntosDeRiesgo",
      );

      return {
        'points': points,
        'score': score,
        'duracion': duracion,
        'distancia': distancia,
      };
    } catch (e) {
      debugPrint("❌ Excepción en calcularRutaSegura: $e");
      return {'error': e.toString()};
    }
  }

  // 5. TRADUCTOR DE TIEMPO (RELATIVO)
  // Corrige el desfase de 5 horas y devuelve texto amigable.
  String _calcularTiempoTranscurrido(String fechaIso) {
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

  // 5. ENVIAR NOTIFICACIÓN PUSH A GUARDIANES
  Future<void> enviarNotificacionEmergencia(String nombreUsuario) async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      // 1. Obtener IDs de OneSignal de mis guardianes
      final res = await Supabase.instance.client
          .from('circulo_confianza')
          .select('perfiles!guardian_id(onesignal_id)')
          .eq('usuario_id', user.id);

      final List<String> targetIds = (res as List)
          .map((e) => e['perfiles']['onesignal_id'] as String?)
          .where((id) => id != null && id.isNotEmpty)
          .cast<String>()
          .toList();

      if (targetIds.isEmpty) {
        debugPrint("⚠️ No hay guardianes con OneSignal ID para notificar.");
        return;
      }

      // 2. Llamar a la API de OneSignal (REST)
      final response = await http.post(
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
                '🆘 ¡$nombreUsuario está en una EMERGENCIA! Abre la app para ver su ubicación.',
            'en': '🆘 $nombreUsuario is in an EMERGENCY! Check the app.',
          },
          'headings': {'es': 'ALERTA ARGOS', 'en': 'ARGOS EMERGENCY'},
          'priority': 10, // Alta prioridad
        }),
      );

      if (response.statusCode == 200) {
        debugPrint(
          "🚀 Notificaciones enviadas correctamente a ${targetIds.length} guardianes.",
        );
      } else {
        debugPrint("❌ Error al enviar notificación: ${response.body}");
      }
    } catch (e) {
      debugPrint("❌ Error en enviarNotificacionEmergencia: $e");
    }
  }

  // 6. ACTUALIZAR MI UBICACIÓN EN TIEMPO REAL
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
}
