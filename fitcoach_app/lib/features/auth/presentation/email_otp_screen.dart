import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'auth_provider.dart';

/// Passed via GoRoute's `state.extra` as a typed argument, same convention
/// as Proximity's `(email, redirectTo)` record for its equivalent route.
class EmailOtpScreenArgs {
  const EmailOtpScreenArgs({required this.email, this.redirectTo});

  final String email;
  final String? redirectTo;
}

class EmailOtpScreen extends ConsumerStatefulWidget {
  const EmailOtpScreen({super.key, required this.email, this.redirectTo});

  final String email;
  final String? redirectTo;

  @override
  ConsumerState<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends ConsumerState<EmailOtpScreen> {
  final _codeController = TextEditingController();

  bool _verifying = false;
  bool _resending = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      setState(() => _error = 'Enter the 6-digit code');
      return;
    }

    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).verifyEmailOtp(email: widget.email, token: code);
      await waitUntilLoggedIn(ref);
      if (mounted) context.go(widget.redirectTo ?? '/');
    } catch (e) {
      setState(() => _error = 'Invalid or expired code: $e');
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Future<void> _resend() async {
    setState(() {
      _resending = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).sendEmailOtp(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code resent')));
      }
    } catch (e) {
      setState(() => _error = 'Could not resend code: $e');
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _verifying || _resending;

    return Scaffold(
      appBar: AppBar(title: const Text('Enter code')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text('We sent a code to ${widget.email}', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                TextField(
                  controller: _codeController,
                  enabled: !busy,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 24, letterSpacing: 8),
                  decoration: const InputDecoration(counterText: '', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: busy ? null : _verify,
                  child: _verifying
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Verify'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: busy ? null : _resend,
                  child: _resending ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Resend code'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
