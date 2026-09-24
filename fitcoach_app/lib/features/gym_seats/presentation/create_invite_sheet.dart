import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/gym_seats_models.dart';
import '../data/invites_repository.dart';

/// Set an optional max-uses/expiry, then create the invite -- the code
/// itself is DB-generated (migration 021), never entered here. Text/code
/// only for this first pass, no QR generation -- see Milestone 7.md's
/// decision log; §10.2's "shareable as a link, code, or QR" is satisfied by
/// the plain code shown/copied from subscription_screen.dart's invite list.
///
/// Returns the created [Invite], or null if the sheet was dismissed.
Future<Invite?> showCreateInviteSheet(BuildContext context, {required String subscriptionId}) {
  return showModalBottomSheet<Invite>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _CreateInviteSheet(subscriptionId: subscriptionId),
  );
}

class _CreateInviteSheet extends ConsumerStatefulWidget {
  const _CreateInviteSheet({required this.subscriptionId});

  final String subscriptionId;

  @override
  ConsumerState<_CreateInviteSheet> createState() => _CreateInviteSheetState();
}

class _CreateInviteSheetState extends ConsumerState<_CreateInviteSheet> {
  final _maxUsesController = TextEditingController();
  DateTime? _expiresAt;
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _maxUsesController.dispose();
    super.dispose();
  }

  Future<void> _pickExpiry() async {
    final picked = await showDatePicker(
      context: context,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _expiresAt = picked);
  }

  Future<void> _create() async {
    final createdBy = ref.read(authProvider).userId;
    if (createdBy == null) return;

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      final maxUses = _maxUsesController.text.trim().isEmpty ? null : int.tryParse(_maxUsesController.text.trim());
      final invite = await ref
          .read(invitesRepositoryProvider)
          .createInvite(subscriptionId: widget.subscriptionId, createdBy: createdBy, maxUses: maxUses, expiresAt: _expiresAt);
      if (mounted) Navigator.of(context).pop(invite);
    } catch (e) {
      setState(() => _error = 'Could not create this invite: $e');
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('New invite', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _maxUsesController,
            enabled: !_creating,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Max uses (optional)', hintText: 'Leave blank for unlimited', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: _creating ? null : _pickExpiry,
            child: Text(_expiresAt == null ? 'Set an expiry date (optional)' : 'Expires ${_expiresAt!.toLocal()}'.split(' ').first),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _creating ? null : _create,
            child: _creating
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.ink))
                : const Text('Create invite'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
