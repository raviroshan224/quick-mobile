import '../constants/app_constants.dart';

enum Flavor { dev, staging, prod }

class EnvConfig {
  const EnvConfig._({required this.flavor, required this.apiBaseUrl});

  final Flavor flavor;
  final String apiBaseUrl;

  static EnvConfig? _instance;

  static EnvConfig get instance {
    assert(_instance != null, 'EnvConfig.init() must be called before use');
    return _instance!;
  }

  static void init(Flavor flavor) {
    _instance = switch (flavor) {
      Flavor.dev => const EnvConfig._(
        flavor: Flavor.dev,
        apiBaseUrl: AppConstants.devBaseUrl,
      ),
      Flavor.staging => const EnvConfig._(
        flavor: Flavor.staging,
        apiBaseUrl: AppConstants.prodBaseUrl,
      ),
      Flavor.prod => const EnvConfig._(
        flavor: Flavor.prod,
        apiBaseUrl: AppConstants.prodBaseUrl,
      ),
    };
  }

  bool get isDev => flavor == Flavor.dev;
  bool get isProd => flavor == Flavor.prod;
}
