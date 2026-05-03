import 'package:flutter/material.dart';

import 'app/leaflogic_app.dart';
import 'core/bootstrap/app_bootstrap.dart';
import 'router/supabase_auth_notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppBootstrap.init();
  final authNotifier = SupabaseAuthNotifier();
  runApp(LeafLogicApp(authNotifier: authNotifier));
}
