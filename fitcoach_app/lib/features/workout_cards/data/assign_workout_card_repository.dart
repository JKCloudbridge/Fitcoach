import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';

/// The one write this milestone that needs fitcoach_backend/workout-api,
/// per CLAUDE.md's hybrid pattern -- assigning a card snapshots exercises
/// into a new workout_assignments/assignment_exercises pair across the
/// trainer/client boundary, which RLS alone can't gate (see
/// migrations/007's and 009's header comments).
class AssignWorkoutCardRepository {
  AssignWorkoutCardRepository(this._dio);

  final Dio _dio;

  Future<String> assign({required String cardId, required String clientId, DateTime? startDate, DateTime? dueDate}) async {
    final response = await _dio.post<Map<String, dynamic>>(
      '/workout-api/assign-workout-card',
      data: {
        'cardId': cardId,
        'clientId': clientId,
        if (startDate != null) 'startDate': _dateOnly(startDate),
        if (dueDate != null) 'dueDate': _dateOnly(dueDate),
      },
    );
    final data = response.data!['data'] as Map<String, dynamic>;
    return data['assignmentId'] as String;
  }

  String _dateOnly(DateTime date) => date.toIso8601String().split('T').first;
}

final assignWorkoutCardRepositoryProvider = Provider<AssignWorkoutCardRepository>((ref) {
  return AssignWorkoutCardRepository(ref.watch(dioProvider));
});

/// Pulls the `{error:{code,message}}` envelope's message out of a failed
/// call, falling back to a generic string -- same shape fitcoach_backend's
/// _shared/errors.ts sends on every error response.
String describeAssignError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map && data['error'] is Map) {
      final message = (data['error'] as Map)['message'];
      if (message is String) return message;
    }
  }
  return 'Could not assign this card: $error';
}
