import 'package:flutter/material.dart';
import '../../../core/ui/glass_box.dart';
import '../../../core/network/api_service.dart';
import '../../../core/utils/ui_utils.dart';

class IncidentClassificationScreen extends StatefulWidget {
  final String alertaId;
  const IncidentClassificationScreen({super.key, required this.alertaId});

  @override
  State<IncidentClassificationScreen> createState() =>
      _IncidentClassificationScreenState();
}

class _IncidentClassificationScreenState
    extends State<IncidentClassificationScreen> {
  final ApiService _apiService = ApiService();
  String? _selectedType;
  bool _isSaving = false;

  final List<Map<String, dynamic>> _incidentTypes = [
    {
      'id': 'robo',
      'label': 'Robo / Asalto',
      'icon': Icons.gavel_rounded,
      'color': Colors.redAccent
    },
    {
      'id': 'acoso',
      'label': 'Acoso / Seguimiento',
      'icon': Icons.visibility_rounded,
      'color': Colors.orangeAccent
    },
    {
      'id': 'medica',
      'label': 'Emergencia Médica',
      'icon': Icons.medical_services_rounded,
      'color': Colors.blueAccent
    },
    {
      'id': 'accidente',
      'label': 'Accidente Vial',
      'icon': Icons.car_crash_rounded,
      'color': Colors.amberAccent
    },
    {
      'id': 'otro',
      'label': 'Otro incidente',
      'icon': Icons.help_outline_rounded,
      'color': Colors.grey
    },
  ];

  Future<void> _saveClassification() async {
    if (_selectedType == null) return;

    setState(() => _isSaving = true);
    try {
      await _apiService.clasificarIncidente(widget.alertaId, _selectedType!);

      // v2.8.3: Notificar al círculo sobre la clasificación
      await _apiService.enviarNotificacionClasificacion(_selectedType!);

      if (mounted) {
        UiUtils.showSuccess(
            "Gracias por tu reporte. Ayudas a proteger la comunidad.");
        Navigator.pop(context);
      }
    } catch (e) {
      UiUtils.showError("No se pudo guardar la clasificación");
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;

    return PopScope(
      canPop: false, // v2.15.1: Bloqueo de clasificación mandatorio
      child: Scaffold(
        backgroundColor:
            isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: const Text("Clasificar Incidente",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          centerTitle: true,
          elevation: 0,
          backgroundColor: Colors.transparent,
          automaticallyImplyLeading: false, // v2.15.1: Sin botón de retroceso
        ),
        body: Padding(
          padding: const EdgeInsets.all(25.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "¿Qué sucedió?",
                style: TextStyle(
                    color: textColor,
                    fontSize: 24,
                    fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Tu reporte ayudará a otros usuarios a evitar zonas peligrosas.",
                style: TextStyle(
                    color: textColor.withValues(alpha: 0.6), fontSize: 14),
              ),
              const SizedBox(height: 30),
              Expanded(
                child: ListView.builder(
                  itemCount: _incidentTypes.length,
                  itemBuilder: (context, index) {
                    final type = _incidentTypes[index];
                    final isSelected = _selectedType == type['id'];

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 15),
                      child: GestureDetector(
                        onTap: () => setState(() => _selectedType = type['id']),
                        child: GlassBox(
                          borderRadius: 20,
                          opacity: isSelected ? 0.15 : (isDark ? 0.05 : 0.08),
                          border: isSelected
                              ? Border.all(color: Colors.blueAccent, width: 2)
                              : null,
                          padding: const EdgeInsets.all(15),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: (type['color'] as Color)
                                      .withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(type['icon'] as IconData,
                                    color: type['color'] as Color, size: 24),
                              ),
                              const SizedBox(width: 20),
                              Text(
                                type['label'] as String,
                                style: TextStyle(
                                  color: textColor,
                                  fontSize: 16,
                                  fontWeight: isSelected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                              const Spacer(),
                              if (isSelected)
                                const Icon(Icons.check_circle,
                                    color: Colors.blueAccent, size: 20),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: _selectedType == null || _isSaving
                      ? null
                      : _saveClassification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 5,
                  ),
                  child: _isSaving
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("GUARDAR REPORTE",
                          style: TextStyle(
                              fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
