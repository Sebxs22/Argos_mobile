import 'dart:async';
import 'package:sensors_plus/sensors_plus.dart';

class SensorHandler {
  StreamSubscription<UserAccelerometerEvent>? _subscription;
  final double threshold =
      25.0; // Umbral para detectar movimientos bruscos [cite: 29]

  void startMonitoring(Function onAlert) {
    _subscription = userAccelerometerEventStream().listen((
      UserAccelerometerEvent event,
    ) {
      // Cálculo de aceleración lineal total
      double acceleration = event.x.abs() + event.y.abs() + event.z.abs();

      if (acceleration > threshold) {
        onAlert(); // Dispara la alerta si detecta el movimiento [cite: 30]
      }
    });
  }

  void stopMonitoring() {
    _subscription?.cancel();
  }
}
