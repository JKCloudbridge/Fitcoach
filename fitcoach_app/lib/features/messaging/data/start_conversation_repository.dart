import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// The one messaging write that needs fitcoach_backend/coaching-api, per
/// CLAUDE.md's hybrid pattern -- finding-or-creating a 1:1 conversation has
/// to validate an active coaching_relationship first and bootstrap
/// conversation_members rows RLS can't authorize on their own (see
/// migrations/018's header comment). Sending within an already-started
/// conversation stays a direct RLS write (messaging_repository.dart).
class StartConversationRepository {
  StartConversationRepository(this._dio);

  final Dio _dio;

  Future<String> start({required String otherUserId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/coaching-api/start-conversation',
      data: {'otherUserId': otherUserId},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['conversationId'] as String;
  }
}

final startConversationRepositoryProvider = Provider<StartConversationRepository>((ref) {
  return StartConversationRepository(ref.watch(dioProvider));
});

/// Same envelope-unwrapping shape as workout_cards'
/// assign_workout_card_repository.dart's describeAssignError.
String describeStartConversationError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String) return message;
    }
  }
  return 'Could not start this conversation: $error';
}
