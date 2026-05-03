import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/leaf_classifier_service.dart';
import '../../services/leaflogic_data_service.dart';
import '../../ui/leaflogic_logo.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<UserLeafRow>? _items;
  String? _error;
  var _loading = true;
  final _classifying = <String>{};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _confirmAndDelete(UserLeafRow row) async {
    final theme = Theme.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete scan?'),
        content: const Text(
          'This removes the image from your library and from cloud storage. '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: theme.colorScheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await LeafLogicDataService(Supabase.instance.client).deleteLeafImage(
        rowId: row.id,
        storagePath: row.storagePath,
      );
      if (!mounted) return;
      messenger.showSnackBar(const SnackBar(content: Text('Scan deleted.')));
      await _load();
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Could not delete: $e')));
      }
    }
  }

  Future<void> _classifyRow(UserLeafRow row) async {
    if (_classifying.contains(row.id)) return;
    setState(() => _classifying.add(row.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final svc = LeafLogicDataService(Supabase.instance.client);
      final bytes = await svc.fetchLeafImageBytes(row.signedUrl);
      final pred = await LeafClassifierService.instance.classifyBytes(bytes);
      if (pred == null) {
        if (mounted) {
          messenger.showSnackBar(
            const SnackBar(content: Text('Classifier not loaded.')),
          );
        }
        return;
      }
      await svc.updatePrediction(
        rowId: row.id,
        label: pred.label,
        confidence: pred.confidence,
      );
      if (!mounted) return;
      // Patch the local row so the UI updates without a full reload.
      setState(() {
        final i = _items!.indexWhere((r) => r.id == row.id);
        if (i != -1) {
          final old = _items![i];
          _items![i] = UserLeafRow(
            id: old.id,
            storagePath: old.storagePath,
            createdAt: old.createdAt,
            signedUrl: old.signedUrl,
            predictedLabel: pred.label,
            predictedConfidence: pred.confidence,
            predictedAt: DateTime.now().toUtc(),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(SnackBar(content: Text('Classify failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _classifying.remove(row.id));
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = LeafLogicDataService(Supabase.instance.client);
      final list = await svc.listMyLeafImages();
      if (mounted) {
        setState(() {
          _items = list;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _items = null;
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LeafLogicLogo(height: 28),
            const SizedBox(width: 8),
            const Text('Scan library'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _buildBody(theme, cs),
      ),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme cs) {
    if (_loading) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 120),
          Center(child: CircularProgressIndicator()),
        ],
      );
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.cloud_off_outlined, size: 56, color: cs.error),
          const SizedBox(height: 12),
          Text('Could not load images', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(_error!, style: theme.textTheme.bodyMedium),
        ],
      );
    }
    final items = _items!;
    if (items.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(32),
        children: [
          Icon(Icons.photo_library_outlined, size: 72, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            'No leaf scans yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Use Scan to take a photo or pick from the gallery. Images upload to '
            'Supabase Storage and appear here.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          Center(
            child: FilledButton.icon(
              onPressed: () => context.go('/capture'),
              icon: const Icon(Icons.document_scanner_outlined),
              label: const Text('Take a scan'),
            ),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final row = items[i];
        return _LibraryCard(
          row: row,
          busy: _classifying.contains(row.id),
          onClassify: () => _classifyRow(row),
          onDelete: () => _confirmAndDelete(row),
          shortDate: _shortDate,
        );
      },
    );
  }

  String _shortDate(DateTime d) {
    final l = d.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')} '
        '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.row,
    required this.busy,
    required this.onClassify,
    required this.onDelete,
    required this.shortDate,
  });

  final UserLeafRow row;
  final bool busy;
  final VoidCallback onClassify;
  final VoidCallback onDelete;
  final String Function(DateTime) shortDate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 110,
            height: 110,
            child: Image.network(
              row.signedUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, p) {
                if (p == null) return child;
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              errorBuilder: (context, err, st) => ColoredBox(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: cs.outline, size: 32),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          shortDate(row.createdAt),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Delete scan',
                        icon: const Icon(Icons.delete_outline, size: 20),
                        onPressed: onDelete,
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  if (row.hasPrediction) ...[
                    _PredictionChip(
                      label: row.predictedLabel!,
                      confidence: row.predictedConfidence!,
                    ),
                    const SizedBox(height: 8),
                  ],
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
                      label: Text(row.hasPrediction ? 'Re-classify' : 'Classify'),
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
}

class _PredictionChip extends StatelessWidget {
  const _PredictionChip({required this.label, required this.confidence});

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
