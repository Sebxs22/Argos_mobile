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
      OtaUpdate()
          .execute(widget.downloadUrl)
          .listen(
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
                  Icons.system_update_alt,
                  color: Color(0xFFE53935),
                  size: 50,
                ),
                const SizedBox(height: 20),
                Text(
                  "Actualización Disponible",
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                Text(
                  "Versión v${widget.version}",
                  style: const TextStyle(color: Colors.white70, fontSize: 14),
                ),
                const SizedBox(height: 25),
                if (!_isDownloading) ...[
                  const Text(
                    "Se recomienda actualizar para contar con las últimas mejoras de seguridad.",
                    style: TextStyle(color: Colors.white54, fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _startDownload,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE53935),
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    child: const Text("ACTUALIZAR AHORA"),
                  ),
                ] else ...[
                  LinearProgressIndicator(
                    value: _progress / 100,
                    backgroundColor: Colors.white12,
                    color: const Color(0xFFE53935),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    _status,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ],
                if (!widget.isRequired && !_isDownloading)
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Más tarde",
                      style: TextStyle(color: Colors.white38),
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
