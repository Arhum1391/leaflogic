import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_env.dart';

class AppBootstrap {
  AppBootstrap._();

  static var _initialized = false;

  static bool get initialized => _initialized;

  /// True when Supabase client is available (env present and init ran).
  static bool get supabaseReady => _initialized && AppEnv.hasSupabaseConfig;

  static Future<void> init() async {
    if (_initialized) return;
    if (AppEnv.hasSupabaseConfig) {
      await Supabase.initialize(
        url: AppEnv.supabaseUrl,
        anonKey: AppEnv.supabaseAnonKey,
      );
    }
    _initialized = true;
  }
}
