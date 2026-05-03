import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Loads `assets/ml/leaf_classifier.tflite` (after export) and runs the same
/// preprocessing as training: RGB, resize 256×256, values in [0, 1].
class LeafClassifierService {
  LeafClassifierService._();
  static final LeafClassifierService instance = LeafClassifierService._();

  Interpreter? _interpreter;
  List<String> _labels = const [];
  var _labelsLoaded = false;
  String? _loadError;

  bool get isReady => _interpreter != null;
  String? get loadError => _loadError;

  Future<void> ensureLoaded() async {
    await _loadLabels();
    if (_interpreter != null) return;
    _loadError = null;
    try {
      _interpreter = await Interpreter.fromAsset('assets/ml/leaf_classifier.tflite');
      _interpreter!.allocateTensors();
    } catch (e, st) {
      _interpreter = null;
      _loadError = '$e';
      assert(() {
        // ignore: avoid_print
        print('LeafClassifier: could not load TFLite ($e)\n$st');
        return true;
      }());
    }
  }

  Future<void> _loadLabels() async {
    if (_labelsLoaded) return;
    try {
      final s = await rootBundle.loadString('assets/ml/labels.json');
      final list = jsonDecode(s) as List<dynamic>;
      _labels = list.map((e) => '$e').toList();
    } catch (_) {
      _labels = const [];
    }
    _labelsLoaded = true;
  }

  /// Returns null if the model is missing or inference fails.
  Future<({String label, double confidence})?> classifyBytes(Uint8List imageBytes) async {
    await ensureLoaded();
    final interpreter = _interpreter;
    if (interpreter == null) return null;

    final decoded = img.decodeImage(imageBytes);
    if (decoded == null) return null;

    final resized = img.copyResize(
      decoded,
      width: 224,
      height: 224,
      interpolation: img.Interpolation.cubic,
    );

    final inShape = interpreter.getInputTensor(0).shape;
    final outShape = interpreter.getOutputTensor(0).shape;
    final nClass = outShape.length == 2 ? outShape[1] : outShape.last;

    final input = _buildNestedInput(resized, inShape);
    if (input == null) return null;

    final output = [List<double>.filled(nClass, 0.0)];

    try {
      interpreter.run(input, output);
    } catch (_) {
      return null;
    }

    final logits = output[0];
    var maxI = 0;
    var maxV = logits[0];
    for (var i = 1; i < logits.length; i++) {
      if (logits[i] > maxV) {
        maxV = logits[i];
        maxI = i;
      }
    }
    final m = logits.reduce((a, b) => math.max(a, b));
    var denom = 0.0;
    for (final v in logits) {
      denom += math.exp(v - m);
    }
    final conf = denom > 0 ? math.exp(logits[maxI] - m) / denom : 1.0;

    final label = maxI < _labels.length && _labels.isNotEmpty
        ? _labels[maxI]
        : 'class_$maxI';
    return (label: label, confidence: conf.clamp(0.0, 1.0));
  }

  /// Builds [batch][...] nested lists for NCHW or NHWC float32 models.
  List<List<List<List<double>>>>? _buildNestedInput(img.Image resized, List<int> shape) {
    if (shape.length != 4) return null;
    final b = shape[0];
    if (b != 1) return null;

    // [1, 3, H, W]
    if (shape[1] == 3) {
      final h = shape[2];
      final w = shape[3];
      return [
        List.generate(3, (c) {
          return List.generate(h, (y) {
            return List.generate(w, (x) {
              final p = resized.getPixel(x, y);
              final v = switch (c) {
                0 => p.r,
                1 => p.g,
                _ => p.b,
              };
              return v.toDouble() / 255.0;
            });
          });
        }),
      ];
    }

    // [1, H, W, 3]
    if (shape[3] == 3) {
      final h = shape[1];
      final w = shape[2];
      return [
        List.generate(h, (y) {
          return List.generate(w, (x) {
            return List.generate(3, (c) {
              final p = resized.getPixel(x, y);
              final v = switch (c) {
                0 => p.r,
                1 => p.g,
                _ => p.b,
              };
              return v.toDouble() / 255.0;
            });
          });
        }),
      ];
    }

    return null;
  }

  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}
