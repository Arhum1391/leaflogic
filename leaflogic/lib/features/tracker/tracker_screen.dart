import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/leaflogic_data_service.dart';

class TrackerScreen extends StatefulWidget {
  const TrackerScreen({super.key});

  @override
  State<TrackerScreen> createState() => _TrackerScreenState();
}

class _TrackerScreenState extends State<TrackerScreen> {
  List<UserLeafRow>? _items;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final svc = LeafLogicDataService(Supabase.instance.client);
      final all = await svc.listMyLeafImages();
      final predicted = all.where((r) => r.hasPrediction).toList()
        ..sort((a, b) => (b.predictedAt ?? b.createdAt).compareTo(a.predictedAt ?? a.createdAt));
      if (mounted) {
        setState(() {
          _items = predicted;
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
        primary: false,
        automaticallyImplyLeading: false,
        toolbarHeight: 32,
        titleSpacing: 16,
        titleTextStyle: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        title: const Text('Tracker'),
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
          Text('Could not load history', style: theme.textTheme.titleMedium),
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
          Icon(Icons.timeline_outlined, size: 72, color: cs.outline),
          const SizedBox(height: 16),
          Text(
            'No classification history yet',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(
            'Classified scans show up here. Use Scan to capture a new leaf '
            'or open Library and tap Classify on existing images.',
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
      itemBuilder: (context, i) => _TrackerCard(row: items[i]),
    );
  }
}

class _TrackerCard extends StatelessWidget {
  const _TrackerCard({required this.row});

  final UserLeafRow row;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final parts = (row.predictedLabel ?? '').split('___');
    final crop = parts.isNotEmpty ? parts[0].replaceAll('_', ' ') : '';
    final disease = parts.length > 1 ? parts[1].replaceAll('_', ' ') : '';
    final conf = row.predictedConfidence ?? 0;
    final pct = (conf * 100).toStringAsFixed(0);
    final color = conf >= 0.9
        ? Colors.green.shade700
        : conf >= 0.7
            ? Colors.orange.shade700
            : cs.error;
    final when = row.predictedAt ?? row.createdAt;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Image.network(
              row.signedUrl,
              fit: BoxFit.cover,
              loadingBuilder: (_, child, p) {
                if (p == null) return child;
                return const Center(child: CircularProgressIndicator(strokeWidth: 2));
              },
              errorBuilder: (context, err, st) => ColoredBox(
                color: cs.surfaceContainerHighest,
                child: Icon(Icons.broken_image_outlined, color: cs.outline, size: 28),
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    disease.isEmpty ? crop : '$crop — $disease',
                    style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '$pct%',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: color,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _relativeTime(when),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _relativeTime(DateTime when) {
    final now = DateTime.now();
    final diff = now.difference(when.toLocal());
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    final l = when.toLocal();
    return '${l.year}-${l.month.toString().padLeft(2, '0')}-${l.day.toString().padLeft(2, '0')}';
  }
}
