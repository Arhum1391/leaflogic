import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/leaflogic_data_service.dart';
import '../../ui/leaflogic_logo.dart';

/// Compile-time Web client id from Google Cloud (OAuth type “Web application”).
const _kGoogleWebClientId = String.fromEnvironment(
  'GOOGLE_WEB_CLIENT_ID',
  defaultValue: '',
);

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  var _register = false;
  var _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = GoRouter.of(context);
    final client = Supabase.instance.client;
    final svc = LeafLogicDataService(client);

    try {
      if (_register) {
        final res = await client.auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
        );
        if (res.session == null) {
          messenger.showSnackBar(
            const SnackBar(
              content: Text(
                'Check your email to confirm the account, or disable email '
                'confirmation in Supabase Auth settings.',
              ),
            ),
          );
          return;
        }
      } else {
        await client.auth.signInWithPassword(
          email: _email.text.trim(),
          password: _password.text,
        );
      }
      await svc.ensureProfileRow();
      if (!mounted) return;
      nav.go('/dashboard');
    } on AuthException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _google() async {
    if (_kGoogleWebClientId.isEmpty) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Google sign-in'),
          content: const Text(
            'Add your OAuth 2.0 Web client id when running the app:\n\n'
            '--dart-define=GOOGLE_WEB_CLIENT_ID=xxxxx.apps.googleusercontent.com\n\n'
            'Use the same id as serverClientId in Google Cloud (Web application). '
            'Also add your Android app + SHA-1 in Google Cloud for token exchange.',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK')),
          ],
        ),
      );
      return;
    }

    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final nav = GoRouter.of(context);
    final client = Supabase.instance.client;
    final svc = LeafLogicDataService(client);

    try {
      final google = GoogleSignIn(serverClientId: _kGoogleWebClientId);
      // Clear any cached session first so signIn() always shows the account
      // picker. Without this, after a sign-out the SDK silently reuses the
      // previous account instead of letting the user choose.
      await google.signOut();
      final account = await google.signIn();
      if (account == null) {
        return;
      }
      final auth = await account.authentication;
      final idToken = auth.idToken;
      final accessToken = auth.accessToken;
      if (idToken == null || accessToken == null) {
        throw Exception('Google did not return tokens. Check Web client id + SHA-1.');
      }
      await client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );
      await svc.ensureProfileRow();
      if (!mounted) return;
      nav.go('/dashboard');
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;

    return Scaffold(
      body: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 52, 24, 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        cs.primary,
                        cs.primary.withValues(alpha: 0.88),
                        const Color(0xFF2E7D32),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const LeafLogicLogo(
                            height: 52,
                            pad: 10,
                            onGreenHeader: true,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'LeafLogic',
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    color: cs.onPrimary,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  'Plant health in your pocket',
                                  style: theme.textTheme.bodyMedium?.copyWith(
                                    color: cs.onPrimary.withValues(alpha: 0.9),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Form(
                        key: _formKey,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              segments: const [
                                ButtonSegment(value: false, label: Text('Sign in')),
                                ButtonSegment(value: true, label: Text('Create account')),
                              ],
                              selected: {_register},
                              onSelectionChanged: (s) {
                                setState(() => _register = s.first);
                              },
                            ),
                            const SizedBox(height: 22),
                            TextFormField(
                              controller: _email,
                              keyboardType: TextInputType.emailAddress,
                              autocorrect: false,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                labelText: 'Email',
                                prefixIcon: Icon(Icons.mail_outline),
                              ),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Enter your email';
                                if (!v.contains('@')) return 'Enter a valid email';
                                return null;
                              },
                            ),
                            const SizedBox(height: 14),
                            TextFormField(
                              controller: _password,
                              obscureText: true,
                              decoration: const InputDecoration(
                                labelText: 'Password',
                                prefixIcon: Icon(Icons.lock_outline),
                              ),
                              validator: (v) {
                                if (v == null || v.isEmpty) return 'Enter a password';
                                if (_register && v.length < 6) {
                                  return 'At least 6 characters';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 22),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Text(_register ? 'Create account' : 'Sign in'),
                            ),
                            const SizedBox(height: 12),
                            OutlinedButton.icon(
                              onPressed: _busy ? null : _google,
                              icon: const Icon(Icons.g_mobiledata, size: 28),
                              label: const Text('Continue with Google'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
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
