import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';

/// Standard pull-to-refresh wrapper used across every data screen so the
/// indicator's color and behavior stay consistent app-wide.
///
/// [child] must contain a scrollable descendant (ListView/GridView/
/// SingleChildScrollView/CustomScrollView) with `AlwaysScrollableScrollPhysics`
/// so the pull gesture still works when content is shorter than the viewport.
class PullToRefresh extends StatelessWidget {
  const PullToRefresh({super.key, required this.onRefresh, required this.child});

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primary,
      child: child,
    );
  }
}
