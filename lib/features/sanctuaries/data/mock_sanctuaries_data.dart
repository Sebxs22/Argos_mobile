import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

// --- MODELOS ---
enum SanctuaryType { police, health, education, store, park, pharmacy, church }

class SanctuaryModel {
  final String name;
  final LatLng location;
  final SanctuaryType type;
  const SanctuaryModel(this.name, this.location, this.type);
}

class ReportModel {
  final String title;
  final String timeAgo;
  final String description;
  final IconData icon;
  const ReportModel(this.title, this.timeAgo, this.description, this.icon);
}

class DangerZoneModel {
  final LatLng center;
  final double radius;
  final List<ReportModel> reports;
  const DangerZoneModel({required this.center, required this.radius, required this.reports});
}

// --- BASE DE DATOS DE SANTUARIOS (FIJOS) ---
// Solo dejamos los lugares seguros permanentes.
final List<SanctuaryModel> kSanctuariesDB = [
  // SALUD
  SanctuaryModel("Hosp. Docente", LatLng(-1.6765, -78.6542), SanctuaryType.health),
  SanctuaryModel("Hosp. IESS", LatLng(-1.6582, -78.6485), SanctuaryType.health),
  SanctuaryModel("Clínica Metropolitana", LatLng(-1.6650, -78.6520), SanctuaryType.health),
  SanctuaryModel("Centro Salud Lizarzaburu", LatLng(-1.6480, -78.6600), SanctuaryType.health),

  // SEGURIDAD
  SanctuaryModel("Comando Policía", LatLng(-1.6600, -78.6550), SanctuaryType.police),
  SanctuaryModel("UPC Terminal", LatLng(-1.6555, -78.6610), SanctuaryType.police),
  SanctuaryModel("UPC Politécnica", LatLng(-1.6640, -78.6790), SanctuaryType.police),
  SanctuaryModel("UPC Centro", LatLng(-1.6680, -78.6580), SanctuaryType.police),
  SanctuaryModel("UPC San Antonio", LatLng(-1.6450, -78.6500), SanctuaryType.police),

  // EDUCACIÓN
  SanctuaryModel("ESPOCH", LatLng(-1.6635, -78.6780), SanctuaryType.education),
  SanctuaryModel("UNACH", LatLng(-1.6510, -78.6415), SanctuaryType.education),
  SanctuaryModel("Col. Maldonado", LatLng(-1.6720, -78.6480), SanctuaryType.education),

  // FARMACIAS
  SanctuaryModel("Fybeca Centro", LatLng(-1.6710, -78.6480), SanctuaryType.pharmacy),
  SanctuaryModel("SanaSana Norte", LatLng(-1.6520, -78.6550), SanctuaryType.pharmacy),

  // SITIOS PÚBLICOS
  SanctuaryModel("Parque Sucre", LatLng(-1.6709, -78.6471), SanctuaryType.park),
  SanctuaryModel("Parque Infantil", LatLng(-1.6650, -78.6490), SanctuaryType.park),
  SanctuaryModel("Iglesia La Basílica", LatLng(-1.6730, -78.6460), SanctuaryType.church),

  // COMERCIO
  SanctuaryModel("Paseo Shopping", LatLng(-1.6800, -78.6650), SanctuaryType.store),
  SanctuaryModel("Multiplaza", LatLng(-1.6500, -78.6550), SanctuaryType.store),
];
