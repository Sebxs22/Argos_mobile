import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'package:flutter/material.dart';
import '../../features/sanctuaries/data/mock_sanctuaries_data.dart';

class ApiService {
  //final String baseUrl = "http://192.168.1.102:8000";
  final String baseUrl = 'http://192.168.182.217:8000';

  // 1. ENVIAR (POST)
  Future<void> enviarAlertaEmergencia(double lat, double long) async {
    try {
      final url = Uri.parse('$baseUrl/alertas');
      await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({
          "latitud": lat,
          "longitud": long,
          "tipo": "emergencia"
        }),
      );
    } catch (e) {
      print("Error enviando: $e");
    }
  }

  // 2. RECIBIR Y AGRUPAR (Lógica Inteligente)
  Future<List<DangerZoneModel>> obtenerAlertas() async {
    try {
      final url = Uri.parse('$baseUrl/alertas');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        List<dynamic> data = jsonDecode(response.body);
        List<DangerZoneModel> zonasAgrupadas = [];
        const Distance distanceCalc = Distance();

        // Ordenamos por fecha (del más reciente al más antiguo)
        // Esto asume que el backend manda la fecha, si no, lo dejamos como viene
        // data.sort((a, b) => b['fecha'].compareTo(a['fecha']));

        for (var item in data) {
          if (item['latitud'] == null || item['longitud'] == null) continue;

          LatLng puntoAlerta = LatLng(item['latitud'], item['longitud']);
          String fechaStr = item['fecha'] ?? DateTime.now().toIso8601String();
          String tiempoTexto = _calcularTiempoTranscurrido(fechaStr);

          // Creamos el reporte individual
          ReportModel nuevoReporte = ReportModel(
            "S.O.S. ACTIVADO",
            tiempoTexto,
            "Alerta de pánico recibida.",
            Icons.warning_amber_rounded,
          );

          // ¿Existe alguna zona cercana (menos de 100m) donde meter este reporte?
          int indexZonaCercana = -1;
          for (int i = 0; i < zonasAgrupadas.length; i++) {
            if (distanceCalc.as(LengthUnit.Meter, puntoAlerta, zonasAgrupadas[i].center) < 100) {
              indexZonaCercana = i;
              break;
            }
          }

          if (indexZonaCercana != -1) {
            // SI YA EXISTE ZONA CERCA: Agregamos el reporte a esa zona
            // (Tenemos que crear una copia nueva porque las listas suelen ser inmutables en props)
            var zonaExistente = zonasAgrupadas[indexZonaCercana];
            List<ReportModel> listaActualizada = List.from(zonaExistente.reports)..add(nuevoReporte);

            zonasAgrupadas[indexZonaCercana] = DangerZoneModel(
                center: zonaExistente.center, // Mantenemos el centro original
                radius: zonaExistente.radius,
                reports: listaActualizada
            );
          } else {
            // SI NO EXISTE: Creamos una zona nueva
            zonasAgrupadas.add(DangerZoneModel(
                center: puntoAlerta,
                radius: 200, // Radio visual del círculo rojo
                reports: [nuevoReporte]
            ));
          }
        }
        return zonasAgrupadas;
      }
    } catch (e) {
      print("Error obteniendo alertas: $e");
    }
    return [];
  }

  String _calcularTiempoTranscurrido(String fechaIso) {
    try {
      DateTime? fechaAlerta = DateTime.tryParse(fechaIso);
      if (fechaAlerta == null) return "Hora desc.";

      DateTime ahora = DateTime.now();
      Duration diferencia = ahora.difference(fechaAlerta);

      if (diferencia.isNegative) return "Hace instantes"; // Corrección de reloj
      if (diferencia.inSeconds < 60) return "Hace ${diferencia.inSeconds} seg";
      if (diferencia.inMinutes < 60) return "Hace ${diferencia.inMinutes} min";
      if (diferencia.inHours < 24) return "Hace ${diferencia.inHours} horas";
      return "Hace ${diferencia.inDays} días";
    } catch (e) {
      return "Hace instantes";
    }
  }
}


