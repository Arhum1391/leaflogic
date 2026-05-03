import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/leaflogic_logo.dart';

class MainShell extends StatelessWidget {
  const MainShell({required this.navigationShell, super.key});

  final StatefulNavigationShell navigationShell;

  static const _scanIndex = 2;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      extendBody: true,
      body: Column(
        children: [
          _BrandHeader(),
          Expanded(child: navigationShell),
        ],
      ),
      floatingActionButton: _ScanFab(
        active: navigationShell.currentIndex == _scanIndex,
        onTap: () => navigationShell.goBranch(_scanIndex),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: _BottomBar(
        currentIndex: navigationShell.currentIndex,
        onSelect: navigationShell.goBranch,
        accent: cs.primary,
      ),
    );
  }
}

class _BrandHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Material(
      color: cs.primary,
      elevation: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
          child: Row(
            children: [
              const LeafLogicLogo(height: 30, pad: 6, onGreenHeader: true),
              const SizedBox(width: 12),
              Text(
                'LeafLogic',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: cs.onPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScanFab extends StatelessWidget {
  const _ScanFab({required this.active, required this.onTap});

  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SizedBox(
      height: 64,
      width: 64,
      child: FloatingActionButton(
        heroTag: 'scan-fab',
        onPressed: onTap,
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
        elevation: 6,
        shape: const CircleBorder(),
        child: Icon(
          active ? Icons.document_scanner : Icons.document_scanner_outlined,
          size: 30,
        ),
      ),
    );
  }
}

class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.currentIndex,
    required this.onSelect,
    required this.accent,
  });

  final int currentIndex;
  final void Function(int) onSelect;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      shape: const CircularNotchedRectangle(),
      notchMargin: 8,
      padding: EdgeInsets.zero,
      height: 64,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _BarItem(
            icon: Icons.dashboard_outlined,
            activeIcon: Icons.dashboard,
            label: 'Dashboard',
            selected: currentIndex == 0,
            onTap: () => onSelect(0),
            accent: accent,
          ),
          _BarItem(
            icon: Icons.photo_library_outlined,
            activeIcon: Icons.photo_library,
            label: 'Library',
            selected: currentIndex == 1,
            onTap: () => onSelect(1),
            accent: accent,
          ),
          // Notch occupies the centre slot - the FAB lives there.
          const SizedBox(width: 64),
          _BarItem(
            icon: Icons.timeline_outlined,
            activeIcon: Icons.timeline,
            label: 'Tracker',
            selected: currentIndex == 3,
            onTap: () => onSelect(3),
            accent: accent,
          ),
          _BarItem(
            icon: Icons.science_outlined,
            activeIcon: Icons.science,
            label: 'Samples',
            selected: currentIndex == 4,
            onTap: () => onSelect(4),
            accent: accent,
          ),
        ],
      ),
    );
  }
}

class _BarItem extends StatelessWidget {
  const _BarItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = selected ? accent : theme.colorScheme.onSurfaceVariant;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(selected ? activeIcon : icon, color: color, size: 22),
              const SizedBox(height: 2),
              Text(
                label,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
