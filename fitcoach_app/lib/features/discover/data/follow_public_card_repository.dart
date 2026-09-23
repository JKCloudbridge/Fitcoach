import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// The one write this milestone that needs fitcoach_backend/workout-api --
/// starting a public card snapshots its exercises into a new
/// workout_assignments/assignment_exercises pair and bumps
/// card_stats.follow_count, which RLS alone can't gate (see migration 013's
/// header). Client-side analog of workout_cards/data/
/// assign_workout_card_repository.dart -- same shape, kept as its own small
/// file rather than a shared generic one since the two features (trainer
/// assigning vs. client self-starting) don't otherwise share code.
class FollowPublicCardRepository {
  FollowPublicCardRepository(this._dio);

  final Dio _dio;

  Future<String> follow({required String cardId}) async {
    final response = await _dio.post<Map<String, dynamic>>('/workout-api/follow-public-card', data: {'cardId': cardId});
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['assignmentId'] as String;
  }
}

final followPublicCardRepositoryProvider = Provider<FollowPublicCardRepository>((ref) {
  return FollowPublicCardRepository(ref.watch(dioProvider));
});

/// Pulls the `{error:{code,message}}` envelope's message out of a failed
/// call, falling back to a generic string -- same shape fitcoach_backend's
/// _shared/errors.ts sends on every error response.
String describeFollowError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String) return message;
    }
  }
  return 'Could not start this card: $error';
}
