/// Optional UI preview for the “Latest scan” card (until TFLite / API is wired).
///
/// Run, for example:
/// `flutter run --dart-define=MOCK_DIAGNOSIS=true ...`
class DiagnosisPreview {
  DiagnosisPreview._();

  static const bool enabled = bool.fromEnvironment(
    'MOCK_DIAGNOSIS',
    defaultValue: false,
  );

  static const String species = String.fromEnvironment(
    'MOCK_SPECIES',
    defaultValue: 'Tomato',
  );

  static const String disease = String.fromEnvironment(
    'MOCK_DISEASE',
    defaultValue: 'Leaf mold',
  );

  /// 0.0–1.0 as a plain decimal string, e.g. `0.78`
  static const String confidenceStr = String.fromEnvironment(
    'MOCK_CONFIDENCE',
    defaultValue: '0.78',
  );

  static double get confidence {
    final v = double.tryParse(confidenceStr);
    if (v == null) return 0.78;
    return v.clamp(0.0, 1.0);
  }
}
