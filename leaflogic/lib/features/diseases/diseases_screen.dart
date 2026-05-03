import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:go_router/go_router.dart';

import '../../ui/compact_icon_button.dart';

class DiseasesScreen extends StatefulWidget {
  const DiseasesScreen({super.key});

  @override
  State<DiseasesScreen> createState() => _DiseasesScreenState();
}

class _DiseasesScreenState extends State<DiseasesScreen> {
  Map<String, List<String>>? _byCrop;
  int _total = 0;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await rootBundle.loadString('assets/ml/labels.json');
      final list = (jsonDecode(s) as List<dynamic>).map((e) => '$e').toList();
      final grouped = <String, List<String>>{};
      for (final raw in list) {
        final parts = raw.split('___');
        final crop = parts.isNotEmpty ? parts[0].replaceAll('_', ' ') : raw;
        final disease = parts.length > 1 ? parts[1].replaceAll('_', ' ') : '';
        grouped.putIfAbsent(crop, () => []).add(disease.isEmpty ? raw : disease);
      }
      // Sort: crops alphabetically, diseases inside each with healthy last.
      final sortedKeys = grouped.keys.toList()..sort();
      final sorted = <String, List<String>>{
        for (final k in sortedKeys)
          k: (grouped[k]!..sort((a, b) {
            final ah = a.toLowerCase() == 'healthy' ? 1 : 0;
            final bh = b.toLowerCase() == 'healthy' ? 1 : 0;
            if (ah != bh) return ah - bh;
            return a.compareTo(b);
          })),
      };
      if (mounted) {
        setState(() {
          _byCrop = sorted;
          _total = list.length;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        primary: true,
        toolbarHeight: 44,
        leading: CompactIconButton(
          icon: Icons.arrow_back,
          tooltip: 'Back',
          onPressed: () => context.pop(),
        ),
        title: const Text('Catalog diseases'),
      ),
      body: _buildBody(theme, cs),
    );
  }

  Widget _buildBody(ThemeData theme, ColorScheme cs) {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Could not load labels: $_error'),
      );
    }
    if (_byCrop == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final groups = _byCrop!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text(
          '$_total classes from PlantVillage that the on-device model can predict, grouped by crop.',
          style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        ...groups.entries.map((entry) {
          final crop = entry.key;
          final diseases = entry.value;
          return Card(
            clipBehavior: Clip.antiAlias,
            margin: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  color: cs.primary.withValues(alpha: 0.08),
                  child: Row(
                    children: [
                      Icon(Icons.eco_outlined, size: 18, color: cs.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          crop,
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.primary,
                          ),
                        ),
                      ),
                      Text(
                        '${diseases.length}',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                ...List.generate(diseases.length, (i) {
                  final d = diseases[i];
                  final isHealthy = d.toLowerCase() == 'healthy';
                  return Container(
                    decoration: BoxDecoration(
                      border: Border(
                        top: i == 0
                            ? BorderSide.none
                            : BorderSide(color: cs.outlineVariant.withValues(alpha: 0.3)),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      children: [
                        Icon(
                          isHealthy ? Icons.check_circle_outline : Icons.bug_report_outlined,
                          size: 18,
                          color: isHealthy ? Colors.green.shade700 : cs.error.withValues(alpha: 0.8),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            d,
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ],
            ),
          );
        }),
      ],
    );
  }
}
