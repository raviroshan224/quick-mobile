import 'package:flutter_test/flutter_test.dart';
import 'package:salon_pos/core/utils/env_config.dart';

void main() {
  group('EnvConfig', () {
    test('uses localhost for dev and Railway for prod', () {
      EnvConfig.init(Flavor.dev);
      expect(EnvConfig.instance.apiBaseUrl, 'http://localhost:3000');

      EnvConfig.init(Flavor.prod);
      expect(
        EnvConfig.instance.apiBaseUrl,
        'https://api.quick.com.np',
      );
    });
  });
}
