import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/env_config.dart';
import 'core/widgets/offline_banner.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  const useProdApi = bool.fromEnvironment(
    'USE_PROD_API',
    defaultValue: kReleaseMode,
  );
  EnvConfig.init(useProdApi ? Flavor.prod : Flavor.dev);
  runApp(const ProviderScope(child: SalonPosApp()));
}

class SalonPosApp extends ConsumerWidget {
  const SalonPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Quick',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
      builder: (context, child) =>
          OfflineBanner(child: child ?? const SizedBox.shrink()),
    );
  }
}
