import 'dart:io';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/leaf_classifier_service.dart';
import '../../services/leaf_diagnosis_notifier.dart';
import '../../services/last_leaf_diagnosis.dart';
import '../../services/leaflogic_data_service.dart';

class CaptureScreen extends StatefulWidget {
  const CaptureScreen({super.key});

  @override
  State<CaptureScreen> createState() => _CaptureScreenState();
}

class _CaptureScreenState extends State<CaptureScreen> {
  final _picker = ImagePicker();
  var _busy = false;
  XFile? _preview;

  Future<void> _pick(ImageSource source) async {
    final picked = await _picker.pickImage(source: source, imageQuality: 82);
    if (!mounted || picked == null) return;
    setState(() => _preview = picked);
  }

  Future<bool> _confirmLowConfidence(double confidence) async {
    final pct = (confidence * 100).toStringAsFixed(0);
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Low confidence'),
        content: Text(
          "The model is only $pct% sure. Try better lighting and frame a "
          "single leaf for a stronger reading. Save this scan anyway?",
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Retake'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Save anyway'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _uploadPreview() async {
    final file = _preview;
    if (file == null) return;

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final bytes = await file.readAsBytes();
      final mime = file.mimeType ?? 'image/jpeg';
      final ext = _extensionFromName(file.name, mime);
      final contentType = mime.contains('/') ? mime : 'image/jpeg';

      final pred = await LeafClassifierService.instance.classifyBytes(bytes);
      if (pred != null) {
        LastLeafDiagnosis.instance.setFromRawLabel(pred.label, pred.confidence);
        bumpLeafDiagnosis();

        if (pred.confidence < 0.5) {
          // Pause the busy modal so the dialog isn't blocked.
          setState(() => _busy = false);
          final ok = await _confirmLowConfidence(pred.confidence);
          if (!mounted) return;
          if (!ok) return;
          setState(() => _busy = true);
        }
      }

      final svc = LeafLogicDataService(Supabase.instance.client);
      await svc.uploadLeafImage(
        bytes: bytes,
        contentType: contentType,
        extension: ext,
        predictedLabel: pred?.label,
        predictedConfidence: pred?.confidence,
      );

      if (!mounted) return;
      final String msg;
      if (pred != null) {
        final parts = pred.label.split('___');
        final short = parts.length >= 2 ? parts[1] : pred.label;
        msg =
            'Saved. Top match: $short (${(pred.confidence * 100).toStringAsFixed(0)}% confidence).';
      } else {
        msg = 'Leaf image saved to your library.';
      }
      messenger.showSnackBar(SnackBar(content: Text(msg)));
      setState(() => _preview = null);
      context.go('/dashboard');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String _extensionFromName(String name, String mime) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return 'png';
    if (lower.endsWith('.webp')) return 'webp';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'jpg';
    if (mime.contains('png')) return 'png';
    if (mime.contains('webp')) return 'webp';
    return 'jpg';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        primary: false,
        automaticallyImplyLeading: false,
        toolbarHeight: 24,
        titleSpacing: 16,
        title: const Text('Scan leaf'),
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            children: [
              if (_preview != null) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: AspectRatio(
                    aspectRatio: 4 / 3,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.file(
                          File(_preview!.path),
                          fit: BoxFit.cover,
                          errorBuilder: (context, err, st) => const ColoredBox(
                            color: Colors.black26,
                            child: Icon(Icons.image_not_supported, size: 48),
                          ),
                        ),
                        // Leaf framing guide overlay
                        IgnorePointer(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: cs.primary.withValues(alpha: 0.85),
                                  width: 3,
                                ),
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busy ? null : () => setState(() => _preview = null),
                        child: const Text('Discard'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _busy ? null : _uploadPreview,
                        child: const Text('Save scan'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
              if (_preview == null) ...[
                AspectRatio(
                  aspectRatio: 4 / 3,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.5)),
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.crop_free, size: 52, color: cs.primary),
                            const SizedBox(height: 10),
                            Text(
                              'Fill the frame with one leaf',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.titleSmall,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Good lighting and a steady shot improve later diagnosis.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.camera),
                  icon: const Icon(Icons.photo_camera_outlined),
                  label: const Text('Take photo'),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                  icon: const Icon(Icons.photo_library_outlined),
                  label: const Text('Choose from gallery'),
                ),
              ],
            ],
          ),
          if (_busy)
            const ModalBarrier(dismissible: false, color: Color(0x66000000)),
          if (_busy)
            const Center(child: CircularProgressIndicator()),
        ],
      ),
    );
  }
}
