import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// The one programs write that needs fitcoach_backend/programs-api, per
/// CLAUDE.md's hybrid pattern -- subscribing creates a program_subscriptions
/// row and cascades into workout_assignments/habits, which RLS alone can't
/// gate (see migration 028's header). Client-side analog of
/// discover/data/follow_public_card_repository.dart -- same shape.
class SubscribeProgramRepository {
  SubscribeProgramRepository(this._dio);

  final Dio _dio;

  Future<String> subscribe({required String programId}) async {
    final response = await _dio.post<Map<String, dynamic>>('/programs-api/subscribe-program', data: {'programId': programId});
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['subscriptionId'] as String;
  }
}

final subscribeProgramRepositoryProvider = Provider<SubscribeProgramRepository>((ref) {
  return SubscribeProgramRepository(ref.watch(dioProvider));
});

/// Pulls the `{error:{code,message}}` envelope's message out of a failed
/// call, falling back to a generic string -- same shape as
/// describeFollowError/describeRedeemInviteError.
String describeSubscribeProgramError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String) return message;
    }
  }
  return 'Could not subscribe to this program: $error';
}
