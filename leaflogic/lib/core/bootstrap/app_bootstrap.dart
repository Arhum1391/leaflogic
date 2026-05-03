import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/leaf_classifier_service.dart';
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
    // Pre-warm the TFLite interpreter in the background so the first tap on
    // Classify / Save scan doesn't pay the ~1s cold-load cost. We don't await
    // this - if the model is missing the per-call ensureLoaded() still handles
    // it, just less smoothly.
    unawaited(LeafClassifierService.instance.ensureLoaded());
    _initialized = true;
  }
}
