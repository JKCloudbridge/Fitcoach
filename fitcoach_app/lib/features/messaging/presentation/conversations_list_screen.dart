import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_theme.dart';
import '../../notifications/presentation/notification_bell.dart';
import 'messaging_providers.dart';
import 'start_conversation_sheet.dart';

/// Conversation list -- one screen shared by both the client "Coach" tab and
/// the trainer "Messages" tab (parameterized by [title]/[basePath]), since
/// the underlying data shape is identical for both roles: a signed-in user's
/// 1:1 conversations, per Requirement 1 §3.17-3.19. The concept HTML
/// (fitcoach-ui-concept.html) only ever mockes up a single hardcoded thread
/// per role, not a list screen -- this is designed fresh, following the rest
/// of the built app's list-screen convention (AppBar + ListView.separated,
/// same shape as cards_list_screen.dart) rather than the concept's markup.
class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key, required this.title, required this.basePath});

  final String title;
  final String basePath;

  Future<void> _startConversation(BuildContext context, WidgetRef ref) async {
    final conversationId = await showStartConversationSheet(context);
    if (conversationId == null) return;
    ref.invalidate(conversationsProvider);
    if (context.mounted) context.push('$basePath/$conversationId');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.add_comment_outlined),
            tooltip: 'New message',
            onPressed: () => _startConversation(context, ref),
          ),
        ],
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your conversations: $error')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'No conversations yet. Tap the message icon above to start one.',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(conversationsProvider),
            child: ListView.separated(
              itemCount: conversations.length,
              separatorBuilder: (context, index) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final conversation = conversations[index];
                final name = conversation.otherDisplayName ?? 'Unnamed';
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: AppColors.stoneLight,
                    child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.ink)),
                  ),
                  title: Text(name, style: TextStyle(fontWeight: conversation.hasUnread ? FontWeight.bold : FontWeight.normal)),
                  subtitle: Text(
                    conversation.lastMessageBody == null
                        ? 'Say hello'
                        : '${conversation.lastMessageIsMine ? 'You: ' : ''}${conversation.lastMessageBody}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: conversation.hasUnread ? FontWeight.w600 : FontWeight.normal),
                  ),
                  trailing: conversation.hasUnread
                      ? const CircleAvatar(radius: 5, backgroundColor: AppColors.lime)
                      : conversation.lastMessageAt != null
                      ? Text(DateFormat.MMMd().format(conversation.lastMessageAt!), style: const TextStyle(fontSize: 11))
                      : null,
                  onTap: () => context.push('$basePath/${conversation.conversationId}'),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
