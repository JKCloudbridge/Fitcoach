import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../coaching/data/coaching_relationships_repository.dart';
import '../../workout_cards/presentation/workout_cards_providers.dart';
import '../data/start_conversation_repository.dart';

class _Candidate {
  const _Candidate({required this.userId, this.displayName});
  final String userId;
  final String? displayName;
}

/// Who can be messaged: a trainer's own active clients, or a client's own
/// active trainer(s) -- start_conversation() (migration 018) enforces the
/// same "active coaching_relationship required" rule server-side regardless,
/// this just keeps the picker from offering someone the RPC would reject
/// anyway.
final _messageableCandidatesProvider = FutureProvider.autoDispose<List<_Candidate>>((ref) async {
  final auth = ref.watch(authProvider);
  if (auth.role == 'trainer') {
    final clients = await ref.watch(trainerActiveClientsProvider.future);
    return [for (final c in clients) _Candidate(userId: c.clientId, displayName: c.displayName)];
  }
  if (auth.role == 'client') {
    final userId = auth.userId;
    if (userId == null) return const [];
    final trainers = await ref.watch(coachingRelationshipsRepositoryProvider).fetchActiveTrainers(userId);
    return [for (final t in trainers) _Candidate(userId: t.trainerId, displayName: t.displayName)];
  }
  return const [];
});

/// Returns the new/existing conversation's id, or null if the sheet was
/// dismissed without starting one.
Future<String?> showStartConversationSheet(BuildContext context) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (context) => const _StartConversationSheet(),
  );
}

class _StartConversationSheet extends ConsumerStatefulWidget {
  const _StartConversationSheet();

  @override
  ConsumerState<_StartConversationSheet> createState() => _StartConversationSheetState();
}

class _StartConversationSheetState extends ConsumerState<_StartConversationSheet> {
  bool _starting = false;
  String? _error;

  Future<void> _start(String otherUserId) async {
    setState(() {
      _starting = true;
      _error = null;
    });
    try {
      final conversationId = await ref.read(startConversationRepositoryProvider).start(otherUserId: otherUserId);
      if (mounted) Navigator.of(context).pop(conversationId);
    } catch (e) {
      setState(() => _error = describeStartConversationError(e));
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final candidatesAsync = ref.watch(_messageableCandidatesProvider);
    final auth = ref.watch(authProvider);
    final isTrainer = auth.role == 'trainer';

    return Padding(
      padding: EdgeInsets.only(left: 24, right: 24, top: 24, bottom: MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(isTrainer ? 'Message a client' : 'Message your coach', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          candidatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, _) => Text('Could not load who you can message: $error'),
            data: (candidates) {
              if (candidates.isEmpty) {
                return Text(
                  isTrainer
                      ? 'No active clients yet. A coaching connection has to exist before you can message someone.'
                      : 'No active coach yet. A coaching connection has to exist before you can send a message.',
                );
              }
              return ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: candidates.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final candidate = candidates[index];
                    return ListTile(
                      title: Text(candidate.displayName ?? 'Unnamed'),
                      onTap: _starting ? null : () => _start(candidate.userId),
                    );
                  },
                ),
              );
            },
          ),
          if (_starting) ...[
            const SizedBox(height: 16),
            const Center(child: SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))),
          ],
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.coral), textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}
