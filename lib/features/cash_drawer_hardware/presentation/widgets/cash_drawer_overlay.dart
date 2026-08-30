import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/cash_drawer_settings_repository.dart';
import '../../domain/printer_connection_config.dart';
import '../providers/cash_drawer_action_provider.dart';
import '../providers/cash_drawer_settings_provider.dart';

/// Floating cash-drawer button, shown above every screen once the owner
/// has turned it on and configured a printer connection.
///
/// Lives outside the `Navigator` subtree (wraps it, in `main.dart`'s
/// `MaterialApp.router.builder`) so drag state and position persist across
/// route changes instead of being rebuilt per screen.
class CashDrawerOverlay extends ConsumerStatefulWidget {
  const CashDrawerOverlay({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CashDrawerOverlay> createState() => _CashDrawerOverlayState();
}

class _CashDrawerOverlayState extends ConsumerState<CashDrawerOverlay> {
  static const _buttonSize = 56.0;
  static const _edgeMargin = 12.0;
  static const _repositionHoldDuration = Duration(milliseconds: 1500);

  bool _dragging = false;
  Offset? _dragTopLeft;

  @override
  Widget build(BuildContext context) {
    ref.listen<CashDrawerActionState>(cashDrawerActionProvider, (previous, next) {
      if (next.status == CashDrawerActionStatus.error) {
        _showFailureSnackBar(next.result);
      }
    });

    final isAuthenticated = ref.watch(authProvider).isAuthenticated;
    final settings = ref.watch(cashDrawerSettingsProvider);
    final visible =
        isAuthenticated && settings.enabled && (settings.connection?.isValid ?? false);

    return Stack(
      children: [
        widget.child,
        if (visible) _buildButton(context, settings),
      ],
    );
  }

  Widget _buildButton(BuildContext context, CashDrawerSettings settings) {
    final mq = MediaQuery.of(context);
    final bounds = _dragBounds(mq);

    final Offset topLeft = _dragging && _dragTopLeft != null
        ? _dragTopLeft!
        : _clampToBounds(_savedOrDefaultTopLeft(settings, mq), bounds);

    final actionState = ref.watch(cashDrawerActionProvider);

    return Positioned(
      left: topLeft.dx,
      top: topLeft.dy,
      // Tight size, matching what _dragBounds/_savedOrDefaultTopLeft assume
      // this button occupies — the hold-progress ring visually overflows
      // past this box (see OverflowBox in _DrawerButtonVisual) without
      // changing the footprint Positioned/the drag math anchor against.
      width: _buttonSize,
      height: _buttonSize,
      child: _DrawerButtonGestures(
        size: _buttonSize,
        holdDuration: _repositionHoldDuration,
        status: actionState.status,
        onTap: () {
          HapticFeedback.mediumImpact();
          ref.read(cashDrawerActionProvider.notifier).open();
        },
        onLongPressStart: () {
          HapticFeedback.heavyImpact();
          setState(() {
            _dragging = true;
            _dragTopLeft = topLeft;
          });
        },
        onLongPressMoveDelta: (delta) {
          setState(() {
            _dragTopLeft = _clampToBounds(_dragTopLeft! + delta, bounds);
          });
        },
        onLongPressEnd: () {
          final finalPos = _dragTopLeft;
          setState(() => _dragging = false);
          if (finalPos == null) return;
          ref.read(cashDrawerSettingsProvider.notifier).setButtonPosition(
                CashDrawerButtonPosition(
                  dx: finalPos.dx / mq.size.width,
                  dy: finalPos.dy / mq.size.height,
                ),
              );
        },
      ),
    );
  }

  ({Offset min, Offset max}) _dragBounds(MediaQueryData mq) {
    final min = Offset(
      mq.padding.left + _edgeMargin,
      mq.padding.top + _edgeMargin,
    );
    final max = Offset(
      mq.size.width - _buttonSize - mq.padding.right - _edgeMargin,
      mq.size.height - _buttonSize - mq.padding.bottom - _edgeMargin,
    );
    return (min: min, max: max);
  }

  Offset _clampToBounds(Offset offset, ({Offset min, Offset max}) bounds) {
    final maxDx = bounds.max.dx < bounds.min.dx ? bounds.min.dx : bounds.max.dx;
    final maxDy = bounds.max.dy < bounds.min.dy ? bounds.min.dy : bounds.max.dy;
    return Offset(
      offset.dx.clamp(bounds.min.dx, maxDx),
      offset.dy.clamp(bounds.min.dy, maxDy),
    );
  }

  Offset _savedOrDefaultTopLeft(CashDrawerSettings settings, MediaQueryData mq) {
    final saved = settings.buttonPosition;
    if (saved != null) {
      return Offset(saved.dx * mq.size.width, saved.dy * mq.size.height);
    }
    // Default: bottom-right, clear of the bottom nav bar.
    return Offset(
      mq.size.width - _buttonSize - _edgeMargin * 2,
      mq.size.height - _buttonSize - mq.padding.bottom - 140,
    );
  }

  void _showFailureSnackBar(CashDrawerResult? result) {
    if (!mounted) return;
    final message = switch (result?.reason) {
      CashDrawerFailureReason.notConfigured =>
        "Cash drawer isn't set up yet — configure it in Settings.",
      CashDrawerFailureReason.connectionFailed =>
        "Couldn't reach the printer — check it's powered on and connected.",
      CashDrawerFailureReason.writeFailed => 'Connected, but the drawer failed to open.',
      _ => "Couldn't open the drawer — try again.",
    };
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }
}

// Built on raw pointer events rather than Tap/LongPressGestureRecognizer:
// LongPressGestureRecognizer hardcodes a ~18px (kTouchSlop) "pre-accept"
// movement tolerance with no way to configure it through its public
// constructor — real fingers drift more than that over a 1.5s hold, which
// silently cancels the gesture before it ever starts. Handling pointer
// events directly lets the hold survive that pre-activation jitter (only
// tracking movement for drag purposes once the hold has actually fired).
class _DrawerButtonGestures extends StatefulWidget {
  const _DrawerButtonGestures({
    required this.size,
    required this.holdDuration,
    required this.status,
    required this.onTap,
    required this.onLongPressStart,
    required this.onLongPressMoveDelta,
    required this.onLongPressEnd,
  });

  final double size;
  final Duration holdDuration;
  final CashDrawerActionStatus status;
  final VoidCallback onTap;
  final VoidCallback onLongPressStart;
  final ValueChanged<Offset> onLongPressMoveDelta;
  final VoidCallback onLongPressEnd;

  @override
  State<_DrawerButtonGestures> createState() => _DrawerButtonGesturesState();
}

class _DrawerButtonGesturesState extends State<_DrawerButtonGestures>
    with SingleTickerProviderStateMixin {
  int? _activePointer;
  bool _dragActivated = false;
  double _preDragMovement = 0;

  // Drives both the hold-progress ring and the drag-activation moment —
  // one clock instead of a bare Timer plus separately-animated UI, so the
  // ring always reflects exactly how close the hold is to completing.
  late final AnimationController _holdController;

  @override
  void initState() {
    super.initState();
    _holdController = AnimationController(vsync: this, duration: widget.holdDuration)
      ..addStatusListener(_onHoldStatusChanged);
  }

  void _onHoldStatusChanged(AnimationStatus status) {
    if (status != AnimationStatus.completed || _dragActivated) return;
    setState(() => _dragActivated = true);
    HapticFeedback.heavyImpact();
    widget.onLongPressStart();
  }

  void _onPointerDown(PointerDownEvent event) {
    if (_activePointer != null) return; // ignore a second simultaneous touch
    setState(() {
      _activePointer = event.pointer;
      _dragActivated = false;
      _preDragMovement = 0;
    });
    HapticFeedback.selectionClick();
    _holdController.forward(from: 0);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (event.pointer != _activePointer) return;
    if (_dragActivated) {
      widget.onLongPressMoveDelta(event.delta);
    } else {
      _preDragMovement += event.delta.distance;
    }
  }

  void _onPointerUp(PointerUpEvent event) {
    if (event.pointer != _activePointer) return;
    _endGesture(fireTap: !_dragActivated && _preDragMovement <= kTouchSlop);
  }

  void _onPointerCancel(PointerCancelEvent event) {
    if (event.pointer != _activePointer) return;
    _endGesture(fireTap: false);
  }

  void _endGesture({required bool fireTap}) {
    final wasDragging = _dragActivated;
    _holdController.animateTo(0, duration: const Duration(milliseconds: 150));
    setState(() {
      _dragActivated = false;
      _activePointer = null;
    });
    if (wasDragging) {
      widget.onLongPressEnd();
    } else if (fireTap) {
      widget.onTap();
    }
  }

  @override
  void dispose() {
    _holdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: AnimatedBuilder(
        animation: _holdController,
        builder: (context, _) => _DrawerButtonVisual(
          size: widget.size,
          status: widget.status,
          isHeld: _activePointer != null,
          isDragActive: _dragActivated,
          holdProgress: _holdController.value,
        ),
      ),
    );
  }
}

class _DrawerButtonVisual extends StatelessWidget {
  const _DrawerButtonVisual({
    required this.size,
    required this.status,
    required this.isHeld,
    required this.isDragActive,
    required this.holdProgress,
  });

