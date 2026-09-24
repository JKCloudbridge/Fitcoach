import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/tag_pill.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../notifications/presentation/notification_bell.dart';
import 'profile_providers.dart';

class TrainerProfileScreen extends ConsumerWidget {
  const TrainerProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(trainerProfileProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          const NotificationBell(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: profileAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your profile: $error')),
        data: (profile) {
          if (profile == null) {
            return const Center(child: Text('No profile found.'));
          }
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              CircleAvatar(
                radius: 40,
                backgroundImage: profile.avatarUrl != null ? NetworkImage(profile.avatarUrl!) : null,
                child: profile.avatarUrl == null ? const Icon(Icons.person, size: 40) : null,
              ),
              const SizedBox(height: 16),
              Text(profile.displayName ?? 'Unnamed trainer', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
              if (profile.isVerified) ...[
                const SizedBox(height: 4),
                const Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [Icon(Icons.verified, size: 16), SizedBox(width: 4), TagPill('Verified')],
                  ),
                ),
              ],
              const SizedBox(height: 24),
              if (profile.bio != null && profile.bio!.isNotEmpty) ...[
                const Text('Bio', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(profile.bio!),
                const SizedBox(height: 16),
              ],
              if (profile.certifications.isNotEmpty) ...[
                const Text('Certifications', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Wrap(spacing: 8, runSpacing: 8, children: [for (final c in profile.certifications) TagPill(c)]),
                const SizedBox(height: 16),
              ],
              const SizedBox(height: 8),
              FilledButton.icon(
                onPressed: () => context.push('/trainer/profile/edit'),
                icon: const Icon(Icons.edit),
                label: const Text('Edit profile'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.push('/trainer/profile/subscription'),
                icon: const Icon(Icons.confirmation_number_outlined),
                label: const Text('Seats & invites'),
              ),
            ],
          );
        },
      ),
    );
  }
}
