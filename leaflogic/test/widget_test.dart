import 'package:flutter_test/flutter_test.dart';
import 'package:leaflogic/core/bootstrap/app_bootstrap.dart';
import 'package:leaflogic/router/supabase_auth_notifier.dart';

import 'package:leaflogic/app/leaflogic_app.dart';

void main() {
  testWidgets('LeafLogic app builds', (WidgetTester tester) async {
    await AppBootstrap.init();
    final authNotifier = SupabaseAuthNotifier();
    await tester.pumpWidget(LeafLogicApp(authNotifier: authNotifier));
    await tester.pumpAndSettle();

    // Without dart-define, user lands on setup / configuration copy.
    expect(find.textContaining('LeafLogic'), findsWidgets);
  });
}
