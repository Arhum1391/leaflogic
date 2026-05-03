import 'package:flutter/foundation.dart';

/// Bumped when the user taps a bottom-nav tab so the underlying screen can
/// re-fetch fresh data even though StatefulShellRoute.indexedStack keeps it
/// alive (which means initState only ever fires once per session).
final ValueNotifier<int> dashboardRefreshSignal = ValueNotifier<int>(0);
final ValueNotifier<int> libraryRefreshSignal = ValueNotifier<int>(0);
final ValueNotifier<int> trackerRefreshSignal = ValueNotifier<int>(0);

/// Branch indices match the order in app_router.dart's StatefulShellRoute:
/// 0 = Dashboard, 1 = Library, 2 = Capture, 3 = Tracker, 4 = Samples.
void requestTabRefresh(int branchIndex) {
  switch (branchIndex) {
    case 0:
      dashboardRefreshSignal.value++;
    case 1:
      libraryRefreshSignal.value++;
    case 3:
      trackerRefreshSignal.value++;
    default:
      break; // Capture / Samples / Diseases don't need re-fetch on focus.
  }
}
