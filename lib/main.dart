import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/env_config.dart';
import 'core/widgets/app_error_fallback.dart';
import 'core/widgets/offline_banner.dart';
import 'features/cash_drawer_hardware/presentation/widgets/cash_drawer_overlay.dart';

void main() {
  // Previously there was no top-level error boundary at all: an uncaught
  // exception anywhere (a bad widget build, an unhandled async error)
  // fell through to Flutter's default behavior — a jarring red/grey screen
  // in the best case, or a silently-dropped async error and a frozen UI in
  // the worst case, with no logging and no way to recover short of a
  // manual restart, potentially mid-transaction.
  //
  // Two complementary hooks are needed to actually cover this:
  //  - ErrorWidget.builder replaces the fallback shown for a widget that
  //    throws *during build* — scoped to just the failing subtree, so a
  //    broken widget doesn't take the rest of the screen down with it.
  //  - runZonedGuarded + PlatformDispatcher.onError catch errors from
  //    *outside* the widget build pipeline (e.g. an unawaited/uncaught
  //    Future rejection) that would otherwise vanish silently or crash the
  //    isolate. WidgetsFlutterBinding.ensureInitialized() and runApp() must
  //    run inside the same zone per Flutter's own guidance, to avoid a
  //    zone-mismatch assertion.
  ErrorWidget.builder = (details) => AppErrorFallback(details: details);

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
    return true;
  };

  runZonedGuarded(() {
    WidgetsFlutterBinding.ensureInitialized();
    const useProdApi = bool.fromEnvironment(
      'USE_PROD_API',
      defaultValue: kReleaseMode,
    );
    EnvConfig.init(useProdApi ? Flavor.prod : Flavor.dev);

    runApp(
      const ProviderScope(child: SalonPosApp()),
    );
  }, (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  });
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
      builder: (context, child) => CashDrawerOverlay(
        child: OfflineBanner(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}
