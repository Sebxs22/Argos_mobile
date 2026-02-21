import 'package:flutter/material.dart';
import 'package:ota_update/ota_update.dart';
import 'glass_box.dart';

class UpdateProgressDialog extends StatefulWidget {
  final String downloadUrl;
  final String version;
  final bool isRequired;

  const UpdateProgressDialog({
    super.key,
    required this.downloadUrl,
    required this.version,
    required this.isRequired,
  });

  @override
  State<UpdateProgressDialog> createState() => _UpdateProgressDialogState();
}

class _UpdateProgressDialogState extends State<UpdateProgressDialog> {
  double _progress = 0;
  String _status = "Preparando descarga...";
  bool _isDownloading = false;

  void _startDownload() {
    setState(() {
      _isDownloading = true;
      _status = "Descargando v${widget.version}...";
    });

    try {
      OtaUpdate().execute(widget.downloadUrl).listen(
        (OtaEvent event) {
          setState(() {
            _progress = double.tryParse(event.value ?? "0") ?? 0;

            switch (event.status) {
              case OtaStatus.DOWNLOADING:
                _status = "Descargando: ${_progress.toInt()}%";
                break;
              case OtaStatus.INSTALLING:
                _status = "Instalando actualización...";
                break;
              case OtaStatus.ALREADY_RUNNING_ERROR:
                _status = "Ya hay una descarga en curso.";
                break;
              case OtaStatus.PERMISSION_NOT_GRANTED_ERROR:
                _status = "Error: Permisos denegados.";
                break;
              default:
                _status = "Error en la actualización.";
            }
          });
        },
        onError: (e) {
          setState(() {
            _status = "Error: $e";
            _isDownloading = false;
          });
        },
      );
    } catch (e) {
      setState(() {
        _status = "Error inesperado: $e";
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !widget.isRequired && !_isDownloading,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: GlassBox(
            borderRadius: 30,
            opacity: 0.1,
            blur: 20,
            padding: const EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.auto_awesome,
                  color: Color(0xFFE53935),
                  size: 60,
                ),
                const SizedBox(height: 15),
                Text(
                  "Nueva Versión Disponible",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white12,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "v${widget.version}",
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                if (!_isDownloading) ...[
                  const Text(
                    "Se han detectado mejoras importantes para tu seguridad en ARGOS.",
                    style: TextStyle(
                      color: Colors.white60,
                      fontSize: 14,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 35),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      gradient: const LinearGradient(
                        colors: [Color(0xFFE53935), Color(0xFFC62828)],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFE53935).withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: _startDownload,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(double.infinity, 60),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      ),
                      child: const Text(
                        "ACTUALIZAR AHORA",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  Column(
                    children: [
                      Stack(
                        children: [
                          Container(
                            height: 12,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.white12,
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: 12,
                            width: (MediaQuery.of(context).size.width - 140) *
                                (_progress / 100),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFF5252), Color(0xFFE53935)],
                              ),
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: [
                                BoxShadow(
                                  color:
                                      const Color(0xFFE53935).withOpacity(0.4),
                                  blurRadius: 10,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 25),
                      Text(
                        _progress >= 100
                            ? "¡Listo! Abriendo instalador..."
                            : _status,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      if (_progress < 100)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: Text(
                            "${_progress.toInt()}% completado",
                            style: const TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
                if (!widget.isRequired && !_isDownloading)
                  Padding(
                    padding: const EdgeInsets.only(top: 15),
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        "Omitir por ahora",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.3),
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
