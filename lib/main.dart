import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/env_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  EnvConfig.init(Flavor.dev);
  runApp(const ProviderScope(child: SalonPosApp()));
}

class SalonPosApp extends ConsumerWidget {
  const SalonPosApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Quick POS',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: router,
    );
  }
}
