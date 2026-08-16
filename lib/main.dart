import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/env_config.dart';
import 'core/widgets/app_error_fallback.dart';
import 'core/widgets/offline_banner.dart';
import 'features/pos/presentation/providers/salon_sessions_provider.dart';

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

  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    const useProdApi = bool.fromEnvironment(
      'USE_PROD_API',
      defaultValue: kReleaseMode,
    );
    EnvConfig.init(useProdApi ? Flavor.prod : Flavor.dev);

    // Salon sessions (and their carts) are restored from on-device storage
    // before the first frame, using a manually-created container so
    // loadPersisted() can run to completion first — this is the one piece
    // of app state that must never flash a default/empty value before the
    // real one loads, since that default value is itself a real (if empty)
    // session a cashier could otherwise start typing into. See
    // SalonSessionsNotifier for what's actually restored and
    // salon_sessions_storage.dart for where it's stored; see
    // _SalonPosAppState below for when it's saved back.
    final container = ProviderContainer();
    await container.read(salonSessionsProvider.notifier).loadPersisted();

    runApp(
      UncontrolledProviderScope(
        container: container,
        child: const SalonPosApp(),
      ),
    );
  }, (error, stack) {
    FlutterError.reportError(FlutterErrorDetails(exception: error, stack: stack));
  });
}

class SalonPosApp extends ConsumerStatefulWidget {
  const SalonPosApp({super.key});

  @override
  ConsumerState<SalonPosApp> createState() => _SalonPosAppState();
}

class _SalonPosAppState extends ConsumerState<SalonPosApp> with WidgetsBindingObserver {
  Timer? _autosaveTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Backstop for a true crash (no lifecycle callback fires): cart
    // *contents* change through the separate per-session CartNotifier
    // instances, which SalonSessionsNotifier has no way to observe
    // directly, so periodic saves are how those reach disk short of an
    // app-lifecycle event. 30s is frequent enough that a hard kill loses at
    // most half a minute of edits, without meaningfully increasing disk I/O
    // for a POS app that isn't otherwise write-heavy.
    _autosaveTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      ref.read(salonSessionsProvider.notifier).persistNow();
    });
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // paused/inactive fire reliably when the app is backgrounded or the OS
    // is about to reclaim it — the realistic "app closes unexpectedly"
    // case for a tablet left at reception, unlike a true native crash.
    if (state == AppLifecycleState.paused || state == AppLifecycleState.inactive) {
      ref.read(salonSessionsProvider.notifier).persistNow();
    }
  }

  @override
  Widget build(BuildContext context) {
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