  final double size;
  final CashDrawerActionStatus status;

  /// A pointer is currently down on the button (whether or not the hold
  /// has completed yet).
  final bool isHeld;

  /// The 1.5s hold has completed — the button is now repositionable.
  final bool isDragActive;

  /// 0..1 progress of the hold toward [isDragActive], so the ring always
  /// shows exactly how much longer to keep holding.
  final double holdProgress;

  static const _ringOverhang = 14.0;

  @override
  Widget build(BuildContext context) {
    final Color background = switch (status) {
      CashDrawerActionStatus.success => AppColors.success,
      CashDrawerActionStatus.error => AppColors.danger,
      _ => AppColors.primary,
    };

    // Shrinks slightly while held (reads as "being pressed"), then grows
    // past its resting size once the hold completes (reads as "armed —
    // you can move me now") — two distinct, at-a-glance states instead of
    // a static circle that looks the same whether nothing, a hold-in-
    // progress, or an active drag is happening under the finger.
    final scale = isDragActive ? 1.14 : (isHeld ? 1.0 - 0.06 * holdProgress : 1.0);

    // The ring overhangs the button's own size, but must not grow the box
    // the parent Positioned/drag-bounds math lays out against. OverflowBox
    // reports itself at exactly the tight `size x size` it receives from
    // Positioned (matching _dragBounds' assumption), while forcing its
    // child to a fixed size+overhang box (min == max on both axes, so the
    // ring's box is deterministic regardless of ambient constraints) that
    // overflows past it purely visually, centered.
    final ringBoxSize = size + _ringOverhang * 2;
    return OverflowBox(
      minWidth: ringBoxSize,
      maxWidth: ringBoxSize,
      minHeight: ringBoxSize,
      maxHeight: ringBoxSize,
      child: Stack(
        alignment: Alignment.center,
        children: [
          if (isHeld && !isDragActive)
            SizedBox(
              width: size + _ringOverhang,
              height: size + _ringOverhang,
              child: CircularProgressIndicator(
                value: holdProgress,
                strokeWidth: 3,
                backgroundColor: Colors.black.withValues(alpha: 0.08),
                valueColor: const AlwaysStoppedAnimation(AppColors.primaryDark),
              ),
            ),
          AnimatedScale(
            scale: scale,
            duration: const Duration(milliseconds: 120),
            curve: Curves.easeOut,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
                border: isDragActive ? Border.all(color: Colors.white, width: 2.5) : null,
                boxShadow: isDragActive
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.45),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ]
                    : AppShadows.elevated,
              ),
              child: Center(child: _icon()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _icon() {
    switch (status) {
      case CashDrawerActionStatus.sending:
        return const SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
        );
      case CashDrawerActionStatus.success:
        return const Icon(Icons.check_rounded, color: Colors.white, size: 26);
      case CashDrawerActionStatus.error:
        return const Icon(Icons.close_rounded, color: Colors.white, size: 26);
      case CashDrawerActionStatus.idle:
        return const Icon(Icons.point_of_sale_rounded, color: Colors.white, size: 24);
    }
  }
}
