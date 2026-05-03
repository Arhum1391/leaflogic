/// Last successful TFLite prediction (in-memory for the current app session).
class LastLeafDiagnosis {
  LastLeafDiagnosis._();
  static final LastLeafDiagnosis instance = LastLeafDiagnosis._();

  String? rawLabel;
  String? species;
  String? diseaseName;
  double? confidence;
  DateTime? at;

  bool get hasResult =>
      rawLabel != null && rawLabel!.isNotEmpty && confidence != null;

  void setFromRawLabel(String raw, double conf) {
    rawLabel = raw;
    confidence = conf.clamp(0.0, 1.0);
    at = DateTime.now();
    final parts = raw.split('___');
    if (parts.length >= 2) {
      species = parts[0].replaceAll('_', ' ');
      diseaseName = parts[1].replaceAll('_', ' ');
    } else {
      species = 'Plant';
      diseaseName = raw.replaceAll('_', ' ');
    }
  }

  void clear() {
    rawLabel = null;
    species = null;
    diseaseName = null;
    confidence = null;
    at = null;
  }
}
