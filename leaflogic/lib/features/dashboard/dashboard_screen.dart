import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/diagnosis_preview.dart';
import '../../services/last_leaf_diagnosis.dart';
import '../../services/leaf_diagnosis_notifier.dart';
import '../../services/leaflogic_data_service.dart';
import '../../ui/leaflogic_logo.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, int>? _stats;
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
      final s = await svc.fetchDashboardStats();
      if (mounted) {
        setState(() {
          _stats = s;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error =
              'Could not load stats. Run both SQL files in Supabase (see Setup steps). '
              'Details: $e';
          _stats = null;
          _loading = false;
        });
      }
    }
  }

  Future<void> _signOut() async {
    LastLeafDiagnosis.instance.clear();
    bumpLeafDiagnosis();
    await Supabase.instance.client.auth.signOut();
    if (mounted) context.go('/login');
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
            const LeafLogicLogo(height: 30),
            const SizedBox(width: 10),
            const Text('Dashboard'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sign out',
            onPressed: _signOut,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Overview',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              'Catalog and community stats update from Supabase.',
              style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 18),
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_error != null)
              Card(
                color: cs.errorContainer.withValues(alpha: 0.35),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: theme.textTheme.bodyMedium),
                ),
              )
            else ...[
              LayoutBuilder(
                builder: (context, c) {
                  final w = c.maxWidth;
                  final cross = w > 520 ? 3 : 2;
                  return GridView.count(
                    crossAxisCount: cross,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 1.15,
                    children: [
                      _MetricTile(
                        icon: Icons.photo_camera_outlined,
                        label: 'My leaf images',
                        value: '${_stats!['my_leaf_images']}',
                        tint: cs.primary,
                      ),
                      _MetricTile(
                        icon: Icons.menu_book_outlined,
                        label: 'Catalog diseases',
                        value: '${_stats!['catalog_diseases']}',
                        tint: cs.secondary,
                      ),
                      _MetricTile(
                        icon: Icons.people_outline,
                        label: 'Registered profiles',
                        value: '${_stats!['registered_profiles']}',
                        tint: const Color(0xFF00695C),
                      ),
                    ],
                  );
                },
              ),
            ],
            const SizedBox(height: 28),
            Text(
              'Latest scan',
              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<int>(
              valueListenable: leafDiagnosisRefresh,
              builder: (context, _, __) {
                if (DiagnosisPreview.enabled) {
                  return _LatestScanCard(
                    species: DiagnosisPreview.species,
                    disease: DiagnosisPreview.disease,
                    confidence: DiagnosisPreview.confidence,
                    footnote:
                        'Preview layout only (MOCK_DIAGNOSIS). Remove mock defines for real TFLite output.',
                  );
                }
                final d = LastLeafDiagnosis.instance;
                if (d.hasResult && d.species != null && d.diseaseName != null && d.confidence != null) {
                  return _LatestScanCard(
                    species: d.species!,
                    disease: d.diseaseName!,
                    confidence: d.confidence!,
                    footnote: d.at != null
                        ? 'From your last scan (${d.at!.year}-${d.at!.month.toString().padLeft(2, '0')}-${d.at!.day.toString().padLeft(2, '0')})'
                        : 'From your last scan',
                  );
                }
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Row(
                      children: [
                        Icon(Icons.biotech_outlined, size: 40, color: cs.primary),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(
                            'Save a leaf photo on the Scan tab to run on-device '
                            'classification (after you add assets/ml/leaf_classifier.tflite). '
                            'Or use MOCK_DIAGNOSIS for a UI-only preview.',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _LatestScanCard extends StatelessWidget {
  const _LatestScanCard({
    required this.species,
    required this.disease,
    required this.confidence,
    required this.footnote,
  });

  final String species;
  final String disease;
  final double confidence;
  final String footnote;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.biotech_outlined, size: 40, color: cs.primary),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        species,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(disease, style: theme.textTheme.bodyLarge),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Confidence',
              style: theme.textTheme.labelMedium?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: confidence,
                minHeight: 10,
                backgroundColor: cs.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${(confidence * 100).toStringAsFixed(1)}%',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: cs.primary,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              footnote,
              style: theme.textTheme.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.tint,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tint, size: 26),
            const Spacer(),
            Text(
              value,
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
