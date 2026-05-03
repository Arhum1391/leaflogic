import 'package:flutter/material.dart';

/// Brand mark from `design/leaflogic.png` (see `pubspec.yaml` assets).
///
/// The PNG is treated as a **white-on-transparent** mask and tinted with
/// [ColorScheme.primary] so it always reads **green** in the UI.
class LeafLogicLogo extends StatelessWidget {
  const LeafLogicLogo({
    super.key,
    this.height = 48,
    this.pad = 8,
    this.onGreenHeader = false,
  });

  /// Nominal logo height (width follows aspect ratio).
  final double height;

  /// Inner padding when [onGreenHeader] applies a light plate behind the mark.
  final double pad;

  /// Use a soft white plate so the green artwork reads on gradient headers.
  final bool onGreenHeader;

  static const _assetPath = 'design/leaflogic.png';

  @override
  Widget build(BuildContext context) {
    final tint = Theme.of(context).colorScheme.primary;

    final image = Image.asset(
      _assetPath,
      height: height,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      // White + alpha → solid brand green (keeps transparency).
      color: tint,
      colorBlendMode: BlendMode.srcIn,
      errorBuilder: (context, err, st) => Icon(
        Icons.eco,
        size: height * 0.85,
        color: tint,
      ),
    );

    if (!onGreenHeader) {
      return image;
    }

    return Container(
      padding: EdgeInsets.all(pad),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: image,
    );
  }
}
