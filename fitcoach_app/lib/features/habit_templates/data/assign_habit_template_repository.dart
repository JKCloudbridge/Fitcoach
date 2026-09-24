import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// The one write this feature needs fitcoach_backend/habits-api for, per
/// CLAUDE.md's hybrid pattern -- assigning a template to a specific client
/// crosses the trainer/client boundary, which RLS alone can't gate (see
/// migrations 015's and 017's header comments). Mirrors
/// workout_cards/data/assign_workout_card_repository.dart's shape exactly.
class AssignHabitTemplateRepository {
  AssignHabitTemplateRepository(this._dio);

  final Dio _dio;

  Future<String> assign({required String templateId, required String clientId}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/habits-api/assign-habit-template',
      data: {'templateId': templateId, 'clientId': clientId},
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['habitId'] as String;
  }
}

final assignHabitTemplateRepositoryProvider = Provider<AssignHabitTemplateRepository>((ref) {
  return AssignHabitTemplateRepository(ref.watch(dioProvider));
});

/// Pulls the `{error:{code,message}}` envelope's message out of a failed
/// call, same shape as workout_cards' describeAssignError.
String describeAssignHabitTemplateError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String) return message;
    }
  }
  return 'Could not assign this habit: $error';
}
