import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/message_models.dart';
import '../data/messaging_repository.dart';
import 'messaging_providers.dart';

/// One conversation's message thread -- live via `conversation-{id}`
/// (Requirement 1 §6.8), matching the visual language of the concept HTML's
/// screenCoach()/screenTrainerMessages() (own messages right-aligned on
/// lime, the other party's left-aligned on the card surface) rebuilt as
/// proper Flutter widgets rather than the concept's raw HTML/CSS.
class ConversationThreadScreen extends ConsumerStatefulWidget {
  const ConversationThreadScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationThreadScreen> createState() => _ConversationThreadScreenState();
}

class _ConversationThreadScreenState extends ConsumerState<ConversationThreadScreen> {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  bool _sending = false;
  String? _error;
  bool _markedRead = false;

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    });
  }

  Future<void> _markRead(String myUserId) async {
    if (_markedRead) return;
    _markedRead = true;
    try {
      await ref.read(messagingRepositoryProvider).markConversationRead(conversationId: widget.conversationId, myUserId: myUserId);
    } catch (_) {
      // Best-effort -- an unread badge staying on one message a beat longer
      // isn't worth surfacing an error for.
      _markedRead = false;
    }
  }

  Future<void> _send(String myUserId) async {
    final body = _inputController.text.trim();
    if (body.isEmpty) return;
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ref.read(messagingRepositoryProvider).sendMessage(conversationId: widget.conversationId, senderId: myUserId, body: body);
      _inputController.clear();
    } catch (e) {
      setState(() => _error = 'Could not send: $e');
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final myUserId = ref.watch(authProvider.select((s) => s.userId));
    final messagesAsync = ref.watch(conversationMessagesProvider(widget.conversationId));

    // Best-effort title lookup from the already-loaded conversation list --
    // falls back to a generic label if this thread was opened before that
    // list finished loading (e.g. a deep link).
    final otherDisplayName = ref
        .watch(conversationsProvider)
        .maybeWhen(
          data: (conversations) {
            for (final conversation in conversations) {
              if (conversation.conversationId == widget.conversationId) return conversation.otherDisplayName;
            }
            return null;
          },
          orElse: () => null,
        );

    return Scaffold(
      appBar: AppBar(title: Text(otherDisplayName ?? 'Conversation')),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Could not load this conversation: $error')),
              data: (messages) {
                if (myUserId != null && messages.isNotEmpty) {
                  unawaited(_markRead(myUserId));
                }
                _scrollToBottom();
                if (messages.isEmpty) {
                  return const Center(child: Text('No messages yet. Say hello.'));
                }
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) => _MessageBubble(message: messages[index], isMine: messages[index].senderId == myUserId),
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Text(_error!, style: const TextStyle(color: AppColors.coral)),
            ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      minLines: 1,
                      maxLines: 4,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(hintText: 'Message'),
                      enabled: !_sending,
                      onSubmitted: myUserId == null ? null : (_) => _send(myUserId),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    icon: const Icon(Icons.send),
                    onPressed: (_sending || myUserId == null) ? null : () => _send(myUserId),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message, required this.isMine});

  final Message message;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMine ? AppColors.lime : Theme.of(context).colorScheme.surface,
          border: isMine ? null : Border.all(color: Theme.of(context).colorScheme.outline),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(message.body, style: TextStyle(color: isMine ? AppColors.ink : Theme.of(context).colorScheme.onSurface)),
      ),
    );
  }
}
