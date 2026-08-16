import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Replaces Flutter's default red/grey error box wherever a widget throws
/// during build. Installed globally via `ErrorWidget.builder` in main.dart —
/// scoped to just the failing subtree, so one broken widget doesn't take an
/// entire screen down with it. Deliberately self-contained (doesn't assume a
/// Material/Scaffold ancestor, since it can be inserted anywhere a widget
/// fails to build) so it always renders something legible rather than
/// risking a second failure while trying to display the first one.
class AppErrorFallback extends StatelessWidget {
  const AppErrorFallback({super.key, required this.details});

  final FlutterErrorDetails details;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surfaceVariant,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: AppColors.textTertiary,
                size: 32,
              ),
              const SizedBox(height: 12),
              const Text(
                'Something went wrong displaying this.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              if (kDebugMode) ...[
                const SizedBox(height: 8),
                Text(
                  details.exceptionAsString(),
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.danger, fontSize: 11),
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
