import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'assign_card_sheet.dart';
import 'workout_cards_providers.dart';

const _visibilityLabels = {'public': 'Public', 'private': 'Private', 'gym_only': 'Gym'};

class CardsListScreen extends ConsumerWidget {
  const CardsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardsAsync = ref.watch(trainerCardsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Cards')),
      body: cardsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Could not load your cards: $error')),
        data: (cards) {
          if (cards.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('No cards yet. Build your first one from the Build tab.', textAlign: TextAlign.center),
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(trainerCardsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: cards.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final card = cards[index];
                return Card(
                  child: ListTile(
                    onTap: () => context.push('/trainer/cards/${card.id}'),
                    title: Text(card.title),
                    subtitle: Text(
                      '${_visibilityLabels[card.visibility] ?? card.visibility} • ${card.exerciseCount} exercises'
                      '${card.isPublished ? '' : ' • Draft'}',
                    ),
                    trailing: TextButton(
                      onPressed: () => showAssignCardSheet(context, cardId: card.id, cardTitle: card.title),
                      child: const Text('Assign'),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
