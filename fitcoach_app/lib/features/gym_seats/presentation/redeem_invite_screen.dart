import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../data/redeem_invite_repository.dart';

/// Client side of gym seat licensing (Requirement 1 §10.3): enter a code
/// handed to them by a coach/gym, redeem it via coaching-api. Reachable from
/// Profile only this pass (an already-onboarded client connecting to a new
/// coach) -- not from onboarding/role-select, per Milestone 7.md's decision
/// log; Plan.md's onboarding flow doesn't currently mention invite codes.
class RedeemInviteScreen extends ConsumerStatefulWidget {
  const RedeemInviteScreen({super.key});

  @override
  ConsumerState<RedeemInviteScreen> createState() => _RedeemInviteScreenState();
}

class _RedeemInviteScreenState extends ConsumerState<RedeemInviteScreen> {
  final _codeController = TextEditingController();
  bool _redeeming = false;
  String? _error;

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  Future<void> _redeem() async {
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = 'Enter a code first');
      return;
    }

    setState(() {
      _redeeming = true;
      _error = null;
    });
    try {
      await ref.read(redeemInviteRepositoryProvider).redeem(code: code);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Connected! Your new coach will show up shortly.')));
        context.pop();
      }
    } catch (e) {
      setState(() => _error = describeRedeemInviteError(e));
    } finally {
      if (mounted) setState(() => _redeeming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join with a code')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Text(
            'Ask your coach or gym for their invite code, then enter it below to connect.',
            style: TextStyle(color: AppColors.inkSoftLight),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _codeController,
            enabled: !_redeeming,
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(labelText: 'Invite code', border: OutlineInputBorder()),
            onSubmitted: (_) => _redeem(),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _redeeming ? null : _redeem,
            child: _redeeming
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : const Text('Redeem'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
