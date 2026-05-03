import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/bootstrap/app_bootstrap.dart';
import '../core/config/app_env.dart';

/// Notifies [GoRouter] when Supabase auth session changes.
class SupabaseAuthNotifier extends ChangeNotifier {
  SupabaseAuthNotifier() {
    if (AppEnv.hasSupabaseConfig && AppBootstrap.initialized) {
      _subscription = Supabase.instance.client.auth.onAuthStateChange.listen(
        (_) => notifyListeners(),
      );
    }
  }

  StreamSubscription<AuthState>? _subscription;

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
