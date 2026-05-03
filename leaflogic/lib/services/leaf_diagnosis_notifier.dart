import 'package:flutter/foundation.dart';

/// Bumped after a new on-device classification so listeners (e.g. Dashboard) refresh.
final ValueNotifier<int> leafDiagnosisRefresh = ValueNotifier<int>(0);

void bumpLeafDiagnosis() {
  leafDiagnosisRefresh.value++;
}
