import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import 'auth_provider.dart';
import 'email_otp_screen.dart';

/// Same submit-button/error-display shape as both sibling apps' auth
/// screens: plain TextEditingController + local busy-flag + inline error
/// text under the form, no flutter_form_builder (dead dependency in both
/// sibling apps -- neither actually uses it for auth/profile forms).
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key, this.redirectTo});

  final String? redirectTo;

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();

  bool _signingInWithGoogle = false;
  bool _sendingOtp = false;
  String? _error;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _signInWithGoogle() async {
    setState(() {
      _signingInWithGoogle = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).signInWithGoogle();
      await waitUntilLoggedIn(ref);
      if (mounted) context.go(widget.redirectTo ?? '/');
    } catch (e) {
      setState(() => _error = 'Google sign-in failed: $e');
    } finally {
      if (mounted) setState(() => _signingInWithGoogle = false);
    }
  }

  Future<void> _sendOtp() async {
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email address');
      return;
    }

    setState(() {
      _sendingOtp = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).sendEmailOtp(email);
      if (mounted) {
        context.push('/login/verify-otp', extra: EmailOtpScreenArgs(email: email, redirectTo: widget.redirectTo));
      }
    } catch (e) {
      setState(() => _error = 'Could not send code: $e');
    } finally {
      if (mounted) setState(() => _sendingOtp = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _signingInWithGoogle || _sendingOtp;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.fitness_center, size: 64),
                const SizedBox(height: 16),
                const Text('FitCoach', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
                const SizedBox(height: 32),
                FilledButton.icon(
                  onPressed: busy ? null : _signInWithGoogle,
                  icon: _signingInWithGoogle
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                      : const Icon(Icons.g_mobiledata),
                  label: const Text('Continue with Google'),
                ),
                const SizedBox(height: 24),
                const Row(
                  children: [
                    Expanded(child: Divider()),
                    Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('or')),
                    Expanded(child: Divider()),
                  ],
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  enabled: !busy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: busy ? null : _sendOtp,
                  child: _sendingOtp
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send sign-in code'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
