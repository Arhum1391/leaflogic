import 'package:flutter/material.dart';

import '../../ui/leaflogic_logo.dart';

/// Shown when `SUPABASE_URL` / `SUPABASE_ANON_KEY` are not passed at compile time.
class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 56, 24, 28),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary,
                    cs.primary.withValues(alpha: 0.85),
                    const Color(0xFF2E7D32),
                  ],
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const LeafLogicLogo(height: 56, pad: 10, onGreenHeader: true),
                  const SizedBox(height: 12),
                  Text(
                    'LeafLogic',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: cs.onPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Connect your Supabase project to continue.',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: cs.onPrimary.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                Text('Supabase setup', style: theme.textTheme.titleLarge),
                const SizedBox(height: 12),
                _Step(
                  n: 1,
                  title: 'Create project',
                  body:
                      'At https://supabase.com create a project. Copy the Project URL '
                      '(https://YOUR_REF.supabase.co) and the anon public API key.',
                ),
                _Step(
                  n: 2,
                  title: 'Run SQL scripts',
                  body:
                      'In Supabase → SQL → New query, run in order:\n'
                      '• leaflogic/supabase/001_reference_schema.sql\n'
                      '• leaflogic/supabase/002_storage_bucket_policies_trigger_seed.sql',
                ),
                _Step(
                  n: 3,
                  title: 'Enable email auth',
                  body:
                      'Authentication → Providers → Email: enable. Turn off “Confirm email” '
                      'for quick testing if you want instant sign-in.',
                ),
                _Step(
                  n: 4,
                  title: 'Run the app with keys',
                  body:
                      'From the leaflogic folder, pass URL and anon key (no line breaks):',
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'flutter run -d YOUR_DEVICE '
                  '--dart-define=SUPABASE_URL=https://YOUR_REF.supabase.co '
                  '--dart-define=SUPABASE_ANON_KEY=eyJ...',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Optional: Google sign-in', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'Add a Web OAuth client in Google Cloud Console, then pass:\n'
                  '--dart-define=GOOGLE_WEB_CLIENT_ID=your.apps.googleusercontent.com',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 24),
                Text('Optional: Latest scan card preview', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'From the MAD repo root, run a tiny train + predict, then copy the '
                  'printed flutter line (MOCK_DIAGNOSIS) next to your Supabase defines:',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'python -m leaflogic_ml.smoke',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 20),
                Text('On-device model (TFLite)', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  'After training, export and copy into leaflogic/assets/ml/:\n'
                  '• leaf_classifier.tflite\n'
                  '• labels.json (overwrites the bundled list; class order must match training).',
                  style: theme.textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                const SizedBox(height: 8),
                SelectableText(
                  'python -m leaflogic_ml.export_tflite --checkpoint leaflogic_ml/runs/smoke/best.pt '
                  '--out-dir leaflogic/assets/ml',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontFamily: 'monospace',
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.n,
    required this.title,
    required this.body,
  });

  final int n;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: cs.primaryContainer,
            foregroundColor: cs.onPrimaryContainer,
            child: Text('$n', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
