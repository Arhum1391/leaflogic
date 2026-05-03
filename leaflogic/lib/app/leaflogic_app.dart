import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../router/supabase_auth_notifier.dart';

class LeafLogicApp extends StatefulWidget {
  const LeafLogicApp({required this.authNotifier, super.key});

  final SupabaseAuthNotifier authNotifier;

  @override
  State<LeafLogicApp> createState() => _LeafLogicAppState();
}

class _LeafLogicAppState extends State<LeafLogicApp> {
  late final GoRouter _router = createAppRouter(widget.authNotifier);

  /// Aligns with brand artwork (`design/leaflogic.png`).
  static const _seed = Color(0xFF558B2F);
  static const _secondary = Color(0xFF33691E);

  @override
  Widget build(BuildContext context) {
    final baseScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      secondary: _secondary,
    );

    return MaterialApp.router(
      title: 'LeafLogic',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: baseScheme,
        scaffoldBackgroundColor: const Color(0xFFF2F7F0),
        appBarTheme: AppBarTheme(
          // Tight 32dp page-name strip under the persistent brand header.
          // The strip's actions still have to be made compact at the call
          // site (IconButton padding/constraints), otherwise each 48x48
          // IconButton silently pushes this height back up.
          toolbarHeight: 32,
          centerTitle: true,
          elevation: 0,
          scrolledUnderElevation: 0.5,
          backgroundColor: baseScheme.surface,
          foregroundColor: baseScheme.onSurface,
          titleTextStyle: TextStyle(
            color: baseScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
          iconTheme: IconThemeData(color: baseScheme.onSurface, size: 20),
          actionsIconTheme: IconThemeData(color: baseScheme.onSurface, size: 20),
        ),
        cardTheme: CardThemeData(
          elevation: 0,
          color: baseScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: baseScheme.outlineVariant.withValues(alpha: 0.35)),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: baseScheme.surface,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
      ),
      routerConfig: _router,
    );
  }
}
