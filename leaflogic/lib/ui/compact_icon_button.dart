import 'package:flutter/material.dart';

/// IconButton sized to fit inside the app's compact 32dp page-name AppBar.
/// Default IconButton has a 48x48 minimum tap target, which forces the
/// AppBar to grow back to 48dp even when toolbarHeight is set lower.
class CompactIconButton extends StatelessWidget {
  const CompactIconButton({
    required this.icon,
    required this.onPressed,
    this.tooltip,
    super.key,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
      iconSize: 20,
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
    );
  }
}
