import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;

import '../../services/leaf_classifier_service.dart';

class _Sample {
  const _Sample({required this.assetPath, required this.expected});
  final String assetPath;
  final String expected;
}

const _samples = <_Sample>[
  _Sample(assetPath: 'assets/samples/apple_scab.jpg', expected: 'Apple — Scab'),
  _Sample(assetPath: 'assets/samples/corn_common_rust.jpg', expected: 'Corn — Common rust'),
  _Sample(assetPath: 'assets/samples/potato_early_blight.jpg', expected: 'Potato — Early blight'),
  _Sample(assetPath: 'assets/samples/tomato_healthy.jpg', expected: 'Tomato — Healthy'),
  _Sample(assetPath: 'assets/samples/tomato_yellow_curl_virus.jpg', expected: 'Tomato — Yellow leaf curl virus'),
];

class SamplesScreen extends StatefulWidget {
  const SamplesScreen({super.key});

  @override
  State<SamplesScreen> createState() => _SamplesScreenState();
}

class _SamplesScreenState extends State<SamplesScreen> {
  final _results = <String, ({String label, double confidence})>{};
  final _inFlight = <String>{};

  Future<void> _classify(_Sample sample) async {
    if (_inFlight.contains(sample.assetPath)) return;
    setState(() => _inFlight.add(sample.assetPath));
    try {
      final data = await rootBundle.load(sample.assetPath);
      final bytes = data.buffer.asUint8List();
      final pred = await LeafClassifierService.instance.classifyBytes(bytes);
      if (!mounted) return;
      setState(() {
        if (pred != null) {
          _results[sample.assetPath] = pred;
        } else {
          _results.remove(sample.assetPath);
        }
      });
      if (pred == null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Classifier not loaded — see Setup.')),
        );
      }
    } finally {
      if (mounted) setState(() => _inFlight.remove(sample.assetPath));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        primary: false,
        automaticallyImplyLeading: false,
        titleSpacing: 16,
        title: const Text('Samples'),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        itemCount: _samples.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) {
          if (i == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Tap "Classify" on any sample to run the on-device TFLite '
                'model. No upload, no internet.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            );
          }
          final sample = _samples[i - 1];
          return _SampleCard(
            sample: sample,
            result: _results[sample.assetPath],
            busy: _inFlight.contains(sample.assetPath),
            onClassify: () => _classify(sample),
          );
        },
      ),
    );
  }
}

class _SampleCard extends StatelessWidget {
  const _SampleCard({
    required this.sample,
    required this.result,
    required this.busy,
    required this.onClassify,
  });

  final _Sample sample;
  final ({String label, double confidence})? result;
  final bool busy;
  final VoidCallback onClassify;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 96,
            height: 96,
            child: Image.asset(sample.assetPath, fit: BoxFit.cover),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    sample.expected,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result != null) ...[
                    const SizedBox(height: 4),
                    _PredictionRow(
                      label: result!.label,
                      confidence: result!.confidence,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _matchVerdict(sample.expected, result!.label),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      onPressed: busy ? null : onClassify,
                      icon: busy
                          ? const SizedBox(
                              height: 14,
                              width: 14,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.bolt_outlined, size: 18),
                      label: Text(result == null ? 'Classify' : 'Re-run'),
                      style: FilledButton.styleFrom(
                        visualDensity: VisualDensity.compact,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Heuristic match: split expected on em dash, compare crop + disease keywords.
  static String _matchVerdict(String expected, String predLabel) {
    final parts = predLabel.split('___');
    final crop = parts.isNotEmpty ? parts[0].toLowerCase() : '';
    final disease = parts.length > 1 ? parts[1].toLowerCase() : '';
    final exp = expected.toLowerCase();
    final cropOk = crop.isNotEmpty && exp.contains(crop.split('_')[0]);
    final diseaseTokens = disease
        .replaceAll('_', ' ')
        .split(' ')
        .where((t) => t.length > 3)
        .toList();
    final diseaseOk =
        diseaseTokens.any((t) => exp.contains(t)) || (exp.contains('healthy') && disease.contains('healthy'));
    if (cropOk && diseaseOk) return '✓ Matches expected class';
    if (cropOk) return '~ Right crop, different disease guess';
    return '✗ Different prediction';
  }
}

class _PredictionRow extends StatelessWidget {
  const _PredictionRow({required this.label, required this.confidence});

  final String label;
  final double confidence;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parts = label.split('___');
    final crop = parts.isNotEmpty ? parts[0].replaceAll('_', ' ') : label;
    final disease = parts.length > 1 ? parts[1].replaceAll('_', ' ') : '';
    final pct = (confidence * 100).toStringAsFixed(0);
    final color = confidence >= 0.9
        ? Colors.green.shade700
        : confidence >= 0.7
            ? Colors.orange.shade700
            : cs.error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          disease.isEmpty ? crop : '$crop — $disease',
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 2),
        Text(
          '$pct% confidence',
          style: theme.textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
