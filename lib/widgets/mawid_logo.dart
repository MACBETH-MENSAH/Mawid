import 'package:flutter/material.dart';

/// The MAWID mark. Reused everywhere the logo appears (top bars, splash,
/// login) instead of each screen having its own copy — so if the asset
/// changes, it changes once, everywhere.
///
/// Drop the exported PNG (or SVG, if you add flutter_svg) at
/// assets/images/mawid_mark.png and declare it under `flutter: assets:`
/// in pubspec.yaml (already done in this project's pubspec.yaml).
class MawidLogo extends StatelessWidget {
  final double size;

  const MawidLogo({super.key, this.size = 32});

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/images/mawid_mark.png',
      height: size,
      width: size,
      // If the asset hasn't been dropped in yet, fail gracefully instead
      // of crashing the whole screen — makes it obvious what's missing
      // without blocking everyone else's work on other screens.
      errorBuilder: (context, error, stackTrace) => Icon(
        Icons.circle_outlined,
        size: size,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// Logo + wordmark, used on Login/Signup/Splash.
class MawidLogoWordmark extends StatelessWidget {
  final double logoSize;
  final double fontSize;

  const MawidLogoWordmark({
    super.key,
    this.logoSize = 96,
    this.fontSize = 40,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        MawidLogo(size: logoSize),
        const SizedBox(height: 20),
        Text(
          'MAWID',
          style: TextStyle(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            letterSpacing: 6,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
