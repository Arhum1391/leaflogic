import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/app_env.dart';
import '../features/auth/login_screen.dart';
import '../features/capture/capture_screen.dart';
import '../features/dashboard/dashboard_screen.dart';
import '../features/library/library_screen.dart';
import '../features/samples/samples_screen.dart';
import '../features/setup/setup_screen.dart';
import '../features/shell/main_shell.dart';

GoRouter createAppRouter(Listenable refreshListenable) {
  return GoRouter(
    initialLocation: '/dashboard',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      if (!AppEnv.hasSupabaseConfig) {
        final onSetup = state.matchedLocation == '/setup';
        return onSetup ? null : '/setup';
      }

      final session = Supabase.instance.client.auth.currentSession;
      final loc = state.matchedLocation;
      final onLogin = loc == '/login';

      if (session == null) {
        return onLogin ? null : '/login';
      }

      if (onLogin || loc == '/setup') {
        return '/dashboard';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/setup',
        builder: (context, state) => const SetupScreen(),
      ),
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return MainShell(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: DashboardScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/library',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: LibraryScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/capture',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: CaptureScreen(),
                ),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/samples',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: SamplesScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
