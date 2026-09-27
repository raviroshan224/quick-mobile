import 'package:flutter/material.dart';

/// Quick logo mark.
/// [onDark] = true renders white on dark backgrounds (splash, sidebar, brand panels).
/// [onDark] = false renders the native black mark on light backgrounds.
class QuickLogo extends StatelessWidget {
  const QuickLogo({super.key, this.size = 48, this.onDark = false});

  final double size;
  final bool onDark;

  static const _asset = 'assets/images/quick_logo.png';

  @override
  Widget build(BuildContext context) {
    final img = Image.asset(_asset, width: size, height: size, fit: BoxFit.contain);
    if (!onDark) return img;
    return ColorFiltered(
      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
      child: img,
    );
  }
}
