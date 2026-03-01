enum FlavorEnvironment { direct, store }

class FlavorConfig {
  final FlavorEnvironment environment;
  final String appName;

  static FlavorConfig? _instance;

  factory FlavorConfig({
    required FlavorEnvironment environment,
    required String appName,
  }) {
    _instance ??= FlavorConfig._internal(environment, appName);
    return _instance!;
  }

  FlavorConfig._internal(this.environment, this.appName);

  static FlavorConfig get instance {
    if (_instance == null) {
      throw Exception(
          'FlavorConfig was not initialized! Please call constructor first.');
    }
    return _instance!;
  }

  bool get isDirectFlavor => environment == FlavorEnvironment.direct;
  bool get isStoreFlavor => environment == FlavorEnvironment.store;
}
